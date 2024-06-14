# MIT License

# Copyright (c) 2024 GvozdevLeonid

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

from libc.stdint cimport uint16_t, uint64_t
from python_bladerf import pybladerf
from queue import Queue
cimport numpy as np
import numpy as np
import threading
import datetime
cimport cython
import signal
import struct
import time
import sys

PY_FREQ_MIN_MHZ = 70_000_000  # 70 MHz
PY_FREQ_MAX_MHZ = 6_000_000_000  # 6000 MHz

cdef int frequency_step_1 = 0
cdef int frequency_step_2 = 0
cdef int frequency_step_3 = 0
cdef int pwr_1_start = 0
cdef int pwr_1_stop = 0
cdef int pwr_2_start = 0
cdef int pwr_2_stop = 0

cdef uint16_t FREQUENCY_STEP = 0
cdef uint64_t BLADERF_TIMESTAMP = 0
INTERLEAVED_OFFSET_RATIO = 0.375
LINEAR_OFFSET_RATIO = 0.5


run_available = True
delay_time = 6


def clear_queue(queue_to_clear: Queue):
    while not queue_to_clear.empty():
        queue_to_clear.get_nowait()


class TuneTime:
    def __init__(self, frequency_idx: int, frequency: int, timestamp: int) -> None:
        self.frequency_idx = frequency_idx
        self.frequency = frequency
        self.timestamp = timestamp

    def __str__(self) -> str:
        return str(self.frequency) + ' ' + str(self.timestamp)


def sigint_callback_handler(sig, frame):
    global run_available
    run_available = False
    sys.stderr.write('\n')


def init_signals():
    try:
        signal.signal(signal.SIGINT, sigint_callback_handler)
        signal.signal(signal.SIGILL, sigint_callback_handler)
        signal.signal(signal.SIGFPE, sigint_callback_handler)
        signal.signal(signal.SIGTERM, sigint_callback_handler)
        signal.signal(signal.SIGABRT, sigint_callback_handler)
    except Exception:
        pass


