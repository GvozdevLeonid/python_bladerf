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

# distutils: language = c++
# cython: language_level=3str
from libc.stdint cimport uint64_t, uint32_t, uint16_t, uint8_t, uintptr_t
from python_bladerf.pylibbladerf.ctime cimport timespec, timespec_get
from python_bladerf.pylibbladerf cimport pybladerf as c_pybladerf
from python_bladerf import pybladerf
from libcpp cimport bool as c_bool
from libcpp.atomic cimport atomic
cimport numpy as cnp
import numpy as np
import threading
cimport cython
import signal
import time
import sys
import os

cnp.import_array()

FREQ_RX_MIN_MHZ = 70  # MHz
FREQ_TX_MIN_MHZ = 47  # MHz
FREQ_MAX_MHZ = 6_000  # MHZ
FREQ_RX_MIN_HZ = int(FREQ_RX_MIN_MHZ * 1e6)  # Hz
FREQ_TX_MIN_HZ = int(FREQ_TX_MIN_MHZ * 1e6)  # Hz
FREQ_MAX_HZ = int(FREQ_MAX_MHZ * 1e6)  # Hz

SAMPLES_TO_XFER_MAX = 9_223_372_036_854_775_808

MIN_SAMPLE_RATE = 520_834
MAX_SAMPLE_RATE = 61_440_000

MIN_BASEBAND_FILTER_BANDWIDTHS = 200_000  # MHz
MAX_BASEBAND_FILTER_BANDWIDTHS = 56_000_000  # MHz

DEFAULT_FREQUENCY = 900_000_000  # 900 MHz

cdef atomic[uint8_t] working_sdrs[16]
cdef dict sdr_ids = {}

cdef struct TransferStatus:
    atomic[uint64_t] byte_count
    atomic[uint64_t] stream_power
    c_bool tx_complete

