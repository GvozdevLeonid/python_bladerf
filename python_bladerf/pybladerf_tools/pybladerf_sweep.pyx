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

# cython: language_level=3str
try:
    from pyfftw.interfaces.numpy_fft import fft, fftshift  # type: ignore
except ImportError:
    try:
        from scipy.fft import fft, fftshift  # type: ignore
    except ImportError:
        from numpy.fft import fft, fftshift  # type: ignore

from libc.stdint cimport uint32_t, uint64_t
from python_bladerf import pybladerf
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

PY_FREQ_MIN_MHZ = 70  # 70 MHz
PY_FREQ_MAX_MHZ = 6_000  # 6000 MHZ
PY_FREQ_MIN_HZ = int(PY_FREQ_MIN_MHZ * 1e6)  # Hz
PY_FREQ_MAX_HZ = int(PY_FREQ_MAX_MHZ * 1e6)  # Hz

MIN_SAMPLE_RATE = 520_834
MAX_SAMPLE_RATE = 61_440_000

MIN_BASEBAND_FILTER_BANDWIDTHS = 200_000  # MHz
MAX_BASEBAND_FILTER_BANDWIDTHS = 56_000_000  # MHz

INTERLEAVED_OFFSET_RATIO = 0.375
LINEAR_OFFSET_RATIO = 0.5

cdef dict run_available = {}
cdef dict device_data = {}


def sigint_callback_handler(sig, frame):
    global run_available
    for device in run_available.keys():
        run_available[device] = False

def init_signals():
    try:
        signal.signal(signal.SIGINT, sigint_callback_handler)
        signal.signal(signal.SIGILL, sigint_callback_handler)
        signal.signal(signal.SIGTERM, sigint_callback_handler)
        signal.signal(signal.SIGHUP, sigint_callback_handler)
        signal.signal(signal.SIGABRT, sigint_callback_handler)
    except Exception:
        pass


