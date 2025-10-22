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
# cython: language_level=3str
try:
    from pyfftw.interfaces.numpy_fft import fft, fftshift  # type: ignore
except ImportError:
    try:
        from scipy.fft import fft, fftshift  # type: ignore
    except ImportError:
        from numpy.fft import fft, fftshift  # type: ignore

from libc.stdint cimport uint64_t, uint32_t, uint16_t, uint8_t, uintptr_t
from python_bladerf.pylibbladerf cimport pybladerf as c_pybladerf
from python_bladerf.pylibbladerf.ctime cimport get_time
from python_bladerf.pylibbladerf cimport cbladerf
from libcpp.queue cimport queue as c_queue
from libc.stdio cimport fprintf, stderr
from libc.stdlib cimport malloc, free
from python_bladerf import pybladerf
from libcpp cimport bool as c_bool
from libcpp.atomic cimport atomic
from libcpp.mutex cimport mutex
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

cdef struct QueueNode:
    uint16_t* buffer
    uint64_t frequency
    double time

cdef QueueNode* init_node(uint32_t node_buffer_size) noexcept nogil:
    cdef QueueNode* node = <QueueNode*>malloc(sizeof(QueueNode))
    node.buffer = <uint16_t*>malloc(node_buffer_size * sizeof(uint16_t))
    node.frequency = 0
    node.time = 0

    return node

cdef void destroy_node(QueueNode** node_ptr) noexcept nogil:
    if node_ptr != NULL and node_ptr[0] != NULL:
        if node_ptr[0].buffer != NULL:
            free(node_ptr[0].buffer)
            node_ptr[0].buffer = NULL
        free(node_ptr[0])
        node_ptr[0] = NULL

