# MIT License

# Copyright (c) 2023-2024 GvozdevLeonid

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
from python_bladerf import pybladerf
from libc.stdint cimport uint32_t, uint64_t
cimport numpy as cnp
import numpy as np
import threading
cimport cython
import signal
import time
import sys
import os

cnp.import_array()

FREQ_MIN_HZ = 70_000_000
FREQ_MAX_HZ = 6_000_000_000

SAMPLES_TO_XFER_MAX = 9_223_372_036_854_775_808

MIN_SAMPLE_RATE = 520_834
MAX_SAMPLE_RATE = 61_440_000

MIN_BASEBAND_FILTER_BANDWIDTHS = 200_000  # MHz
MAX_BASEBAND_FILTER_BANDWIDTHS = 56_000_000  # MHz

DEFAULT_FREQUENCY = 900_000_000

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
cpdef void rx_process(object device):
    global run_available, device_data

    cdef dict current_device_data = device_data[device.serialno]

    cdef uint32_t to_read
    cdef cnp.ndarray accepted_data
    cdef uint32_t samples_per_transfer = int(os.environ.get('pybladerf_transfer_samples_per_transfer', 65536))
    cdef uint32_t divider = current_device_data['divider']
    cdef object dtype = np.int8 if current_device_data['oversample'] else np.int16
    cdef cnp.ndarray buffer = np.empty(samples_per_transfer * 2, dtype=dtype)

    device.pybladerf_enable_module(current_device_data['channel'], True)
    while run_available[device.serialno]:
        device.pybladerf_sync_rx(buffer, samples_per_transfer, None, 0)

        current_device_data['byte_count'] += samples_per_transfer * current_device_data['bytes_per_sample']
        current_device_data['stream_power'] += np.sum(buffer[:samples_per_transfer * 2].astype(np.int32) ** 2)
        to_read = samples_per_transfer

        if current_device_data['num_samples']:
            if (to_read > current_device_data['num_samples']):
                to_read = current_device_data['num_samples']
            current_device_data['num_samples'] -= to_read

        accepted_data = (buffer[:to_read * 2:2] / divider + 1j * buffer[1:to_read * 2:2] / divider).astype(np.complex64)

        if current_device_data['rx_buffer'] is not None:
            current_device_data['rx_buffer'].append(accepted_data)
        else:
            accepted_data.tofile(current_device_data['rx_file'])

        if current_device_data['num_samples'] == 0:
            run_available[device.serialno] = False

    device_data[device.serialno]['event'].set()


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef void tx_process(object device):
    global run_available, device_data

    cdef dict current_device_data = device_data[device.serialno]

    cdef bytes raw_data
    cdef uint64_t writed = 0
    cdef uint64_t to_write = 0
    cdef uint64_t rewrited = 0
    cdef cnp.ndarray sent_data
    cdef cnp.ndarray scaled_data
    cdef uint32_t samples_per_transfer = int(os.environ.get('pybladerf_transfer_samples_per_transfer', 65536))
    cdef uint32_t divider = current_device_data['divider']
    cdef object dtype = np.int8 if current_device_data['oversample'] else np.int16
    cdef cnp.ndarray buffer = np.empty(samples_per_transfer * 2, dtype=np.int8 if current_device_data['oversample'] else np.int16)

    device.pybladerf_enable_module(current_device_data['channel'], True)
    while run_available[device.serialno]:
        to_write = samples_per_transfer

        if current_device_data['num_samples']:
            if (to_write > current_device_data['num_samples']):
                to_write = current_device_data['num_samples']
            current_device_data['num_samples'] -= to_write

        if current_device_data['tx_buffer'] is not None:

            sent_data = current_device_data['tx_buffer'].get_chunk(to_write, ring=current_device_data['repeat_tx'], wait=True, timeout=0.5)

            if len(sent_data):
                writed = len(sent_data)
            else:
                # buffer is empty or finished
                current_device_data['tx_complete'] = True
                run_available[device.serialno] = False
                break

            scaled_data = (sent_data.view(np.float32) * divider).astype(dtype)
            buffer[0:writed * 2:2] = scaled_data[0::2]
            buffer[1:writed * 2:2] = scaled_data[1::2]

            device.pybladerf_sync_tx(buffer, writed, None, 0)
            current_device_data['byte_count'] += writed * current_device_data['bytes_per_sample']
            current_device_data['stream_power'] += np.sum(buffer[:writed * 2].astype(np.int32) ** 2)

            # limit samples
            if current_device_data['num_samples'] == 0:
                current_device_data['tx_complete'] = True
                run_available[device.serialno] = False

        else:
            raw_data = current_device_data['tx_file'].read(to_write * 8)
            if len(raw_data):
                writed = len(raw_data) // 8
            elif current_device_data['tx_file'].tell() < 1:
                # file is empty
                run_available[device.serialno] = False
                break
            else:
                writed = 0

            sent_data = np.frombuffer(raw_data, dtype=np.complex64)
            
            scaled_data = (sent_data.view(np.float32) * divider).astype(dtype)
            buffer[0:writed * 2:2] = scaled_data[0::2]
            buffer[1:writed * 2:2] = scaled_data[1::2]

            # limit samples
            if current_device_data['num_samples'] == 0:
                device.pybladerf_sync_tx(buffer, writed, None, 0)
                current_device_data['byte_count'] += writed * current_device_data['bytes_per_sample']
                current_device_data['stream_power'] += np.sum(buffer[:writed * 2].astype(np.int32) ** 2)
                current_device_data['tx_complete'] = True
                run_available[device.serialno] = False
                continue

            # buffer is full
            if to_write == writed:
                device.pybladerf_sync_tx(buffer, writed, None, 0)
                current_device_data['byte_count'] += writed * current_device_data['bytes_per_sample']
                current_device_data['stream_power'] += np.sum(buffer[:writed * 2].astype(np.int32) ** 2)
                continue

            # file is finished
            if not current_device_data['repeat_tx']:
                device.pybladerf_sync_tx(buffer, writed, None, 0)
                current_device_data['byte_count'] += writed * current_device_data['bytes_per_sample']
                current_device_data['stream_power'] += np.sum(buffer[:writed * 2].astype(np.int32) ** 2)
                current_device_data['tx_complete'] = True
                run_available[device.serialno] = False
                continue

            # repeat file
            while writed < to_write:
                current_device_data['tx_file'].seek(0)
                raw_data = current_device_data['tx_file'].read((to_write - writed) * 8)
                if len(raw_data):
                    rewrited = len(raw_data) // 8
                else:
                    device.pybladerf_sync_tx(buffer, writed, None, 0)
                    current_device_data['byte_count'] += writed * current_device_data['bytes_per_sample']
                    current_device_data['stream_power'] += np.sum(buffer[:writed * 2].astype(np.int32) ** 2)
                    current_device_data['tx_complete'] = True
                    run_available[device.serialno] = False
                    continue

                sent_data = np.frombuffer(raw_data, dtype=np.complex64)
                scaled_data = (sent_data.view(np.float32) * divider).astype(dtype)
                buffer[writed * 2:(writed + rewrited) * 2:2] = scaled_data[0::2]
                buffer[writed * 2 + 1:(writed + rewrited) * 2:2] = scaled_data[1::2]

                writed += rewrited

            device.pybladerf_sync_tx(buffer, writed, None, 0)
            current_device_data['byte_count'] += writed * current_device_data['bytes_per_sample']
            current_device_data['stream_power'] += np.sum(buffer[:writed * 2].astype(np.int32) ** 2)
            continue

    device_data[device.serialno]['event'].set()


