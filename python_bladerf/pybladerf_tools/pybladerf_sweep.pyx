# MIT License

# Copyright (c) 2024-2025 GvozdevLeonid

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# distutils: language = c++
# cython: language_level = 3str
# cython: freethreading_compatible = True
try:
    from pyfftw.interfaces.numpy_fft import fft, fftshift  # type: ignore
except ImportError:
    try:
        from scipy.fft import fft, fftshift  # type: ignore
    except ImportError:
        from numpy.fft import fft, fftshift  # type: ignore

from python_bladerf.pylibbladerf cimport pybladerf as c_pybladerf
from libc.stdint cimport uint64_t, uint32_t, uint16_t, uint8_t
from python_bladerf.pylibbladerf cimport cbladerf
from python_bladerf import pybladerf
from libcpp.atomic cimport atomic
from queue import Queue
cimport numpy as cnp
import numpy as np
import threading
import datetime
cimport cython
import signal
import struct
import time
import sys
import os

cnp.import_array()

FREQ_MIN_MHZ = 70  # 70 MHz
FREQ_MAX_MHZ = 6_000  # 6000 MHZ
FREQ_MIN_HZ = int(FREQ_MIN_MHZ * 1e6)  # Hz
FREQ_MAX_HZ = int(FREQ_MAX_MHZ * 1e6)  # Hz

MIN_SAMPLE_RATE = 520_834
MAX_SAMPLE_RATE = 61_440_000

MIN_BASEBAND_FILTER_BANDWIDTHS = 200_000  # MHz
MAX_BASEBAND_FILTER_BANDWIDTHS = 56_000_000  # MHz

INTERLEAVED_OFFSET_RATIO = 0.375
LINEAR_OFFSET_RATIO = 0.5

cdef atomic[uint8_t] working_sdrs[16]
cdef dict sdr_ids = {}

cdef struct SweepStep:
    uint64_t frequency
    uint64_t schedule_time

def sigint_callback_handler(sig, frame, sdr_id):
    global working_sdrs
    working_sdrs[sdr_id].store(0)


def init_signals() -> int:
    global working_sdrs

    sdr_id = -1
    for i in range(16):
        if working_sdrs[i].load() == 0:
            sdr_id = i
            break

    if sdr_id >= 0:
        try:
            signal.signal(signal.SIGINT, lambda sig, frame: sigint_callback_handler(sig, frame, sdr_id))
            signal.signal(signal.SIGILL, lambda sig, frame: sigint_callback_handler(sig, frame, sdr_id))
            signal.signal(signal.SIGTERM, lambda sig, frame: sigint_callback_handler(sig, frame, sdr_id))
            signal.signal(signal.SIGABRT, lambda sig, frame: sigint_callback_handler(sig, frame, sdr_id))
        except Exception as ex:
            sys.stderr.write(f'Error: {ex}\n')

    return sdr_id


def stop_all() -> None:
    global working_sdrs
    for i in range(16):
        working_sdrs[i].store(0)