@cython.boundscheck(False)
@cython.wraparound(False)
cdef process_data(object data_queue, object file_object, object sweep_queue, int binary_output, int divider, int fftSize, int sample_rate, int sweep_style):
    global run_available

    cdef double norm_factor = 1.0 / fftSize
    cdef window = np.hanning(fftSize)

    while run_available:
        if not data_queue.empty():
            samples, frequency, time_str = data_queue.get()

            fftwOut = fft((samples[0::2] / divider + 1j * samples[1::2] / divider) * window)
            pwr = np.log10(np.abs(fftwOut * norm_factor) ** 2) * 10.0

            if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_LINEAR:
                pwr = fftshift(pwr)

            if binary_output:
                if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
                    record_length = 16 + (fftSize // 4) * 4
                    line = struct.pack('I', record_length)
                    line += struct.pack('Q', frequency)
                    line += struct.pack('Q', frequency + frequency_step_1)
                    line += struct.pack('<' + 'f' * (fftSize // 4), *pwr[pwr_1_start: pwr_1_stop])
                    line += struct.pack('I', record_length)
                    line += struct.pack('Q', frequency + frequency_step_2)
                    line += struct.pack('Q', frequency + frequency_step_3)
                    line += struct.pack('<' + 'f' * (fftSize // 4), *pwr[pwr_2_start: pwr_2_stop])

                else:
                    record_length = 16 + fftSize * 4
                    line = struct.pack('I', record_length)
                    line += struct.pack('Q', frequency)
                    line += struct.pack('Q', frequency + sample_rate)
                    line += struct.pack('<' + 'f' * fftSize, *pwr)

                if file_object is None:
                    sys.stdout.buffer.write(line)

                else:
                    file_object.write(line)

            elif sweep_queue is not None:
                if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
                    sweep_queue.put({
                        'timestamp': time_str,
                        'start_frequency': frequency,
                        'stop_frequency': frequency + frequency_step_1,
                        'array': pwr[pwr_1_start: pwr_1_stop]
                    })
                    sweep_queue.put({
                        'timestamp': time_str,
                        'start_frequency': frequency + frequency_step_2,
                        'stop_frequency': frequency + frequency_step_3,
                        'array': pwr[pwr_2_start: pwr_2_stop]
                    })

                else:
                    sweep_queue.put({
                        'timestamp': time_str,
                        'start_frequency': frequency,
                        'stop_frequency': frequency + sample_rate,
                        'array': pwr
                    })

            else:
                if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
                    line = f'{time_str}, {frequency}, {frequency + frequency_step_1}, {sample_rate / fftSize}, {fftSize}, '
                    pwr_1 = pwr[pwr_1_start: pwr_1_stop]
                    for i in range(len(pwr_1)):
                        line += f'{pwr_1[i]:.10f}, '
                    line += f'\n{time_str}, {frequency + frequency_step_2}, {frequency + frequency_step_3}, {sample_rate / fftSize}, {fftSize}, '
                    pwr_2 = pwr[pwr_2_start: pwr_2_stop]
                    for i in range(len(pwr_2)):
                        line += f'{pwr_2[i]:.10f}, '
                    line = line[:-2] + '\n'

                else:
                    line = f'{time_str}, {frequency}, {frequency + sample_rate}, {sample_rate / fftSize}, {fftSize}, '
                    for i in range(len(pwr)):
                        line += f'{pwr[i]:.2f}, '
                    line = line[:-2] + '\n'

                if file_object is None:
                    sys.stdout.write(line)
                else:
                    file_object.write(line)
        else:
            time.sleep(0.035)


@cython.boundscheck(False)
@cython.wraparound(False)
cdef schedule_frequency(object device, int channel, int fftSize, int time_1ms, list step_frequencies, dict step_quick_tunes, uint16_t steps, object tune_queue):
    global FREQUENCY_STEP, BLADERF_TIMESTAMP, delay_time

    cdef uint64_t await_time = BLADERF_TIMESTAMP + fftSize + time_1ms * delay_time
    cdef uint64_t schedule_time = BLADERF_TIMESTAMP + fftSize + time_1ms * (delay_time // 2)

    new_tune = TuneTime(
        FREQUENCY_STEP,
        step_frequencies[FREQUENCY_STEP],
        await_time,
    )

    device.pybladerf_schedule_retune(
        channel,
        schedule_time,
        0,
        step_quick_tunes[new_tune.frequency]
    )

    BLADERF_TIMESTAMP = await_time

    FREQUENCY_STEP += 1
    if FREQUENCY_STEP == steps:
        FREQUENCY_STEP = 0

    tune_queue.put_nowait(new_tune)


def pybladerf_sweep(frequencies: list = [70, 6000], gain: int = 20, bin_width: int = 100_000,
                    sample_rate: int = 61_000_000, bandwidth: int = 56_000_000, channel: int = 0, oversample: bool = False,
                    num_sweeps: int = None, binary_output: bool = False, one_shot: bool = False, sweep_queue: Queue = None, filename: str = None,
                    print_to_console: bool = True, device: pybladerf.PyBladerfDevice = None, device_identifier: str = '',
                    rxfir: pybladerf.pybladerf_rfic_rxfir = pybladerf.pybladerf_rfic_rxfir.PYBLADERF_RFIC_RXFIR_BYPASS,
                    sweep_style: pybladerf.pybladerf_sweep_style = pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED):

    global pwr_1_start, pwr_1_stop, pwr_2_start, pwr_2_stop, frequency_step_1, frequency_step_2, frequency_step_3
    global run_available, FREQUENCY_STEP, BLADERF_TIMESTAMP
    cdef uint64_t sweep_count = 0
    cdef double sweep_rate = 0

    run_available = True
    FREQUENCY_STEP = 0

    init_signals()
    file_object = None
    if filename is not None:
        file_object = open(filename, 'w' if not binary_output else 'wb')

    data_queue = Queue()
    tune_queue = Queue()

    step_quick_tunes = {}
    step_frequencies = []

    sample_rate = int(sample_rate)
    bandwidth = int(bandwidth)
    time_1ms = int(sample_rate // 1000)

    fftSize = int(sample_rate / bin_width)
    while ((fftSize + 4) % 8):
        fftSize += 1

    frequency_step_1 = sample_rate // 4
    frequency_step_2 = sample_rate // 2
    frequency_step_3 = (sample_rate * 3) // 4

    pwr_1_start = 1 + (fftSize * 5) // 8
    pwr_1_stop = 1 + (fftSize * 5) // 8 + fftSize // 4
    pwr_2_start = 1 + fftSize // 8
    pwr_2_stop = 1 + fftSize // 8 + fftSize // 4

    dtype = np.int8 if oversample else np.int16
    cdef int divider = 127 if oversample else 2048

    samples = np.empty(fftSize * 2, dtype=dtype)

    processing_thread = threading.Thread(target=process_data, args=(data_queue, file_object, sweep_queue, binary_output, divider, fftSize, sample_rate, sweep_style))
    processing_thread.daemon = True
    processing_thread.start()

    meta = pybladerf.pybladerf_metadata()
    channel = pybladerf.PYBLADERF_CHANNEL_RX(channel)

    if device is None:
        device = pybladerf.pybladerf_open(device_identifier)

    if oversample:
        device.pybladerf_enable_feature(
            pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE,
            True)
    else:
        device.pybladerf_enable_feature(
            pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE,
            False)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_tuning_mode({pybladerf.pybladerf_tuning_mode.PYBLADERF_TUNING_MODE_FPGA})\n')
    device.pybladerf_set_tuning_mode(pybladerf.pybladerf_tuning_mode.PYBLADERF_TUNING_MODE_FPGA)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_sample_rate({channel}, {sample_rate / 1e6 :.3f} MHz)\n')
    device.pybladerf_set_sample_rate(channel, sample_rate)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_bandwidth({channel}, {bandwidth / 1e6 :.3f} MHz)\n')
    device.pybladerf_set_bandwidth(channel, bandwidth)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_gain_mode({channel}, {pybladerf.pybladerf_gain_mode.PYBLADERF_GAIN_MGC})\n')
    device.pybladerf_set_gain_mode(channel, pybladerf.pybladerf_gain_mode.PYBLADERF_GAIN_MGC)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_rfic_rx_fir({rxfir})\n')
    device.pybladerf_set_rfic_rx_fir(rxfir)

    device.pybladerf_set_gain(channel, gain)
    if print_to_console:
        sys.stderr.write(f'Sweeping from {frequencies[0]} MHz to {frequencies[1]} MHz\n')

    cdef uint64_t frequency_range = int((frequencies[1] - frequencies[0]) * 1e6)
    cdef uint16_t steps = 1 + (frequency_range - 1) // sample_rate
    cdef uint64_t frequency = (frequencies[0] * 1e6)
    cdef uint64_t offset = sample_rate * LINEAR_OFFSET_RATIO

    if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
        offset = sample_rate * INTERLEAVED_OFFSET_RATIO
        steps *= 2

    for i in range(steps):
        device.pybladerf_set_frequency(channel, frequency + offset)
        quick_tune = device.pybladerf_get_quick_tune(channel)

        step_quick_tunes[frequency] = quick_tune
        step_frequencies.append(frequency)

        if sweep_style == pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED:
            if i % 2 == 0:
                frequency += sample_rate / 4
            else:
                frequency += 3 * sample_rate / 4
        else:
            frequency += sample_rate

    device.pybladerf_sync_config(
        layout=pybladerf.pybladerf_channel_layout.PYBLADERF_RX_X1,
        format=pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC8_Q7_META if oversample else pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC16_Q11_META,
        num_buffers=32,
        buffer_size=16384,
        num_transfers=16,
        stream_timeout=0,
    )

    device.pybladerf_enable_module(channel, True)
    BLADERF_TIMESTAMP = device.pybladerf_get_timestamp(pybladerf.pybladerf_direction.PYBLADERF_RX)
    for i in range(9):
        schedule_frequency(device, channel, fftSize, time_1ms, step_frequencies, step_quick_tunes, steps, tune_queue)

    cdef double time_start = time.time()
    cdef double time_prev = time.time()

    time_str = datetime.datetime.now().strftime("%Y-%m-%d, %H:%M:%S.%f")
    while run_available:
        current_tune = tune_queue.get()
        meta.timestamp = current_tune.timestamp

        try:
            device.pybladerf_sync_rx(samples, fftSize, metadata=meta, timeout_ms=500)
            data_queue.put_nowait((samples.copy(), current_tune.frequency, time_str))
            schedule_frequency(device, channel, fftSize, time_1ms, step_frequencies, step_quick_tunes, steps, tune_queue)

            if current_tune.frequency == step_frequencies[-1]:
                time_str = datetime.datetime.now().strftime("%Y-%m-%d, %H:%M:%S.%f")
                sweep_count += 1

        except pybladerf.PYBLADERF_ERR_TIME_PAST:
            print('PYBLADERF_ERR_TIME_PAST')
            tune_queue.queue.clear()
            device.pybladerf_cancel_scheduled_retunes(channel)

            time_str = datetime.datetime.now().strftime("%Y-%m-%d, %H:%M:%S.%f")
            BLADERF_TIMESTAMP = device.pybladerf_get_timestamp(pybladerf.pybladerf_direction.PYBLADERF_RX) + time_1ms * 50
            FREQUENCY_STEP = step_frequencies.index(current_tune.frequency)
            for i in range(3):
                schedule_frequency(device, channel, fftSize, time_1ms, step_frequencies, step_quick_tunes, steps, tune_queue)

        if one_shot or (num_sweeps == sweep_count):
            run_available = False

        time_now = time.time()
        if time_now - time_prev >= 1:
            time_prev = time_now
            sweep_rate = sweep_count / (time_now - time_start)
            sys.stderr.write(f'{sweep_count} total sweeps completed, {round(sweep_rate, 2)} sweeps/second\n')

    if filename is not None:
        file_object.close()

    if print_to_console:
        if not run_available:
            sys.stderr.write('Exiting...\n')
        else:
            sys.stderr.write('Exiting... [ pybladerf streaming stopped ]\n')

    time_now = time.time()
    time_difference = time_now - time_prev
    if sweep_rate == 0 and time_difference > 0:
        sweep_rate = sweep_count / (time_now - time_start)

    if print_to_console:
        sys.stderr.write(f'Total sweeps: {sweep_count} in {time_now - time_start:.5f} seconds ({sweep_rate :.2f} sweeps/second)\n')

    try:
        device.pybladerf_enable_module(channel, False)
        device.pybladerf_close()
        if print_to_console:
            sys.stderr.write('pybladerf_close() done\n')

    except RuntimeError as e:
        sys.stderr.write(f'{e}\n')

    run_available = False
    clear_queue(sweep_queue)