cdef double get_timestamp() noexcept nogil:
    cdef timespec ts

    if timespec_get(&ts, 1) != 0:
        return <double>ts.tv_sec + <double>ts.tv_nsec / 1000000000.0
    else:
        with gil:
            return time.time()


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
cpdef void rx_process(c_pybladerf.PyBladerfDevice device,
                      uint8_t device_id,
                      uintptr_t transfer_status_ptr,
                      uint8_t channel,
                      uint8_t oversample,
                      object notify_finished,
                      object rx_buffer,
                      object file,
                      int num_samples):

    global working_sdrs

    cdef TransferStatus* transfer_status = <TransferStatus*> transfer_status_ptr

    cdef uint64_t to_read
    cdef cnp.ndarray accepted_data

    cdef uint64_t samples_per_transfer = int(os.environ.get('pybladerf_transfer_samples_per_transfer', 65536))
    cdef uint16_t divider = 128 if oversample else 2048
    cdef uint8_t bytes_per_sample = 2 if oversample else 4
    cdef cnp.ndarray buffer = np.empty(samples_per_transfer * 2, dtype=np.int8 if oversample else np.int16)

    device.pybladerf_enable_module(channel, True)
    while working_sdrs[device_id].load():
        device.pybladerf_sync_rx(buffer, samples_per_transfer, None, 0)

        transfer_status.byte_count.fetch_add(samples_per_transfer * bytes_per_sample)
        transfer_status.stream_power.fetch_add(np.sum(buffer[:samples_per_transfer * 2].astype(np.int32) ** 2))
        to_read = samples_per_transfer

        if num_samples:
            if (to_read > num_samples):
                to_read = num_samples
            num_samples -= to_read

        accepted_data = (buffer[:to_read * 2:2] / divider + 1j * buffer[1:to_read * 2:2] / divider).astype(np.complex64)

        if rx_buffer is not None:
            rx_buffer.append(accepted_data)
        else:
            accepted_data.tofile(file)

        if num_samples == 0:
            working_sdrs[device_id].store(0)

    notify_finished.set()


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef void tx_process(c_pybladerf.PyBladerfDevice device,
                      uint8_t device_id,
                      uintptr_t transfer_status_ptr,
                      uint8_t channel,
                      uint8_t oversample,
                      uint8_t repeat_tx,
                      object notify_finished,
                      object tx_buffer,
                      object file,
                      int num_samples):

    global working_sdrs

    cdef TransferStatus* transfer_status = <TransferStatus*> transfer_status_ptr

    cdef bytes raw_data
    cdef uint64_t writed = 0
    cdef uint64_t to_write = 0
    cdef uint64_t rewrited = 0
    cdef cnp.ndarray sent_data
    cdef cnp.ndarray scaled_data
    cdef uint8_t bytes_per_sample = 2 if oversample else 4
    cdef uint32_t samples_per_transfer = int(os.environ.get('pybladerf_transfer_samples_per_transfer', 65536))
    cdef uint16_t divider = 128 if oversample else 2048
    cdef object dtype = np.int8 if oversample else np.int16
    cdef cnp.ndarray buffer = np.empty(samples_per_transfer * 2, dtype=dtype)

    device.pybladerf_enable_module(channel, True)
    while working_sdrs[device_id].load():
        to_write = samples_per_transfer

        if num_samples:
            if (to_write > num_samples):
                to_write = num_samples
            num_samples -= to_write

        if tx_buffer is not None:

            sent_data = tx_buffer.get_chunk(to_write, ring=repeat_tx, wait=True, timeout=0.5)

            if len(sent_data):
                writed = len(sent_data)
            else:
                # buffer is empty or finished
                transfer_status.tx_complete = True
                working_sdrs[device_id].store(0)
                break

            scaled_data = (sent_data.view(np.float32) * divider).astype(dtype)
            buffer[0:writed * 2:2] = scaled_data[0::2]
            buffer[1:writed * 2:2] = scaled_data[1::2]

            device.pybladerf_sync_tx(buffer, writed, None, 0)
            transfer_status.byte_count.fetch_add(writed * bytes_per_sample)
            transfer_status.stream_power.fetch_add(np.sum(buffer[:writed * 2].astype(np.int32) ** 2))

            # limit samples
            if num_samples == 0:
                transfer_status.tx_complete = True
                working_sdrs[device_id].store(0)

        else:
            raw_data = file.read(to_write * 8)
            if len(raw_data):
                writed = len(raw_data) // 8
            elif file.tell() < 1:
                # file is empty
                working_sdrs[device_id].store(0)
                break
            else:
                writed = 0

            sent_data = np.frombuffer(raw_data, dtype=np.complex64)
            
            scaled_data = (sent_data.view(np.float32) * divider).astype(dtype)
            buffer[0:writed * 2:2] = scaled_data[0::2]
            buffer[1:writed * 2:2] = scaled_data[1::2]

            # limit samples
            if num_samples == 0:
                device.pybladerf_sync_tx(buffer, writed, None, 0)
                transfer_status.byte_count.fetch_add(writed * bytes_per_sample)
                transfer_status.stream_power.fetch_add(np.sum(buffer[:writed * 2].astype(np.int32) ** 2))
                transfer_status.tx_complete = True
                working_sdrs[device_id].store(0)
                continue

            # buffer is full
            if to_write == writed:
                device.pybladerf_sync_tx(buffer, writed, None, 0)
                transfer_status.byte_count.fetch_add(writed * bytes_per_sample)
                transfer_status.stream_power.fetch_add(np.sum(buffer[:writed * 2].astype(np.int32) ** 2))
                continue

            # file is finished
            if not repeat_tx:
                device.pybladerf_sync_tx(buffer, writed, None, 0)
                transfer_status.byte_count.fetch_add(writed * bytes_per_sample)
                transfer_status.stream_power.fetch_add(np.sum(buffer[:writed * 2].astype(np.int32) ** 2))
                transfer_status.tx_complete = True
                working_sdrs[device_id].store(0)
                continue

            # repeat file
            while writed < to_write:
                file.seek(0)
                raw_data = file.read((to_write - writed) * 8)
                if len(raw_data):
                    rewrited = len(raw_data) // 8
                else:
                    device.pybladerf_sync_tx(buffer, writed, None, 0)
                    transfer_status.byte_count.fetch_add(writed * bytes_per_sample)
                    transfer_status.stream_power.fetch_add(np.sum(buffer[:writed * 2].astype(np.int32) ** 2))
                    transfer_status.tx_complete = True
                    working_sdrs[device_id].store(0)
                    continue

                sent_data = np.frombuffer(raw_data, dtype=np.complex64)
                scaled_data = (sent_data.view(np.float32) * divider).astype(dtype)
                buffer[writed * 2:(writed + rewrited) * 2:2] = scaled_data[0::2]
                buffer[writed * 2 + 1:(writed + rewrited) * 2:2] = scaled_data[1::2]

                writed += rewrited

            device.pybladerf_sync_tx(buffer, writed, None, 0)
            transfer_status.byte_count.fetch_add(writed * bytes_per_sample)
            transfer_status.stream_power.fetch_add(np.sum(buffer[:writed * 2].astype(np.int32) ** 2))
            continue

    notify_finished.set()