cpdef void pybladerf_transfer(frequency: int = None, sample_rate: int = 10_000_000, baseband_filter_bandwidth: int = None,
                              gain: int = 0, channel: int = 0, oversample: bool = False, antenna_enable: bool = False,
                              repeat_tx: bool = False, synchronize: bool = False, num_samples: int = None, serial_number: str = None,
                              rx_filename: str = None, tx_filename: str = None, rx_buffer: object = None, tx_buffer: object = None,
                              print_to_console: bool = True):

    global run_available, device_data

    init_signals()

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

    if num_samples and num_samples >= SAMPLES_TO_XFER_MAX:
        raise RuntimeError(f'num_samples must be less than {SAMPLES_TO_XFER_MAX}')

    if (rx_buffer is not None or rx_filename is not None) and (tx_buffer is not None or tx_filename is not None):
        raise RuntimeError('BladeRF transfer cannot receive and send IQ samples at the same time.')

    elif rx_buffer is not None or rx_filename is not None:
        channel = pybladerf.PYBLADERF_CHANNEL_RX(channel)
    elif tx_buffer is not None or tx_filename is not None:
        channel = pybladerf.PYBLADERF_CHANNEL_TX(channel)

    cdef uint32_t max_scale = 127 if oversample else 2047
    cdef dict current_device_data = {
        'num_samples': num_samples,
        'divider': 128 if oversample else 2048,
        'oversample': oversample,
        'bytes_per_sample': 2 if oversample else 4,
        'event': threading.Event(),
        'repeat_tx': repeat_tx,
        'tx_complete': False,
        'stream_power': 0,
        'byte_count': 0,
        'channel': channel,

        'rx_file': open(rx_filename, 'wb') if rx_filename not in ('-', None) else (sys.stdout.buffer if rx_filename == '-' else None),
        'tx_file': open(tx_filename, 'rb') if tx_filename not in ('-', None) else (sys.stdin.buffer if tx_filename == '-' else None),
        'rx_buffer': rx_buffer,
        'tx_buffer': tx_buffer
    }
    device_data[device.serialno] = current_device_data

    if frequency is not None:
        if frequency > FREQ_MAX_HZ or frequency < FREQ_MIN_HZ:
            raise RuntimeError(f'frequency must be between {FREQ_MIN_HZ} and {FREQ_MAX_HZ}')
    else:
        frequency = DEFAULT_FREQUENCY

    if oversample:
        if print_to_console:
            sys.stderr.write(f'call pybladerf_enable_feature({pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE}, True)\n')
        device.pybladerf_enable_feature(pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE, True)
    else:
        device.pybladerf_enable_feature(pybladerf.pybladerf_feature.PYBLADERF_FEATURE_OVERSAMPLE, False)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_sample_rate({sample_rate / 1e6 :.3f} MHz)\n')
    device.pybladerf_set_sample_rate(channel, sample_rate)

    if not oversample:
        if print_to_console:
            sys.stderr.write(f'call pybladerf_set_bandwidth({channel}, {baseband_filter_bandwidth / 1e6 :.3f} MHz)\n')
        device.pybladerf_set_bandwidth(channel, baseband_filter_bandwidth)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_trigger_init({channel}, {pybladerf.pybladerf_trigger_signal.PYBLADERF_TRIGGER_MINI_EXP_1})\n')
    trigger = device.pybladerf_trigger_init(channel, pybladerf.pybladerf_trigger_signal.PYBLADERF_TRIGGER_MINI_EXP_1)

    if synchronize:
        if print_to_console:
            sys.stderr.write(f'set trigger role as {pybladerf.pybladerf_trigger_role.PYBLADERF_TRIGGER_ROLE_SLAVE}')
        trigger.role = pybladerf.pybladerf_trigger_role.PYBLADERF_TRIGGER_ROLE_SLAVE
    else:
        if print_to_console:
            sys.stderr.write(f'set trigger role as {pybladerf.pybladerf_trigger_role.PYBLADERF_TRIGGER_ROLE_MASTER}')
        trigger.role = pybladerf.pybladerf_trigger_role.PYBLADERF_TRIGGER_ROLE_MASTER

    if print_to_console:
        sys.stderr.write(f'call pybladerf_trigger_arm(trigger, True)\n')
    device.pybladerf_trigger_arm(trigger, True)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_frequency({channel}, {frequency} Hz / {frequency / 1e6 :.3f} MHz)\n')
    device.pybladerf_set_frequency(channel, frequency)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_gain_mode({channel}, {pybladerf.pybladerf_gain_mode.PYBLADERF_GAIN_MGC})\n')
    device.pybladerf_set_gain_mode(channel, pybladerf.pybladerf_gain_mode.PYBLADERF_GAIN_MGC)
    device.pybladerf_set_gain(channel, gain)

    if antenna_enable:
        if print_to_console:
            sys.stderr.write(f'call pybladerf_set_bias_tee({channel}, True)\n')
        device.pybladerf_set_bias_tee(channel, True)

    if rx_buffer is not None or rx_filename is not None:
        device.pybladerf_sync_config(
            layout=pybladerf.pybladerf_channel_layout.PYBLADERF_RX_X1,
            data_format=pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC8_Q7 if oversample else pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC16_Q11,
            num_buffers=int(os.environ.get('pybladerf_transfer_num_buffers', 4096)),
            buffer_size=int(os.environ.get('pybladerf_transfer_buffer_size', 8192)),
            num_transfers=int(os.environ.get('pybladerf_transfer_num_transfers', 32)),
            stream_timeout=0,
        )

        processing_thread = threading.Thread(target=rx_process, args=(device, ), daemon=True)
        processing_thread.start()

    elif tx_buffer is not None or tx_filename is not None:
        device.pybladerf_sync_config(
            layout=pybladerf.pybladerf_channel_layout.PYBLADERF_TX_X1,
            data_format=pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC8_Q7 if oversample else pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC16_Q11,
            num_buffers=int(os.environ.get('pybladerf_transfer_num_buffers', 4096)),
            buffer_size=int(os.environ.get('pybladerf_transfer_buffer_size', 8192)),
            num_transfers=int(os.environ.get('pybladerf_transfer_num_transfers', 32)),
            stream_timeout=0,
        )

        processing_thread = threading.Thread(target=tx_process, args=(device, ), daemon=True)
        processing_thread.start()

    if not synchronize:
        device.pybladerf_trigger_fire(trigger)

    if num_samples and print_to_console:
        sys.stderr.write(f'samples_to_xfer {num_samples}/{num_samples / (5e5 if oversample else 25e4):.3f} MB\n')

    cdef double time_start = time.time()
    cdef double time_prev = time.time()
    cdef double time_difference = 0
    cdef uint64_t stream_power = 0
    cdef double dB_full_scale = 0
    cdef uint64_t byte_count = 0
    while run_available[device.serialno]:
        time.sleep(0.05)
        time_now = time.time()
        time_difference = time_now - time_prev
        if time_difference >= 1.0:
            if print_to_console:
                byte_count, stream_power = current_device_data['byte_count'], current_device_data['stream_power']
                current_device_data['stream_power'], current_device_data['byte_count'] = 0, 0

                if byte_count == 0 and synchronize:
                    sys.stderr.write('Waiting for trigger...\n')
                elif byte_count != 0 and not current_device_data['tx_complete']:
                    dB_full_scale = 10 * np.log10(stream_power / ((byte_count / 2) * max_scale ** 2))
                    sys.stderr.write(f'{(byte_count / time_difference) / 1e6:.1f} MB/second, average power {dB_full_scale:.1f} dBfs\n')
                elif byte_count == 0 and not synchronize and not current_device_data['tx_complete']:
                    if print_to_console:
                        sys.stderr.write('Couldn\'t transfer any data for one second.\n')
                    break

            time_prev = time_now

    time_now = time.time()
    if print_to_console:
        if not run_available[device.serialno]:
            sys.stderr.write('\nExiting...\n')
        else:
            sys.stderr.write('\nExiting... [ pybladerf streaming stopped ]\n')

    run_available[device.serialno] = False
    current_device_data['event'].wait()

    trigger.role = pybladerf.pybladerf_trigger_role.PYBLADERF_TRIGGER_ROLE_DISABLED
    device.pybladerf_trigger_arm(trigger, False)

    if print_to_console:
        sys.stderr.write(f'Total time: {time_now - time_start:.5f} seconds\n')
    time.sleep(.5)

    if rx_filename not in ('-', None):
        current_device_data['rx_file'].close()

    if tx_filename not in ('-', None):
        current_device_data['tx_file'].close()

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