def stop_sdr(serialno: str) -> None:
    global sdr_ids, working_sdrs
    if serialno in sdr_ids:
        working_sdrs[sdr_ids[serialno]].store(0)


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef void process_data(uint8_t device_id,
                       uint64_t sample_rate,
                       int sweep_style,
                       uint8_t oversample,
                       uint32_t fft_size,
                       uint8_t binary_output,
                       object close_ready,
                       object raw_data_queue,
                       object empty_raw_data_queue,
                       object file,
                       object queue,
    ):

    global working_sdrs

    cdef cnp.ndarray window = np.hanning(fft_size)
    cdef uint16_t divider = 128 if oversample else 2048

    cdef cnp.ndarray data
    cdef cnp.ndarray raw_iq
    cdef cnp.ndarray fftOut
    cdef cnp.ndarray dbfs
    cdef double psd_norm = 1 / (sample_rate * np.dot(window, window))

    cdef uint32_t fft_1_start = 1 + (fft_size * 5) // 8
    cdef uint32_t fft_1_stop = 1 + (fft_size * 5) // 8 + fft_size // 4

    cdef uint32_t fft_2_start = 1 + fft_size // 8
    cdef uint32_t fft_2_stop = 1 + fft_size // 8 + fft_size // 4

    cdef uint64_t frequency = 0
    cdef str time_str

    while working_sdrs[device_id].load():

        if raw_data_queue.empty():
            time.sleep(.035)
            continue

        time_str, frequency, data = raw_data_queue.get()

        raw_iq = data[::2] * divider + 1j * data[1::2] * divider
        empty_raw_data_queue.put(data)

        fft_out = fft((raw_iq - raw_iq.mean()) * window)
        dbfs = np.log10((fft_out.real**2 + fft_out.imag**2) * psd_norm + 1e-300) * 10.0

        if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_LINEAR:
            pwr = fftshift(pwr)

        if binary_output:
            if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
                record_length = 16 + (fft_size // 4) * 4
                line = struct.pack('I', record_length)
                line += struct.pack('Q', frequency)
                line += struct.pack('Q', frequency + sample_rate // 4)
                line += struct.pack('<' + 'f' * (fft_size // 4), *pwr[fft_1_start:fft_1_stop])
                line += struct.pack('I', record_length)
                line += struct.pack('Q', frequency + sample_rate // 2)
                line += struct.pack('Q', frequency + (sample_rate * 3) // 4)
                line += struct.pack('<' + 'f' * (fft_size // 4), *pwr[fft_2_start:fft_2_stop])

            else:
                record_length = 16 + fft_size * 4
                line = struct.pack('I', record_length)
                line += struct.pack('Q', frequency)
                line += struct.pack('Q', frequency + sample_rate)
                line += struct.pack('<' + 'f' * fft_size, *pwr)

            file.write(line)

        elif queue is not None:
            if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
                queue.put({
                    'timestamp': time_str,
                    'start_frequency': frequency,
                    'stop_frequency': frequency + sample_rate // 4,
                    'dbfs': pwr[fft_1_start:fft_1_stop].astype(np.float32),
                })
                queue.put({
                    'timestamp': time_str,
                    'start_frequency': frequency + sample_rate // 2,
                    'stop_frequency': frequency + (sample_rate * 3) // 4,
                    'dbfs': pwr[fft_2_start:fft_2_stop].astype(np.float32),
                })

            else:
                queue.put({
                    'timestamp': time_str,
                    'start_frequency': frequency,
                    'stop_frequency': frequency + sample_rate,
                    'dbfs': pwr.astype(np.float32),
                })

        else:
            if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
                line = f'{time_str}, {frequency}, {frequency + sample_rate // 4}, {sample_rate / fft_size}, {fft_size}, '
                for value in pwr[fft_1_start:fft_1_stop]:
                    line += f'{value:.10f}, '
                line += f'\n{time_str}, {frequency + sample_rate // 2}, {frequency + (sample_rate * 3) // 4}, {sample_rate / fft_size}, {fft_size}, '
                for value in pwr[fft_2_start:fft_2_stop]:
                    line += f'{value:.10f}, '
                line = line[:len(line) - 2] + '\n'

            else:
                line = f'{time_str}, {frequency}, {frequency + sample_rate}, {sample_rate / fft_size}, {fft_size}, '
                for i in range(len(pwr)):
                    line += f'{pwr[i]:.2f}, '
                line = line[:len(line) - 2] + '\n'

            file.write(line)

    close_ready.set()


def pybladerf_sweep(frequencies: list[int] | None = None, sample_rate: int = 61_000_000, baseband_filter_bandwidth: int | None = None,
                    gain: int = 20, bin_width: int = 100_000, channel: int = 0, oversample: bool = False, antenna_enable: bool = False,
                    sweep_style: pybladerf.pybladerf_sweep_style = pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED, serial_number: str | None = None,
                    binary_output: bool = False, one_shot: bool = False, num_sweeps: int | None = None,
                    filename: str | None = None, queue: object | None = None,
                    print_to_console: bool = True,
                    ) -> None:

    global working_sdrs, sdr_ids

    cdef uint8_t device_id = init_signals()
    cdef uint8_t formated_channel = pybladerf.PYBLADERF_CHANNEL_RX(channel)
    cdef c_pybladerf.PyBladerfDevice device
    cdef cbladerf.bladerf* c_device
    cdef uint64_t offset = 0

    if serial_number is None:
        device = pybladerf.pybladerf_open()
    else:
        device = pybladerf.pybladerf_open_by_serial(serial_number)
    c_device = device.get_ptr()

    working_sdrs[device_id].store(1)
    sdr_ids[device.serialno] = device_id

    device.pybladerf_enable_feature(pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE, False)

    if oversample:
        sample_rate = int(sample_rate) if MIN_SAMPLE_RATE * 2 <= int(sample_rate) <= MAX_SAMPLE_RATE * 2 else 122_000_000
    else:
        sample_rate = int(sample_rate) if MIN_SAMPLE_RATE <= int(sample_rate) <= MAX_SAMPLE_RATE else 61_000_000

    real_min_freq_hz = FREQ_MIN_HZ - sample_rate // 2
    real_max_freq_hz = FREQ_MAX_HZ + sample_rate // 2

    if baseband_filter_bandwidth is None:
        baseband_filter_bandwidth = int(sample_rate * .75)
    baseband_filter_bandwidth = int(baseband_filter_bandwidth) if MIN_BASEBAND_FILTER_BANDWIDTHS <= int(baseband_filter_bandwidth) <= MAX_BASEBAND_FILTER_BANDWIDTHS else int(sample_rate * .75)

    if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
        offset = int(sample_rate * INTERLEAVED_OFFSET_RATIO)
    else:
        offset = int(sample_rate * LINEAR_OFFSET_RATIO)

    if frequencies is None:
        frequencies = [int(FREQ_MIN_MHZ - sample_rate // 2e6), int(FREQ_MAX_MHZ + sample_rate // 2e6)]

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_tuning_mode({pybladerf.pybladerf_tuning_mode.PYBLADERF_TUNING_MODE_FPGA})\n')
    device.pybladerf_set_tuning_mode(pybladerf.pybladerf_tuning_mode.PYBLADERF_TUNING_MODE_FPGA)

    if oversample:
        if print_to_console:
            sys.stderr.write(f'call pybladerf_enable_feature({pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE}, True)\n')
        device.pybladerf_enable_feature(pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE, True)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_sample_rate({sample_rate / 1e6 :.3f} MHz)\n')
    device.pybladerf_set_sample_rate(formated_channel, sample_rate)

    if not oversample:
        if print_to_console:
            sys.stderr.write(f'call pybladerf_set_bandwidth({formated_channel}, {baseband_filter_bandwidth / 1e6 :.3f} MHz)\n')
        device.pybladerf_set_bandwidth(formated_channel, baseband_filter_bandwidth)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_gain_mode({formated_channel}, {pybladerf.pybladerf_gain_mode.PYBLADERF_GAIN_MGC})\n')
    device.pybladerf_set_gain_mode(formated_channel, pybladerf.pybladerf_gain_mode.PYBLADERF_GAIN_MGC)
    device.pybladerf_set_gain(formated_channel, gain)

    if antenna_enable:
        if print_to_console:
            sys.stderr.write(f'call pybladerf_set_bias_tee({formated_channel}, True)\n')
        device.pybladerf_set_bias_tee(formated_channel, True)

    num_ranges = len(frequencies) // 2
    calculated_frequencies = []

    for i in range(num_ranges):
        frequencies[2 * i] = int(frequencies[2 * i] * 1e6)
        frequencies[2 * i + 1] = int(frequencies[2 * i + 1] * 1e6)

        if frequencies[2 * i] >= frequencies[2 * i + 1]:
            device.pybladerf_close()
            raise RuntimeError('max frequency must be greater than min frequency.')

        step_count = 1 + (frequencies[2 * i + 1] - frequencies[2 * i] - 1) // sample_rate
        frequencies[2 * i + 1] = int(frequencies[2 * i] + step_count * sample_rate)

        if frequencies[2 * i] < real_min_freq_hz:
            device.pybladerf_close()
            raise RuntimeError(f'min frequency must must be greater than {int(real_min_freq_hz / 1e6)} MHz.')
        if frequencies[2 * i + 1] > real_max_freq_hz:
            device.pybladerf_close()
            raise RuntimeError(f'max frequency may not be higher {int(real_max_freq_hz / 1e6)} MHz.')

        frequency = frequencies[2 * i]
        if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
            for j in range(step_count * 2):
                calculated_frequencies.append(frequency)
                if j % 2 == 0:
                    frequency += int(sample_rate / 4)
                else:
                    frequency += int(3 * sample_rate / 4)
        else:
            for j in range(step_count):
                calculated_frequencies.append(frequency)
                frequency += sample_rate

        if print_to_console:
            sys.stderr.write(f'Sweeping from {frequencies[2 * i] / 1e6} MHz to {frequencies[2 * i + 1] / 1e6} MHz\n')

    if len(calculated_frequencies) > 256:
        device.pybladerf_close()
        raise RuntimeError('Reached maximum number of RX quick tune profiles. Please reduce the frequency range or increase the sample rate.')

    cdef uint32_t fft_size = int(sample_rate / bin_width)
    if fft_size < 4:
        device.pybladerf_close()
        raise RuntimeError(f'bin_width should be no more than {sample_rate // 4} Hz')

    while ((fft_size + 4) % 8):
        fft_size += 1

    quick_tunes = []
    for frequency in calculated_frequencies:
        device.pybladerf_set_frequency(formated_channel, frequency + offset)

        quick_tune = device.pybladerf_get_quick_tune(formated_channel)
        quick_tunes.append((frequency, quick_tune))

    raw_data_queue = Queue()
    empty_raw_data_queue = Queue()

    file = open(filename, 'w' if not binary_output else 'wb') if filename is not None else (sys.stdout.buffer if binary_output else sys.stdout)
    close_ready = threading.Event()

    device.pybladerf_set_rfic_rx_fir(pybladerf.pybladerf_rfic_rxfir.PYBLADERF_RFIC_RXFIR_BYPASS)
    device.pybladerf_sync_config(
        layout=pybladerf.pybladerf_channel_layout.PYBLADERF_RX_X1,
        data_format=pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC8_Q7_META if oversample else pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC16_Q11_META,
        num_buffers=int(os.environ.get('pybladerf_sweep_num_buffers', 4096)),
        buffer_size=int(os.environ.get('pybladerf_sweep_buffer_size', 8192)),
        num_transfers=int(os.environ.get('pybladerf_sweep_num_transfers', 64)),
        stream_timeout=0,
    )
    device.pybladerf_enable_module(formated_channel, True)

    processing_thread = threading.Thread(target=process_data, args=(
        device_id,
        sample_rate,
        sweep_style if sweep_style in pybladerf.pybladerf_sweep_style else pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED,
        1 if oversample else 0,
        fft_size,
        1 if binary_output else 0,
        close_ready,
        raw_data_queue,
        empty_raw_data_queue,
        file,
        queue,
    ), daemon=True)
    processing_thread.start()

    cdef uint64_t time_1ms = int(sample_rate // 1000)
    cdef uint64_t await_time = int(time_1ms * float(os.environ.get('pybladerf_sweep_await_time', 1.5)))
    cdef uint16_t tune_steps = len(calculated_frequencies)

    cdef double time_start = time.time()
    cdef double time_prev = time.time()
    cdef uint8_t free_rffe_profile = 0
    cdef uint8_t rffe_profiles = min(8, tune_steps)

    cdef uint64_t schedule_timestamp = 0
    cdef uint64_t accepted_samples = 0
    cdef double time_difference = 0
    cdef uint64_t sweep_count = 0
    cdef uint16_t tune_step = 0
    cdef double sweep_rate = 0
    cdef double time_now = 0

    cdef uint8_t sweep_step_write_ptr = 0
    cdef uint8_t sweep_step_read_ptr = 0
    cdef SweepStep[8] sweep_steps

    cdef cnp.ndarray buffer

    cdef c_pybladerf.pybladerf_metadata meta = pybladerf.pybladerf_metadata()

    schedule_timestamp = device.pybladerf_get_timestamp(pybladerf.pybladerf_direction.PYBLADERF_RX) + time_1ms * 150

    for i in range(8):
        quick_tunes[tune_step][1].rffe_profile = free_rffe_profile
        device.pybladerf_schedule_retune(formated_channel, schedule_timestamp, 0, quick_tunes[tune_step][1])

        sweep_steps[sweep_step_write_ptr].frequency = quick_tunes[tune_step][0]
        sweep_steps[sweep_step_write_ptr].schedule_time = schedule_timestamp + await_time
        sweep_step_write_ptr = (sweep_step_write_ptr + 1) % 8

        free_rffe_profile = (free_rffe_profile + 1) % rffe_profiles
        schedule_timestamp += await_time + fft_size
        tune_step = (tune_step + 1) % tune_steps

    with nogil:
        while working_sdrs[device_id].load():

# 
                if empty_raw_data_queue.empty():
                    buffer = np.empty(fft_size if oversample else fft_size * 2, dtype=np.int8 if oversample else np.int16)
                else:
                    buffer = empty_raw_data_queue.get()

                meta.timestamp = sweep_steps[sweep_step_read_ptr].schedule_time

                try:
                    device.pybladerf_sync_rx(buffer, fft_size, meta, 0)
                    raw_data_queue.put(
                        (
                            datetime.datetime.now().strftime('%Y-%m-%d, %H:%M:%S.%f'),
                            sweep_steps[sweep_step_read_ptr].frequency,
                            buffer,
                        )
                    )

                    sweep_step_read_ptr = (sweep_step_read_ptr + 1) % 8

                    quick_tunes[tune_step][1].rffe_profile = free_rffe_profile
                    device.pybladerf_schedule_retune(formated_channel, schedule_timestamp, 0, quick_tunes[tune_step][1])

                    sweep_steps[sweep_step_write_ptr].frequency = quick_tunes[tune_step][0]
                    sweep_steps[sweep_step_write_ptr].schedule_time = schedule_timestamp + await_time
                    sweep_step_write_ptr = (sweep_step_write_ptr + 1) % 8

                    free_rffe_profile = (free_rffe_profile + 1) % rffe_profiles
                    schedule_timestamp += await_time + fft_size
                    tune_step = (tune_step + 1) % tune_steps

                    accepted_samples += fft_size

                except pybladerf.PYBLADERF_ERR_TIME_PAST:
                    sys.stderr.write("Timestamp is in the past, restarting...\n")

                    tune_step = 0
                    free_rffe_profile = 0
                    sweep_step_read_ptr = 0
                    sweep_step_write_ptr = 0

                    schedule_timestamp = device.pybladerf_get_timestamp(pybladerf.pybladerf_direction.PYBLADERF_RX) + time_1ms * 150
                    empty_raw_data_queue.put(buffer)

                    for i in range(8):
                        quick_tunes[tune_step][1].rffe_profile = free_rffe_profile
                        device.pybladerf_schedule_retune(formated_channel, schedule_timestamp, 0, quick_tunes[tune_step][1])

                        sweep_steps[sweep_step_write_ptr].frequency = quick_tunes[tune_step][0]
                        sweep_steps[sweep_step_write_ptr].schedule_time = schedule_timestamp + await_time
                        sweep_step_write_ptr = (sweep_step_write_ptr + 1) % 8

                        free_rffe_profile = (free_rffe_profile + 1) % rffe_profiles
                        schedule_timestamp += await_time + fft_size
                        tune_step = (tune_step + 1) % tune_steps

                    continue

                except pybladerf.PYBLADERF_ERR as ex:
                    sys.stderr.write("pybladerf_sync_rx() failed: %s %d", cbladerf.bladerf_strerror(ex.code), ex.code)
                    working_sdrs[device_id].store(0)
                    break


                if tune_step == 0:
                    sweep_count += 1

                    if one_shot or (num_sweeps == sweep_count):
                        if sweep_count:
                            working_sdrs[device_id].store(0)

                time_now = time.time()
                time_difference = time_now - time_prev
                if time_difference >= 1.0:
                    if print_to_console:
                        sweep_rate = sweep_count / (time_now - time_start)
                        sys.stderr.write(f'{sweep_count} total sweeps completed, {round(sweep_rate, 2)} sweeps/second\n')

                    if accepted_samples == 0:
                        if print_to_console:
                            sys.stderr.write("Couldn\'t transfer any data for one second.\n")
                        break

                    accepted_samples = 0
                    time_prev = time_now

    if print_to_console:
        if not working_sdrs[device_id].load():
            sys.stderr.write('\nExiting...\n')
        else:
            sys.stderr.write('\nExiting... [ pybladerf streaming stopped ]\n')

    working_sdrs[device_id].store(0)
    close_ready.wait()
    sdr_ids.pop(device.serialno, None)

    del empty_raw_data_mutex
    del raw_data_mutex

    if filename is not None:
        file.close()

    time_now = time.time()
    time_difference = time_now - time_prev
    if sweep_rate == 0 and time_difference > 0:
        sweep_rate = sweep_count / (time_now - time_start)

    if print_to_console:
        sys.stderr.write(f'Total sweeps: {sweep_count} in {time_now - time_start:.5f} seconds ({sweep_rate :.2f} sweeps/second)\n')

    if antenna_enable:
        try:
            device.pybladerf_set_bias_tee(formated_channel, False)
        except Exception as ex:
                sys.stderr.write(f'{ex}\n')

    try:
        device.pybladerf_enable_module(formated_channel, False)
    except Exception as ex:
            sys.stderr.write(f'{ex}\n')

    try:
        device.pybladerf_close()
        if print_to_console:
            sys.stderr.write('pybladerf_close() done\n')
    except Exception as ex:
        sys.stderr.write(f'{ex}\n')