cdef struct QuickTune:
    uint64_t frequency
    cbladerf.bladerf_quick_tune quick_tune

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
                       uint16_t divider,
                       uint8_t binary_output,
                       object notify_finished,
                       uintptr_t raw_data_ptr,
                       uintptr_t empty_raw_data_ptr,
                       uintptr_t raw_data_mutex_ptr,
                       uintptr_t empty_raw_data_mutex_ptr,
                       object file,
                       object queue):

    global working_sdrs

    cdef c_queue[QueueNode*]* raw_data = <c_queue[QueueNode*]*> raw_data_ptr
    cdef c_queue[QueueNode*]* empty_raw_data = <c_queue[QueueNode*]*> empty_raw_data_ptr

    cdef mutex* raw_data_mutex = <mutex*> raw_data_mutex_ptr
    cdef mutex* empty_raw_data_mutex = <mutex*> empty_raw_data_mutex_ptr

    cdef double norm_factor = 1 / fft_size
    cdef cnp.ndarray window = np.hanning(fft_size)

    cdef cnp.ndarray data
    cdef cnp.ndarray raw_iq
    cdef cnp.ndarray fftOut
    cdef cnp.ndarray pwr

    cdef uint32_t fft_1_start = 1 + (fft_size * 5) // 8
    cdef uint32_t fft_1_stop = 1 + (fft_size * 5) // 8 + fft_size // 4

    cdef uint32_t fft_2_start = 1 + fft_size // 8
    cdef uint32_t fft_2_stop = 1 + fft_size // 8 + fft_size // 4

    cdef uint64_t frequency = 0
    cdef str time_str
    cdef uint32_t i

    cdef QueueNode* node = NULL

    while working_sdrs[device_id].load():
        with nogil:
            if not raw_data.empty():
                raw_data_mutex.lock()
                node = raw_data.front()
                raw_data.pop()
                raw_data_mutex.unlock()
            else:
                node = NULL

        if node != NULL:

            frequency = node.frequency
            time_str = datetime.datetime.fromtimestamp(node.time).strftime('%Y-%m-%d, %H:%M:%S.%f')

            if oversample:
                data = np.frombuffer(<uint8_t[:fft_size * 2]> <uint8_t*> node.buffer, dtype=np.int8)  # type: ignore
            else:
                data = np.frombuffer(<uint16_t[:fft_size * 2]> node.buffer, dtype=np.int16)  # type: ignore

            raw_iq = data[::2] / divider + 1j * data[1::2] / divider
            raw_iq = (raw_iq - raw_iq.mean()) * window 
            fftOut = fft(raw_iq)

            empty_raw_data_mutex.lock()
            empty_raw_data.push(node)
            empty_raw_data_mutex.unlock()
            node = NULL

            pwr = np.log10(np.abs(fftOut * norm_factor) ** 2) * 10.0
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
                        'fft': pwr[fft_1_start:fft_1_stop].astype(np.float32),
                    })
                    queue.put({
                        'timestamp': time_str,
                        'start_frequency': frequency + sample_rate // 2,
                        'stop_frequency': frequency + (sample_rate * 3) // 4,
                        'fft': pwr[fft_2_start:fft_2_stop].astype(np.float32),
                    })

                else:
                    queue.put({
                        'timestamp': time_str,
                        'start_frequency': frequency,
                        'stop_frequency': frequency + sample_rate,
                        'fft': pwr.astype(np.float32),
                        'raw_iq': raw_iq,
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

        else:
            time.sleep(.035)

    notify_finished.set()


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
    cdef int i

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

    cdef QuickTune[256] quick_tunes
    for i, frequency in enumerate(calculated_frequencies):
        device.pybladerf_set_frequency(formated_channel, frequency + offset)

        cbladerf.bladerf_get_quick_tune(c_device, formated_channel, &quick_tunes[i].quick_tune)
        quick_tunes[i].frequency = frequency

    cdef c_queue[QueueNode*] raw_data
    cdef c_queue[QueueNode*] empty_raw_data
    cdef mutex* raw_data_mutex = new mutex()
    cdef mutex* empty_raw_data_mutex = new mutex()

    file = open(filename, 'w' if not binary_output else 'wb') if filename is not None else (sys.stdout.buffer if binary_output else sys.stdout)
    notify_finished = threading.Event()

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
        128 if oversample else 2048,
        1 if binary_output else 0,
        notify_finished,
        <uintptr_t> &raw_data,
        <uintptr_t> &empty_raw_data,
        <uintptr_t> raw_data_mutex,
        <uintptr_t> empty_raw_data_mutex,
        file,
        queue,
    ), daemon=True)
    processing_thread.start()

    cdef uint64_t time_1ms = int(sample_rate // 1000)
    cdef uint64_t await_time = int(time_1ms * float(os.environ.get('pybladerf_sweep_await_time', 1.5)))
    cdef uint16_t tune_steps = len(calculated_frequencies)

    cdef double time_start = get_time()
    cdef double time_prev = get_time()
    cdef uint8_t free_rffe_profile = 0
    cdef uint8_t rffe_profiles = min(8, tune_steps)

    cdef uint32_t node_buffer_size = fft_size if oversample else fft_size * 2
    cdef uint64_t schedule_timestamp = 0
    cdef uint64_t accepted_samples = 0
    cdef double time_difference = 0
    cdef uint64_t sweep_count = 0
    cdef uint16_t tune_step = 0
    cdef double sweep_time = 0
    cdef double sweep_rate = 0
    cdef double time_now = 0

    cdef uint8_t sweep_step_write_ptr = 0
    cdef uint8_t sweep_step_read_ptr = 0
    cdef SweepStep[8] sweep_steps
    cdef QueueNode* node = NULL

    cdef c_pybladerf.pybladerf_metadata py_meta = pybladerf.pybladerf_metadata()
    cdef cbladerf.bladerf_metadata* c_meta = py_meta.get_ptr()

    cdef c_bool c_print_to_console = print_to_console
    cdef int c_num_sweeps = num_sweeps if num_sweeps else -1
    cdef c_bool c_one_shot = one_shot
    cdef int result = 0

    schedule_timestamp = device.pybladerf_get_timestamp(pybladerf.pybladerf_direction.PYBLADERF_RX) + time_1ms * 150

    for i in range(8):
        quick_tunes[tune_step].quick_tune.rffe_profile = free_rffe_profile
        result = cbladerf.bladerf_schedule_retune(c_device, formated_channel, schedule_timestamp, quick_tunes[tune_step].frequency, &quick_tunes[tune_step].quick_tune)
        if result != 0:
            sys.stderr.write(f'pybladerf_schedule_retune() failed: {cbladerf.bladerf_strerror(result).decode("utf-8")} {result}\n')
            working_sdrs[device_id].store(0)

        sweep_steps[sweep_step_write_ptr].frequency = quick_tunes[tune_step].frequency
        sweep_steps[sweep_step_write_ptr].schedule_time = schedule_timestamp + await_time
        sweep_step_write_ptr = (sweep_step_write_ptr + 1) % 8

        free_rffe_profile = (free_rffe_profile + 1) % rffe_profiles
        schedule_timestamp += await_time + fft_size
        tune_step = (tune_step + 1) % tune_steps

    sweep_time = get_time()
    with nogil:
        while working_sdrs[device_id].load():

                if node == NULL:
                    if not empty_raw_data.empty():
                        empty_raw_data_mutex.lock()
                        node = empty_raw_data.front()
                        empty_raw_data.pop()
                        empty_raw_data_mutex.unlock()
                    else:
                        node = init_node(node_buffer_size)

                node.frequency = sweep_steps[sweep_step_read_ptr].frequency
                node.time = sweep_time

                c_meta.timestamp = sweep_steps[sweep_step_read_ptr].schedule_time
                result = cbladerf.bladerf_sync_rx(c_device, <void*> node.buffer, fft_size, c_meta, 0)
                sweep_step_read_ptr = (sweep_step_read_ptr + 1) % 8

                if result == -14:
                    fprintf(stderr, "Timestamp is in the past, restarting...\n")

                    tune_step = 0
                    free_rffe_profile = 0
                    sweep_step_read_ptr = 0
                    sweep_step_write_ptr = 0

                    cbladerf.bladerf_get_timestamp(c_device, cbladerf.bladerf_direction.BLADERF_RX, &schedule_timestamp)

                    for i in range(8):
                        quick_tunes[tune_step].quick_tune.rffe_profile = free_rffe_profile
                        result = cbladerf.bladerf_schedule_retune(c_device, formated_channel, schedule_timestamp, quick_tunes[tune_step].frequency, &quick_tunes[tune_step].quick_tune)
                        if result != 0:
                            fprintf(stderr, "pybladerf_schedule_retune() failed: %s %d", cbladerf.bladerf_strerror(result), result)
                            working_sdrs[device_id].store(0)
                            break

                        sweep_steps[sweep_step_write_ptr].frequency = quick_tunes[tune_step].frequency
                        sweep_steps[sweep_step_write_ptr].schedule_time = schedule_timestamp + await_time
                        sweep_step_write_ptr = (sweep_step_write_ptr + 1) % 8

                        free_rffe_profile = (free_rffe_profile + 1) % rffe_profiles
                        schedule_timestamp += await_time + fft_size
                        tune_step = (tune_step + 1) % tune_steps
                    continue

                elif result != 0:
                    fprintf(stderr, "pybladerf_sync_rx() failed: %s %d", cbladerf.bladerf_strerror(result), result)
                    working_sdrs[device_id].store(0)
                    break

                raw_data_mutex.lock()
                raw_data.push(node)
                raw_data_mutex.unlock()
                node = NULL

                accepted_samples += fft_size

                quick_tunes[tune_step].quick_tune.rffe_profile = free_rffe_profile
                result = cbladerf.bladerf_schedule_retune(c_device, formated_channel, schedule_timestamp, quick_tunes[tune_step].frequency, &quick_tunes[tune_step].quick_tune)
                if result != 0:
                    fprintf(stderr, "pybladerf_schedule_retune() failed: %s %d", cbladerf.bladerf_strerror(result), result)
                    working_sdrs[device_id].store(0)
                    break

                sweep_steps[sweep_step_write_ptr].frequency = quick_tunes[tune_step].frequency
                sweep_steps[sweep_step_write_ptr].schedule_time = schedule_timestamp + await_time
                sweep_step_write_ptr = (sweep_step_write_ptr + 1) % 8

                free_rffe_profile = (free_rffe_profile + 1) % rffe_profiles
                schedule_timestamp += await_time + fft_size
                tune_step = (tune_step + 1) % tune_steps

                if tune_step == 0:
                    sweep_time = get_time()
                    sweep_count += 1

                    if c_one_shot or (c_num_sweeps == sweep_count):
                        if sweep_count:
                            working_sdrs[device_id].store(0)

                time_now = get_time()
                time_difference = time_now - time_prev
                if time_difference >= 1.0:
                    if c_print_to_console:
                        sweep_rate = sweep_count / (time_now - time_start)
                        fprintf(stderr, "%llu total sweeps completed, %.2f sweeps/second\n", sweep_count, sweep_rate )

                    if accepted_samples == 0:
                        if c_print_to_console:
                            fprintf(stderr, "Couldn\'t transfer any data for one second.\n")
                        break

                    accepted_samples = 0
                    time_prev = time_now

    if print_to_console:
        if not working_sdrs[device_id].load():
            sys.stderr.write('\nExiting...\n')
        else:
            sys.stderr.write('\nExiting... [ pybladerf streaming stopped ]\n')

    working_sdrs[device_id].store(0)
    notify_finished.wait()
    sdr_ids.pop(device.serialno, None)

    while not raw_data.empty():
        node = raw_data.front()
        raw_data.pop()
        destroy_node(&node)
    while not empty_raw_data.empty():
        node = empty_raw_data.front()
        empty_raw_data.pop()
        destroy_node(&node)

    del empty_raw_data_mutex
    del raw_data_mutex

    if filename is not None:
        file.close()

    time_now = get_time()
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