def pybladerf_transfer(frequency: int | None = None, sample_rate: int = 10_000_000, baseband_filter_bandwidth: int | None = None,
                       gain: int = 0, channel: int = 0, oversample: bool = False, antenna_enable: bool = False,
                       repeat_tx: bool = False, synchronize: bool = False, num_samples: int | None = None, serial_number: str | None = None,
                       rx_filename: str | None = None, tx_filename: str | None = None, rx_buffer: object | None = None, tx_buffer: object | None = None,
                       print_to_console: bool = True) -> None:

    global working_sdrs, sdr_ids

    cdef uint8_t device_id = init_signals()
    cdef c_pybladerf.PyBladerfDevice device
    cdef uint8_t formated_channel

    if serial_number is None:
        device = pybladerf.pybladerf_open()
    else:
        device = pybladerf.pybladerf_open_by_serial(serial_number)

    working_sdrs[device_id].store(1)
    sdr_ids[device.serialno] = device_id

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
        formated_channel = pybladerf.PYBLADERF_CHANNEL_RX(channel)
    elif tx_buffer is not None or tx_filename is not None:
        formated_channel = pybladerf.PYBLADERF_CHANNEL_TX(channel)

    if frequency is not None:
        if (rx_buffer is not None or rx_filename is not None) and frequency > FREQ_MAX_HZ or frequency < FREQ_RX_MIN_HZ:
            raise RuntimeError(f'frequency for RX must be between {FREQ_RX_MIN_HZ} and {FREQ_MAX_HZ}')
        if (tx_buffer is not None or tx_filename is not None) and frequency > FREQ_MAX_HZ or frequency < FREQ_TX_MIN_HZ:
            raise RuntimeError(f'frequency for RX must be between {FREQ_TX_MIN_HZ} and {FREQ_MAX_HZ}')
    else:
        frequency = DEFAULT_FREQUENCY

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
        sys.stderr.write(f'call pybladerf_trigger_init({formated_channel}, {pybladerf.pybladerf_trigger_signal.PYBLADERF_TRIGGER_MINI_EXP_1})\n')
    trigger = device.pybladerf_trigger_init(formated_channel, pybladerf.pybladerf_trigger_signal.PYBLADERF_TRIGGER_MINI_EXP_1)

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
        sys.stderr.write(f'call pybladerf_set_frequency({formated_channel}, {frequency} Hz / {frequency / 1e6 :.3f} MHz)\n')
    device.pybladerf_set_frequency(formated_channel, frequency)

    if print_to_console:
        sys.stderr.write(f'call pybladerf_set_gain_mode({formated_channel}, {pybladerf.pybladerf_gain_mode.PYBLADERF_GAIN_MGC})\n')
    device.pybladerf_set_gain_mode(formated_channel, pybladerf.pybladerf_gain_mode.PYBLADERF_GAIN_MGC)
    device.pybladerf_set_gain(formated_channel, gain)

    if antenna_enable:
        if print_to_console:
            sys.stderr.write(f'call pybladerf_set_bias_tee({formated_channel}, True)\n')
        device.pybladerf_set_bias_tee(formated_channel, True)

    rx_file = open(rx_filename, 'wb') if rx_filename not in ('-', None) else (sys.stdout.buffer if rx_filename == '-' else None)
    tx_file = open(tx_filename, 'rb') if tx_filename not in ('-', None) else (sys.stdin.buffer if tx_filename == '-' else None)
    notify_finished = threading.Event()

    cdef TransferStatus transfer_status
    if rx_buffer is not None or rx_filename is not None:
        device.pybladerf_sync_config(
            layout=pybladerf.pybladerf_channel_layout.PYBLADERF_RX_X1,
            data_format=pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC8_Q7 if oversample else pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC16_Q11,
            num_buffers=int(os.environ.get('pybladerf_transfer_num_buffers', 4096)),
            buffer_size=int(os.environ.get('pybladerf_transfer_buffer_size', 8192)),
            num_transfers=int(os.environ.get('pybladerf_transfer_num_transfers', 64)),
            stream_timeout=0,
        )

        processing_thread = threading.Thread(target=rx_process, args=(
            device,
            device_id,
            <uintptr_t> &transfer_status,
            formated_channel,
            1 if oversample else 0,
            notify_finished,
            rx_buffer,
            rx_file,
            num_samples if num_samples else -1
        ), daemon=True)
        processing_thread.start()

    elif tx_buffer is not None or tx_filename is not None:
        device.pybladerf_sync_config(
            layout=pybladerf.pybladerf_channel_layout.PYBLADERF_TX_X1,
            data_format=pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC8_Q7 if oversample else pybladerf.pybladerf_format.PYBLADERF_FORMAT_SC16_Q11,
            num_buffers=int(os.environ.get('pybladerf_transfer_num_buffers', 4096)),
            buffer_size=int(os.environ.get('pybladerf_transfer_buffer_size', 8192)),
            num_transfers=int(os.environ.get('pybladerf_transfer_num_transfers', 64)),
            stream_timeout=0,
        )

        processing_thread = threading.Thread(target=tx_process, args=(
            device,
            device_id,
            <uintptr_t> &transfer_status,
            formated_channel,
            1 if oversample else 0,
            1 if repeat_tx else 0,
            notify_finished,
            tx_buffer,
            tx_file,
            num_samples if num_samples else -1
        ), daemon=True)
        processing_thread.start()

    if not synchronize:
        device.pybladerf_trigger_fire(trigger)

    if num_samples and print_to_console:
        sys.stderr.write(f'samples_to_xfer {num_samples}/{num_samples / (5e5 if oversample else 25e4):.3f} MB\n')

    cdef double time_start = get_timestamp()
    cdef double time_prev = get_timestamp()
    cdef double time_difference = 0
    cdef uint64_t stream_power = 0
    cdef double dB_full_scale = 0
    cdef uint64_t byte_count = 0
    cdef double time_now = 0

    cdef uint16_t max_scale = 127 if oversample else 2047

    while working_sdrs[device_id].load():
        time.sleep(0.05)
        time_now = get_timestamp()
        time_difference = time_now - time_prev
        if time_difference >= 1.0:
            if print_to_console:
                byte_count = transfer_status.byte_count.load()
                stream_power = transfer_status.stream_power.load()

                transfer_status.byte_count.store(0)
                transfer_status.stream_power.store(0)

                if byte_count == 0 and synchronize:
                    sys.stderr.write("Waiting for trigger...\n")
                elif byte_count != 0 and not transfer_status.tx_complete:
                    dB_full_scale = 10 * np.log10(stream_power / ((byte_count / 2) * max_scale ** 2))
                    sys.stderr.write(f'{(byte_count / time_difference) / 1e6:.1f} MB/second, average power {dB_full_scale:.1f} dBfs\n')
                elif byte_count == 0 and not synchronize and not transfer_status.tx_complete:
                    if print_to_console:
                        sys.stderr.write('Couldn\'t transfer any data for one second.\n')
                    break

            time_prev = time_now

    time_now = time.time()
    if print_to_console:
        if not working_sdrs[device_id].load():
            sys.stderr.write('\nExiting...\n')
        else:
            sys.stderr.write('\nExiting... [ pybladerf streaming stopped ]\n')

    working_sdrs[device_id].store(0)
    sdr_ids.pop(device.serialno, None)
    notify_finished.wait()

    trigger.role = pybladerf.pybladerf_trigger_role.PYBLADERF_TRIGGER_ROLE_DISABLED
    device.pybladerf_trigger_arm(trigger, False)

    if print_to_console:
        sys.stderr.write(f'Total time: {time_now - time_start:.5f} seconds\n')

    if rx_filename not in ('-', None):
        rx_file.close()

    if tx_filename not in ('-', None):
        tx_file.close()

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