@cython.boundscheck(False)
@cython.wraparound(False)
cdef void process_data(object device):
    global run_available, device_data

    cdef dict current_device_data = device_data[device.serialno]
    cdef object event_finished = current_device_data['event']

    cdef double norm_factor = 1 / current_device_data['fft_size']
    cdef object sweep_style = current_device_data['sweep_style']
    cdef uint64_t sample_rate = current_device_data['sample_rate']
    cdef uint32_t fft_size = current_device_data['fft_size']
    cdef cnp.ndarray window = current_device_data['window']
    cdef uint32_t divider = current_device_data['divider']

    cdef cnp.ndarray fftOut
    cdef cnp.ndarray buffer
    cdef cnp.ndarray pwr

    cdef uint32_t fft_1_start = 1 + (fft_size * 5) // 8
    cdef uint32_t fft_1_stop = 1 + (fft_size * 5) // 8 + fft_size // 4

    cdef uint32_t fft_2_start = 1 + fft_size // 8
    cdef uint32_t fft_2_stop = 1 + fft_size // 8 + fft_size // 4

    cdef uint64_t frequency = 0
    cdef str time_str
    cdef uint32_t i

    while run_available[device.serialno]:
        if not current_device_data['raw_data'].empty():
            frequency, time_str, buffer = current_device_data['raw_data'].get()

            fftOut = fft((buffer[::2] / divider + 1j * buffer[1::2] / divider) * window)
            pwr = np.log10(np.abs(fftOut * norm_factor) ** 2) * 10.0

            if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_LINEAR:
                pwr = fftshift(pwr)

            if current_device_data['binary_output']:
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

                current_device_data['file'].write(line)

            elif current_device_data['queue'] is not None:
                if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
                    current_device_data['queue'].put({
                        'timestamp': time_str,
                        'start_frequency': frequency,
                        'stop_frequency': frequency + sample_rate // 4,
                        'array': pwr[fft_1_start:fft_1_stop].astype(np.float32)
                    })
                    current_device_data['queue'].put({
                        'timestamp': time_str,
                        'start_frequency': frequency + sample_rate // 2,
                        'stop_frequency': frequency + (sample_rate * 3) // 4,
                        'array': pwr[fft_2_start:fft_2_stop].astype(np.float32)
                    })

                else:
                    current_device_data['queue'].put({
                        'timestamp': time_str,
                        'start_frequency': frequency,
                        'stop_frequency': frequency + sample_rate,
                        'array': pwr.astype(np.float32)
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

                current_device_data['file'].write(line)

        else:
            time.sleep(.035)

    event_finished.set()


def pybladerf_sweep(frequencies: list = None, sample_rate: int = 61_000_000, baseband_filter_bandwidth: int = None,
                           gain: int = 20, bin_width: int = 100_000, channel: int = 0, oversample: bool = False, antenna_enable: bool = False,
                           sweep_style: pybladerf.pybladerf_sweep_style = pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED, serial_number: str = None,
                           binary_output: bool = False, one_shot: bool = False, num_sweeps: int = None,
                           filename: str = None, queue: object = None,
                           print_to_console: bool = True,
                           ):

    global run_available, device_data
    init_signals()

    channel = pybladerf.PYBLADERF_CHANNEL_RX(channel)

    if serial_number is None:
        device = pybladerf.pybladerf_open()
    else:
        device = pybladerf.pybladerf_open_by_serial(serial_number)

    run_available[device.serialno] = True
    device.pybladerf_enable_feature(pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE, False)

    if oversample:
        sample_rate = int(sample_rate) if MIN_SAMPLE_RATE * 2 <= int(sample_rate) <= MAX_SAMPLE_RATE * 2 else 122_000_000
    else:
        sample_rate = int(sample_rate) if MIN_SAMPLE_RATE <= int(sample_rate) <= MAX_SAMPLE_RATE else 61_000_000

    if baseband_filter_bandwidth is None:
        baseband_filter_bandwidth = int(sample_rate * .75)
    baseband_filter_bandwidth = int(baseband_filter_bandwidth) if MIN_BASEBAND_FILTER_BANDWIDTHS <= int(baseband_filter_bandwidth) <= MAX_BASEBAND_FILTER_BANDWIDTHS else int(sample_rate * .75)

    cdef dict current_device_data = {
        'sweep_style': sweep_style if sweep_style in pybladerf.pybladerf_sweep_style else pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED,
        'sample_rate': sample_rate,
        'divider': 128 if oversample else 2048,
        'event': threading.Event(),

        'frequencies': [],
        'timestamps': Queue(),
        'raw_data': Queue(),
        'fft_size': None,
        'window': None,

        'binary_output': binary_output,
        'file': open(filename, 'w' if not binary_output else 'wb') if filename is not None else (sys.stdout.buffer if binary_output else sys.stdout),
        'queue': queue
    }

    real_min_freq_hz = PY_FREQ_MIN_HZ - sample_rate // 2
    real_max_freq_hz = PY_FREQ_MAX_HZ + sample_rate // 2

    if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
        offset = int(sample_rate * INTERLEAVED_OFFSET_RATIO)
    else:
        offset = int(sample_rate * LINEAR_OFFSET_RATIO)

    if frequencies is None:
        frequencies = [int(PY_FREQ_MIN_MHZ - sample_rate // 2e6), int(PY_FREQ_MAX_MHZ + sample_rate // 2e6)]

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_tuning_mode({pybladerf.pybladerf_tuning_mode.PYBLADERF_TUNING_MODE_FPGA})\n')
    device.pybladerf_set_tuning_mode(pybladerf.pybladerf_tuning_mode.PYBLADERF_TUNING_MODE_FPGA)

    if oversample:
        if print_to_console:
            sys.stderr.write(f'call pybladerf_enable_feature({pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE}, True)\n')
        device.pybladerf_enable_feature(pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE, True)
        samples_dtype = np.int8
    else:
        device.pybladerf_enable_feature(pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE, False)
        samples_dtype = np.int16

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_sample_rate({sample_rate / 1e6 :.3f} MHz)\n')
    device.pybladerf_set_sample_rate(channel, sample_rate)

    if not oversample:
        if print_to_console:
            sys.stderr.write(f'call pybladerf_set_bandwidth({channel}, {baseband_filter_bandwidth / 1e6 :.3f} MHz)\n')
        device.pybladerf_set_bandwidth(channel, baseband_filter_bandwidth)


    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_gain_mode({channel}, {pybladerf.pybladerf_gain_mode.PYBLADERF_GAIN_MGC})\n')
    device.pybladerf_set_gain_mode(channel, pybladerf.pybladerf_gain_mode.PYBLADERF_GAIN_MGC)
    device.pybladerf_set_gain(channel, gain)

    if antenna_enable:
        if print_to_console:
            sys.stderr.write(f'call pybladerf_set_bias_tee({channel}, True)\n')
        device.pybladerf_set_bias_tee(channel, True)

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

    shift_after = -1
    if len(calculated_frequencies) % 8 < 4:
        shift_after = len(calculated_frequencies) - len(calculated_frequencies) % 8

    for i, frequency in enumerate(calculated_frequencies):
        if i == shift_after:
            device.pybladerf_get_quick_tune(channel)
            device.pybladerf_get_quick_tune(channel)
            device.pybladerf_get_quick_tune(channel)

        device.pybladerf_set_frequency(channel, frequency + offset)
        current_device_data['frequencies'].append((frequency, device.pybladerf_get_quick_tune(channel)))

    fft_size = int(sample_rate / bin_width)
    if fft_size < 4:
        device.pybladerf_close()
        raise RuntimeError(f'bin_width should be no more than {sample_rate // 4} Hz')

    while ((fft_size + 4) % 8):
        fft_size += 1

    current_device_data['fft_size'] = fft_size
    current_device_data['window'] = np.hanning(fft_size)
    device_data[device.serialno] = current_device_data

    device.pybladerf_sync_config(
        layout=pybladerf.pybladerf_channel_layout.PYBLADERF_RX_X1,
        data_format=pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC8_Q7_META if oversample else pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC16_Q11_META,
        num_buffers=int(os.environ.get('pybladerf_sweep_num_buffers', 4096)),
        buffer_size=int(os.environ.get('pybladerf_sweep_buffer_size', 8192)),
        num_transfers=int(os.environ.get('pybladerf_sweep_num_transfers', 32)),
        stream_timeout=0,
    )

    device.pybladerf_enable_module(channel, True)

    processing_thread = threading.Thread(target=process_data, args=(device, ))
    processing_thread.daemon = True
    processing_thread.start()

    cdef uint64_t time_1ms = int(sample_rate // 1000)
    cdef uint64_t await_time = int(time_1ms * float(os.environ.get('pybladerf_sweep_await_time', 6)))
    cdef uint32_t tune_steps = len(current_device_data['frequencies'])
    cdef double time_start = time.time()
    cdef double time_prev = time.time()

    cdef uint64_t schedule_timestamp = 0
    cdef uint64_t accepted_samples = 0
    cdef double time_difference = 0
    cdef uint64_t sweep_count = 0
    cdef uint64_t timestamp = 0
    cdef uint32_t tune_step = 0
    cdef double sweep_rate = 0
    cdef double time_now = 0
    cdef str time_str

    meta = pybladerf.pybladerf_metadata()
    schedule_timestamp = device.pybladerf_get_timestamp(pybladerf.pybladerf_direction.PYBLADERF_RX) + time_1ms * 150

    for i in range(4):
        start_from, quick_tune = current_device_data['frequencies'][tune_step]
        device.pybladerf_schedule_retune(channel, schedule_timestamp, start_from + offset, quick_tune)
        current_device_data['timestamps'].put((start_from, schedule_timestamp + await_time))
        schedule_timestamp += await_time + fft_size
        tune_step = (tune_step + 1) % tune_steps

    time_str = datetime.datetime.now().strftime('%Y-%m-%d, %H:%M:%S.%f')
    while run_available[device.serialno]:
        try:

            frequency, timestamp = current_device_data['timestamps'].get()
            meta.timestamp = timestamp
            samples = np.empty(fft_size * 2, dtype=samples_dtype)

            device.pybladerf_sync_rx(samples, fft_size, metadata=meta, timeout_ms=0)
            current_device_data['raw_data'].put_nowait((frequency, time_str, samples))
            accepted_samples += fft_size

            start_from, quick_tune = current_device_data['frequencies'][tune_step]
            device.pybladerf_schedule_retune(channel, schedule_timestamp, start_from + offset, quick_tune)
            current_device_data['timestamps'].put((start_from, schedule_timestamp + await_time))
            schedule_timestamp += await_time + fft_size
            tune_step = (tune_step + 1) % tune_steps

            if tune_step == 0:
                time_str = datetime.datetime.now().strftime('%Y-%m-%d, %H:%M:%S.%f')
                sweep_count += 1

                if one_shot or (num_sweeps == sweep_count):
                    if sweep_count:
                        run_available[device.serialno] = False

            time_now = time.time()
            time_difference = time_now - time_prev
            if time_difference >= 1.0:
                if print_to_console:
                    sweep_rate = sweep_count / (time_now - time_start)
                    sys.stderr.write(f'{sweep_count} total sweeps completed, {round(sweep_rate, 2)} sweeps/second\n')

                if accepted_samples == 0:
                    if print_to_console:
                        sys.stderr.write('Couldn\'t transfer any data for one second.\n')
                    break

                accepted_samples = 0
                time_prev = time_now

        except pybladerf.PYBLADERF_ERR_TIME_PAST:
            sys.stderr.write('get PYBLADERF_ERR_TIME_PAST error, start sweep from the first frequency\n')

            device.pybladerf_cancel_scheduled_retunes(channel)
            current_device_data['timestamps'].queue.clear()
            tune_step = 0

            time_str = datetime.datetime.now().strftime("%Y-%m-%d, %H:%M:%S.%f")
            schedule_timestamp = device.pybladerf_get_timestamp(pybladerf.pybladerf_direction.PYBLADERF_RX) + time_1ms * 150

            for i in range(4):
                start_from, quick_tune = current_device_data['frequencies'][tune_step]
                device.pybladerf_schedule_retune(channel, schedule_timestamp, start_from + offset, quick_tune)
                current_device_data['timestamps'].put((start_from, schedule_timestamp + await_time))
                schedule_timestamp += await_time + fft_size
                tune_step = (tune_step + 1) % tune_steps

        except Exception as ex:
            sys.stderr.write(f'ERROR {ex}\n')
            break

    if print_to_console:
        if not run_available[device.serialno]:
            sys.stderr.write('\nExiting...\n')
        else:
            sys.stderr.write('\nExiting... [ pybladerf streaming stopped ]\n')
    
    run_available[device.serialno] = False
    current_device_data['event'].wait()

    if filename is not None:
        current_device_data['file'].close()

    time_now = time.time()
    time_difference = time_now - time_prev
    if sweep_rate == 0 and time_difference > 0:
        sweep_rate = sweep_count / (time_now - time_start)

    if print_to_console:
        sys.stderr.write(f'Total sweeps: {sweep_count} in {time_now - time_start:.5f} seconds ({sweep_rate :.2f} sweeps/second)\n')

    device_data.pop(device.serialno, None)
    run_available.pop(device.serialno, None)

    try:
        device.pybladerf_enable_module(channel, False)
    except Exception as ex:
            sys.stderr.write(f'{ex}\n')
    try:
        device.pybladerf_close()
        if print_to_console:
            sys.stderr.write('pybladerf_close() done\n')

    except Exception as ex:
        sys.stderr.write(f'{ex}\n')
