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

from enum import IntEnum
from typing import Callable, Self

import numpy as np

def PYBLADERF_CHANNEL_RX(channel: int) -> int:
    '''Return rx channel by number (0, 1)'''
    ...

def PYBLADERF_CHANNEL_TX(channel: int) -> int:
    '''Return tx channel by number (0, 1)'''
    ...

def PYBLADERF_CHANNEL_IS_TX(channel: int) -> bool:
    '''Return True if channel is tx'''
    ...

def PYBLADERF_CHANNEL_IS_RX(channel: int) -> bool:
    '''Return True if channel is rx'''
    ...

PYBLADERF_CHANNEL_INVALID: int
'''Invalid channel'''
PYBLADERF_DIRECTION_MASK: int
'''Direction mask'''

PYBLADERF_RETUNE_NOW: int
'''Specifies that scheduled retune should occur immediately when using'''

PYBLADERF_META_STATUS_OVERRUN: int
'''This indicates that either the host (more likely) or the FPGA is not keeping up with the incoming samples.'''
PYBLADERF_META_STATUS_UNDERRUN: int
'''A sample underrun has occurred. This generally only occurs on the TX channel when the FPGA is starved of samples.'''
PYBLADERF_META_FLAG_TX_BURST_START: int
'''
Mark the associated buffer as the start of a burst transmission.

! NOTE !
    This is only used for the pybladerf_sync_tx() call.

When using this flag, the pybladerf_metadata.timestamp field should contain the timestamp at which samples should be sent.

Between specifying the PYBLADERF_META_FLAG_TX_BURST_START and PYBLADERF_META_FLAG_TX_BURST_END flags, there is no need for the user to the
pybladerf_metadata.timestamp field because the library will ensure the correct value is used, based upon the timestamp initially provided and the number of samples that have been sent.
'''
PYBLADERF_META_FLAG_TX_BURST_END: int
'''
Mark the associated buffer as the end of a burst transmission. This will flush the remainder of the sync interface's current working buffer and enqueue samples into the hardware's transmit FIFO.

As of libbladeRF v1.3.0, it is no longer necessary for the API user to ensure that the final 3 samples of a burst are 0i + 0j. libbladeRF now ensures this hardware requirement is upheld.

Specifying this flag and flushing the sync interface's working buffer implies that the next timestamp that can be transmitted is the current timestamp plus the duration of the burst that this flag is ending and the remaining length of the remaining buffer that is flushed. (The buffer size, in this case, is the `buffer_size` value passed to the previous pybladerf_sync_config() call.)

Rather than attempting to keep track of the number of samples sent with respect to buffer sizes, it is easiest to always assume 1 buffer's worth of time is required between bursts. In this case "buffer" refers to the `buffer_size` parameter provided to pybladerf_sync_config().) If this is too much time, consider using the PYBLADERF_META_FLAG_TX_UPDATE_TIMESTAMP flag.

! NOTE !
    This is only used for the pybladerf_sync_tx() call. It is ignored by the pybladerf_sync_rx() call.
'''
PYBLADERF_META_FLAG_TX_NOW: int
'''
Use this flag in conjunction with PYBLADERF_META_FLAG_TX_BURST_START to indicate that the burst should be transmitted as soon as possible, as opposed to waiting for a specific timestamp.

When this flag is used, there is no need to set the pybladerf_metadata.timestamp field.
'''
PYBLADERF_META_FLAG_TX_UPDATE_TIMESTAMP: int
'''
Use this flag within a burst (i.e., between the use of PYBLADERF_META_FLAG_TX_BURST_START and PYBLADERF_META_FLAG_TX_BURST_END) to specify that pybladerf_sync_tx() should read the pybladerf_metadata.timestamp field and zero-pad samples up to the specified timestamp. The provided samples will then be transmitted at that timestamp.

Use this flag when potentially flushing an entire buffer via the PYBLADERF_META_FLAG_TX_BURST_END would yield an unacceptably large gap in the transmitted samples.

In some applications where a transmitter is constantly transmitting with extremely small gaps (less than a buffer), users may end up using a single PYBLADERF_META_FLAG_TX_BURST_START, and then numerous calls to pybladerf_sync_tx() with the PYBLADERF_META_FLAG_TX_UPDATE_TIMESTAMP flag set. The PYBLADERF_META_FLAG_TX_BURST_END would only be used to end the stream when shutting down.
'''
PYBLADERF_META_FLAG_RX_NOW: int
'''This flag indicates that calls to bladerf_sync_rx should return any available samples, rather than wait until the timestamp indicated in the pybladerf_metadata timestamp field.'''
PYBLADERF_META_FLAG_RX_HW_UNDERFLOW: int
'''This flag is asserted in bladerf_metadata.status by the hardware when an underflow is detected in the sample buffering system on the device.'''
PYBLADERF_META_FLAG_RX_HW_MINIEXP1: int
'''This flag is asserted in bladerf_metadata.status by the hardware if mini expansion IO pin 1 is asserted.'''
PYBLADERF_META_FLAG_RX_HW_MINIEXP2: int
'''This flag is asserted in bladerf_metadata.status by the hardware if mini expansion IO pin 2 is asserted.'''

PYBLADERF_TRIGGER_REG_ARM: int
'''
Trigger control register "Arm" bit

This bit arms (i.e., enables) the trigger controller when set to 1. Samples will be gated until the "Fire" bit has been asserted.

A 0 in this bit disables the trigger controller. Samples will continue to flow as they normally do in this state.'''
PYBLADERF_TRIGGER_REG_FIRE: int
'''
Trigger control register "Fire" bit

For a master, this bit causes a trigger to be sent to all slave devices. Once this trigger is received (the master "receives" it immediately as well), devices begin streaming samples.

This bit has no effect on slave devices.
'''
PYBLADERF_TRIGGER_REG_MASTER: int
'''
Trigger control register "Master" bit

Selects whether the device is a trigger master (1) or trigger slave (0). The trigger master drives the trigger signal as an output.

Slave devices configure the trigger signal as an input.
'''
PYBLADERF_TRIGGER_REG_LINE: int
'''
Trigger control registers "line" bit

This is a read-only register bit that denotes the current state of the the trigger signal.
'''

# ---- ERROR ---- #
class PYBLADERF_ERR(Exception):
    '''Base pybladerf error'''

class PYBLADERF_ERR_UNEXPECTED(PYBLADERF_ERR):
    '''An unexpected failure occurred'''

class PYBLADERF_ERR_RANGE(PYBLADERF_ERR):
    '''Provided parameter is out of range'''

class PYBLADERF_ERR_INVAL(PYBLADERF_ERR):
    '''Invalid operation/parameter'''

class PYBLADERF_ERR_MEM(PYBLADERF_ERR):
    '''Memory allocation error'''

class PYBLADERF_ERR_IO(PYBLADERF_ERR):
    '''File/Device I/O error'''

class PYBLADERF_ERR_TIMEOUT(PYBLADERF_ERR):
    '''Operation timed out'''

class PYBLADERF_ERR_NODEV(PYBLADERF_ERR):
    '''No device(s) available'''

class PYBLADERF_ERR_UNSUPPORTED(PYBLADERF_ERR):
    '''Operation not supported'''

class PYBLADERF_ERR_MISALIGNED(PYBLADERF_ERR):
    '''Misaligned flash access'''

class PYBLADERF_ERR_CHECKSUM(PYBLADERF_ERR):
    '''Invalid checksum'''

class PYBLADERF_ERR_NO_FILE(PYBLADERF_ERR):
    '''File not found'''

class PYBLADERF_ERR_UPDATE_FPGA(PYBLADERF_ERR):
    '''An FPGA update is required'''

class PYBLADERF_ERR_UPDATE_FW(PYBLADERF_ERR):
    '''A firmware update is requied'''

class PYBLADERF_ERR_TIME_PAST(PYBLADERF_ERR):
    '''Requested timestamp is in the past'''

class PYBLADERF_ERR_QUEUE_FULL(PYBLADERF_ERR):
    '''Could not enqueue data into full queue'''

class PYBLADERF_ERR_FPGA_OP(PYBLADERF_ERR):
    '''An FPGA operation reported failure'''

class PYBLADERF_ERR_PERMISSION(PYBLADERF_ERR):
    '''Insufficient permissions for the requested operation'''

class PYBLADERF_ERR_WOULD_BLOCK(PYBLADERF_ERR):
    '''Operation would block, but has been requested to be non-blocking. This indicates to a caller that it may need to retry the operation later'''

class PYBLADERF_ERR_NOT_INIT(PYBLADERF_ERR):
    '''Device insufficiently initialized for operation'''

# ---- ENUM ---- #
class pybladerf_backend(IntEnum):
    '''Backend by which the host communicates with the device'''
    PYBLADERF_BACKEND_ANY = ...
    '''"Don't Care" -- use any available backend '''
    PYBLADERF_BACKEND_LINUX = ...
    '''Linux kernel driver'''
    PYBLADERF_BACKEND_LIBUSB = ...
    '''libusb'''
    PYBLADERF_BACKEND_CYPRESS = ...
    '''CyAPI'''
    PYBLADERF_BACKEND_DUMMY = ...
    '''Dummy used for development purposes'''

    def __str__(self) -> str:
        ...

class pybladerf_fpga_size(IntEnum):
    '''FPGA device variant (size)'''
    PYBLADERF_FPGA_UNKNOWN = ...
    '''Unable to determine FPGA variant'''
    PYBLADERF_FPGA_40KLE = ...
    '''40 kLE FPGA'''
    PYBLADERF_FPGA_115KLE = ...
    '''115 kLE FPGA'''
    PYBLADERF_FPGA_A4 = ...
    '''49 kLE FPGA'''
    PYBLADERF_FPGA_A5 = ...
    '''77 kLE FPGA (A5)'''
    PYBLADERF_FPGA_A9 = ...
    '''301 kLE FPGA (A9)'''

    def __str__(self) -> str:
        ...

class pybladerf_dev_speed(IntEnum):
    '''
    This enum describes the USB Speed at which the bladeRF is connected.
    Speeds not listed here are not supported.
    '''
    PYBLADERF_DEVICE_SPEED_UNKNOWN = ...
    PYBLADERF_DEVICE_SPEED_HIGH = ...
    PYBLADERF_DEVICE_SPEED_SUPER = ...

    def __str__(self) -> str:
        ...

class pybladerf_fpga_source(IntEnum):
    '''FPGA configuration source'''
    PYBLADERF_FPGA_SOURCE_UNKNOWN = ...
    '''Uninitialized/invalid'''
    PYBLADERF_FPGA_SOURCE_FLASH = ...
    '''Last FPGA load was from flash'''
    PYBLADERF_FPGA_SOURCE_HOST = ...
    '''Last FPGA load was from host'''

    def __str__(self) -> str:
        ...

class pybladerf_direction(IntEnum):
    '''Stream direction'''
    PYBLADERF_RX = ...
    '''Receive direction'''
    PYBLADERF_TX = ...
    '''Transmit direction'''

    def __str__(self) -> str:
        ...

class pybladerf_channel_layout(IntEnum):
    '''Stream channel layout'''
    PYBLADERF_RX_X1 = ...
    '''x1 RX (SISO)'''
    PYBLADERF_TX_X1 = ...
    '''x1 TX (SISO)'''
    PYBLADERF_RX_X2 = ...
    '''x2 RX (MIMO)'''
    PYBLADERF_TX_X2 = ...
    '''x2 TX (MIMO)'''

    def __str__(self) -> str:
        ...

class pybladerf_gain_mode(IntEnum):
    '''
    Gain control modes
    In general, the default mode is automatic gain control. This will continuously adjust the gain to maximize dynamic range and minimize clipping.
    '''
    PYBLADERF_GAIN_DEFAULT = ...
    '''
    Device-specific default (automatic, when available)

    On the bladeRF x40 and x115 with FPGA versions >= v0.7.0, this is automatic gain control.

    On the bladeRF 2.0 Micro, this is BLADERF_GAIN_SLOWATTACK_AGC with reasonable default settings.'''
    PYBLADERF_GAIN_MGC = ...
    '''
    Manual gain control.
    Available on all bladeRF models.
    '''
    PYBLADERF_GAIN_FASTATTACK_AGC = ...
    '''
    Automatic gain control, fast attack (advanced)

    Only available on the bladeRF 2.0 Micro. This is an advanced option, and typically requires additional configuration for ideal performance.'''
    PYBLADERF_GAIN_SLOWATTACK_AGC = ...
    '''
    Automatic gain control, slow attack (advanced)
    Only available on the bladeRF 2.0 Micro. This is an advanced option, and typically requires additional configuration for ideal performance.'''
    PYBLADERF_GAIN_HYBRID_AGC = ...
    '''
    Automatic gain control, hybrid attack (advanced)

    Only available on the bladeRF 2.0 Micro. This is an advanced option, and typically requires additional configuration for ideal performance.'''

    def __str__(self) -> str:
        ...

class pybladerf_loopback(IntEnum):
    '''Loopback options'''
    PYBLADERF_LB_NONE = ...
    '''Disables loopback and returns to normal operation.'''
    PYBLADERF_LB_FIRMWARE = ...
    '''Firmware loopback inside of the FX3.'''
    PYBLADERF_LB_BB_TXLPF_RXVGA2 = ...
    '''Baseband loopback. TXLPF output is connected to the RXVGA2 input.'''
    PYBLADERF_LB_BB_TXVGA1_RXVGA2 = ...
    '''Baseband loopback. TXVGA1 output is connected to the RXVGA2 input.'''
    PYBLADERF_LB_BB_TXLPF_RXLPF = ...
    '''Baseband loopback. TXLPF output is connected to the RXLPF input.'''
    PYBLADERF_LB_BB_TXVGA1_RXLPF = ...
    '''Baseband loopback. TXVGA1 output is connected to RXLPF input.'''
    PYBLADERF_LB_RF_LNA1 = ...
    '''RF loopback. The TXMIX output, through the AUX PA, is connected to the output of LNA1.'''
    PYBLADERF_LB_RF_LNA2 = ...
    '''RF loopback. The TXMIX output, through the AUX PA, is connected to the output of LNA2.'''
    PYBLADERF_LB_RF_LNA3 = ...
    '''RF loopback. The TXMIX output, through the AUX PA, is connected to the output of LNA3.'''
    PYBLADERF_LB_RFIC_BIST = ...
    '''RFIC digital loopback (built-in self-test)'''

    def __str__(self) -> str:
        ...

class pybladerf_trigger_role(IntEnum):
    '''This value denotes the role of a device in a trigger chain.'''
    PYBLADERF_TRIGGER_ROLE_INVALID = ...
    '''Invalid role selection.'''
    PYBLADERF_TRIGGER_ROLE_DISABLED = ...
    '''Triggering functionality is disabled on this device. Samples are not gated and the trigger signal is an input.'''
    PYBLADERF_TRIGGER_ROLE_MASTER = ...
    '''This device is the trigger master. Its trigger signal will be an output and this device will determine when all devices shall trigger.'''
    PYBLADERF_TRIGGER_ROLE_SLAVE = ...
    '''This device is the trigger slave. This device's trigger signal will be an input and this devices will wait for the master's trigger signal assertion.'''

    def __str__(self) -> str:
        ...

class pybladerf_trigger_signal(IntEnum):
    '''
    Trigger signal selection

    This selects pin or signal used for the trigger.

    ! NOTE !
        PYBLADERF_TRIGGER_J71_4, PYBLADERF_TRIGGER_J51_1, and PYBLADERF_TRIGGER_MINI_EXP_1 are the only valid options as of FPGA v0.6.0. All three values have the same behavior and may be used interchangably.

    The `PYBLADERF_TRIGGER_USER_*` values have been added to allow users to modify both hardware and software implementations to add custom triggers, while maintaining libbladeRF API compatibility. Official bladeRF releases will not utilize these user signal IDs.
    '''
    PYBLADERF_TRIGGER_INVALID = ...
    '''Invalid selection.'''
    PYBLADERF_TRIGGER_J71_4 = ...
    '''J71 pin 4, mini_exp[1] on x40/x115'''
    PYBLADERF_TRIGGER_J51_1 = ...
    '''J51 pin 1, mini_exp[1] on xA4/xA5/xA9'''
    PYBLADERF_TRIGGER_MINI_EXP_1 = ...
    '''mini_exp[1], hardware-independent'''
    PYBLADERF_TRIGGER_USER_0 = ...
    '''Reserved for user SW/HW customizations'''
    PYBLADERF_TRIGGER_USER_1 = ...
    '''Reserved for user SW/HW customizations'''
    PYBLADERF_TRIGGER_USER_2 = ...
    '''Reserved for user SW/HW customizations'''
    PYBLADERF_TRIGGER_USER_3 = ...
    '''Reserved for user SW/HW customizations'''
    PYBLADERF_TRIGGER_USER_4 = ...
    '''Reserved for user SW/HW customizations'''
    PYBLADERF_TRIGGER_USER_5 = ...
    '''Reserved for user SW/HW customizations'''
    PYBLADERF_TRIGGER_USER_6 = ...
    '''Reserved for user SW/HW customizations'''
    PYBLADERF_TRIGGER_USER_7 = ...
    '''Reserved for user SW/HW customizations'''

    def __str__(self) -> str:
        ...

class pybladerf_rx_mux(IntEnum):
    '''
    RX Mux modes

    These values describe the source of samples to the RX FIFOs in the FPGA. They map directly to rx_mux_mode_t inside the FPGA's source code.
    '''
    PYBLADERF_RX_MUX_INVALID = ...
    '''Invalid RX Mux mode selection.'''
    PYBLADERF_RX_MUX_BASEBAND = ...
    '''Read baseband samples. This is the default mode of operation.'''
    PYBLADERF_RX_MUX_12BIT_COUNTER = ...
    '''
    Read samples from 12 bit counters.

    The I channel counts up while the Q channel counts down.
    '''
    PYBLADERF_RX_MUX_32BIT_COUNTER = ...
    '''
    Read samples from a 32 bit up-counter.

    I and Q form a little-endian value.
    '''
    PYBLADERF_RX_MUX_DIGITAL_LOOPBACK = ...
    '''
    RX_MUX setting 0x3 is reserved for future use.

    Read samples from the baseband TX input to the FPGA (from the host)
    '''

    def __str__(self) -> str:
        ...

class pybladerf_stream_state(IntEnum):
    '''Async stream state'''
    STREAM_IDLE = ...
    '''Idle and initialized.'''
    STREAM_RUNNING = ...
    '''Currently running.'''
    STREAM_SHUTTING_DOWN = ...
    '''
    Currently tearing down.

    See pybladerf_stream->error_code to determine whether or not the shutdown was a clean exit or due to an error.
    '''
    STREAM_DONE = ...
    '''Done and deallocated'''

    def __str__(self) -> str:
        ...

class pybladerf_correction(IntEnum):
    '''
    Correction parameter selection

    These values specify the correction parameter to modify or query when calling pybladerf_set_correction() or pybladerf_get_correction(). Note that the meaning of the `value` parameter to these functions depends upon the correction parameter.
    '''
    PYBLADERF_CORR_DCOFF_I = ...
    '''Adjusts the in-phase DC offset. Valid values are [-2048, 2048], which are scaled to the available control bits.'''
    PYBLADERF_CORR_DCOFF_Q = ...
    '''Adjusts the quadrature DC offset. Valid values are [-2048, 2048], which are scaled to the available control bits.'''
    PYBLADERF_CORR_PHASE = ...
    '''Adjusts phase correction of [-10, 10] degrees, via a provided count value of [-4096, 4096].'''
    PYBLADERF_CORR_GAIN = ...
    '''Adjusts gain correction value in [-1.0, 1.0], via provided values in the range of [-4096, 4096].'''

    def __str__(self) -> str:
        ...

class pybladerf_format(IntEnum):
    '''Sample format'''
    PYBLADERF_FORMAT_SC16_Q11 = ...
    '''
    Signed, Complex 16-bit Q11. This is the native format of the DAC data.

    Values in the range [-2048, 2048) are used to represent [-1.0, 1.0).

    Note that the lower bound here is inclusive, and the upper bound is exclusive. Ensure that provided samples stay within [-2048, 2047].

    Samples consist of interleaved IQ value pairs, with I being the first value in the pair. Each value in the pair is a right-aligned, little-endian int16_t. The FPGA ensures that these values are sign-extended.

    ```html
        .--------------.--------------.
        | Bits 31...16 | Bits 15...0  |
        +--------------+--------------+
        |   Q[15..0]   |   I[15..0]   |
        .--------------.--------------.
    ```

    When using this format the minimum required buffer size, in bytes, is:

        `buffer_size_min = (2 x num_samples x num_channels x sizeof(int16_t))`

    For example, to hold 2048 samples for one channel, a buffer must be at least 8192 bytes large.

    When a multi-channel pybladerf_channel_layout is selected, samples will be interleaved per channel. For example, with PYBLADERF_RX_X2 or PYBLADERF_TX_X2 (x2 MIMO), the buffer is structured like:

    ```html
        .-------------.--------------.--------------.------------------.
        | Byte offset | Bits 31...16 | Bits 15...0  |    Description   |
        +-------------+--------------+--------------+------------------+
        |    0x00     |     Q0[0]    |     I0[0]    |  Ch 0, sample 0  |
        |    0x04     |     Q1[0]    |     I1[0]    |  Ch 1, sample 0  |
        |    0x08     |     Q0[1]    |     I0[1]    |  Ch 0, sample 1  |
        |    0x0c     |     Q1[1]    |     I1[1]    |  Ch 1, sample 1  |
        |    ...      |      ...     |      ...     |        ...       |
        |    0xxx     |     Q0[n]    |     I0[n]    |  Ch 0, sample n  |
        |    0xxx     |     Q1[n]    |     I1[n]    |  Ch 1, sample n  |
        .-------------.--------------.--------------.------------------.
    ```

    Per the `buffer_size_min` formula above, 2048 samples for two channels will generate 4096 total samples, and require at least 16384 bytes.

    Implementors may use the interleaved buffers directly, or may use pybladerf_deinterleave_stream_buffer() / pybladerf_interleave_stream_buffer() if contiguous blocks of samples are desired.
    '''
    PYBLADERF_FORMAT_SC16_Q11_META = ...
    '''
    This format is the same as the PYBLADERF_FORMAT_SC16_Q11 format, except the first 4 samples in every block* of samples are replaced with metadata organized as follows. All fields are little-endian byte order.

    ```html
        .-------------.------------.----------------------------------.
        | Byte offset |   Type     | Description                      |
        +-------------+------------+----------------------------------+
        |    0x00     | uint16_t   | Reserved                         |
        |    0x02     |  uint8_t   | Stream flags                     |
        |    0x03     |  uint8_t   | Meta version ID                  |
        |    0x04     | uint64_t   | 64-bit Timestamp                 |
        |    0x0c     | uint32_t   | BLADERF_META_FLAG_* flags        |
        |  0x10..end  |            | Payload                          |
        .-------------.------------.----------------------------------.
    ```

    For IQ sample meta mode, the Meta version ID and Stream flags should currently be set to values 0x00 and 0x00, respectively.

    *The number of samples in a block is dependent upon the USB speed being used:
    - USB 2.0 Hi-Speed: 256 samples
    - USB 3.0 SuperSpeed: 512 samples

    When using the pybladerf_sync_rx() and pybladerf_sync_tx() functions, the above details are entirely transparent; the caller need not be concerned with these details. These functions take care of packing/unpacking the metadata into/from the underlying stream and convey this information through the pybladerf_metadata structure.

    However, when using the FN_STREAMING_ASYNC interface, the user is responsible for manually packing/unpacking the above metadata into/from their samples.
    '''
    PYBLADERF_FORMAT_SC8_Q7 = ...
    '''
    Signed, Complex 8-bit Q8. This is the native format of the DAC data.

    Values in the range [-128, 128) are used to represent [-1.0, 1.0). Note that the lower bound here is inclusive, and the upper bound is exclusive. Ensure that provided samples stay within [-128, 127].

    Samples consist of interleaved IQ value pairs, with I being the value in the pair. Each value in the pair is a right-aligned int8_t. The FPGA ensures that these values are sign-extended.

    ```html
        .--------------.--------------.
        | Bits 15...8  | Bits  7...0  |
        +--------------+--------------+
        |    Q[7..0]   |    I[7..0]   |
        .--------------.--------------.
    ```

    When using this format the minimum required buffer size, in bytes, is:
        `buffer_size_min = (2 x num_samples x num_channels x sizeof(int8_t))`

    For example, to hold 2048 samples for one channel, a buffer must be at least 4096 bytes large.

    When a multi-channel pybladerf_channel_layout is selected, samples will be interleaved per channel. For example, with PYBLADERF_RX_X2 or PYBLADERF_TX_X2 (x2 MIMO), the buffer is structured like:

    ```html
        .-------------.--------------.--------------.------------------.
        | Byte offset | Bits 15...8  | Bits  7...0  |    Description   |
        +-------------+--------------+--------------+------------------+
        |    0x00     |     Q0[0]    |     I0[0]    |  Ch 0, sample 0  |
        |    0x02     |     Q1[0]    |     I1[0]    |  Ch 1, sample 0  |
        |    0x04     |     Q0[1]    |     I0[1]    |  Ch 0, sample 1  |
        |    0x06     |     Q1[1]    |     I1[1]    |  Ch 1, sample 1  |
        |    ...      |      ...     |      ...     |        ...       |
        |    0xxx     |     Q0[n]    |     I0[n]    |  Ch 0, sample n  |
        |    0xxx     |     Q1[n]    |     I1[n]    |  Ch 1, sample n  |
        `-------------`--------------`--------------`------------------`
    ```

    Per the `buffer_size_min` formula above, 2048 samples for two channels will generate 4096 total samples, and require at least 8192 bytes.

    Implementors may use the interleaved buffers directly, or may use pybladerf_deinterleave_stream_buffer() / pybladerf_interleave_stream_buffer() if contiguous blocks of samples are desired.
    '''
    PYBLADERF_FORMAT_SC8_Q7_META = ...
    '''
    This format is the same as the PYBLADERF_FORMAT_SC8_Q7 format, except the first 8 samples in every block* of samples are replaced with metadata organized as follows. All fields are little-endian byte order.

    ```html
        .-------------.------------.----------------------------------.
        | Byte offset |   Type     | Description                      |
        +-------------+------------+----------------------------------+
        |    0x00     | uint16_t   | Reserved                         |
        |    0x02     |  uint8_t   | Stream flags                     |
        |    0x03     |  uint8_t   | Meta version ID                  |
        |    0x04     | uint64_t   | 64-bit Timestamp                 |
        |    0x0c     | uint32_t   | BLADERF_META_FLAG_* flags        |
        |  0x10..end  |            | Payload                          |
        .-------------.------------.----------------------------------.
    ```

    For IQ sample meta mode, the Meta version ID and Stream flags should currently be set to values 0x00 and 0x00, respectively.

    *The number of samples in a block is dependent upon the USB speed being used:
    - USB 2.0 Hi-Speed: 256 samples
    - USB 3.0 SuperSpeed: 512 samples

    When using the pybladerf_sync_rx() and pybladerf_sync_tx() functions, the above details are entirely transparent; the caller need not be concerned with these details. These functions take care of packing/unpacking the metadata into/from the underlying stream and convey this information through the pybladerf_metadata structure.

    However, when using the FN_STREAMING_ASYNC interface, the user is responsible for manually packing/unpacking the above metadata into/from their samples.
    '''

    def __str__(self) -> str:
        ...

class pybladerf_vctcxo_tamer_mode(IntEnum):
    '''
    VCTCXO Tamer mode selection

    These values control the use of header J71 pin 1 for taming the on-board VCTCXO to improve or sustain frequency accuracy.

    When supplying input into the VCTCXO tamer, a 1.8V signal must be provided.

    ! WARNING !
        Exceeding 1.8V on J71-1 can damage the associated FPGA I/O bank. Ensure that you provide only a 1.8V signal!

    '''
    PYBLADERF_VCTCXO_TAMER_INVALID = ...
    '''Denotes an invalid selection or state.'''
    PYBLADERF_VCTCXO_TAMER_DISABLED = ...
    '''Do not attempt to tame the VCTCXO with an input source.'''
    PYBLADERF_VCTCXO_TAMER_1_PPS = ...
    '''Use a 1 pps input source to tame the VCTCXO.'''
    PYBLADERF_VCTCXO_TAMER_10_MHZ = ...
    '''Use a 10 MHz input source to tame the VCTCXO.'''

    def __str__(self) -> str:
        ...

class pybladerf_tuning_mode(IntEnum):
    '''
    Frequency tuning modes
    The default tuning mode, `PYBLADERF_TUNING_MODE_HOST`, can be overridden by setting a PYBLADERF_DEFAULT_TUNING_MODE environment variable to `host` or `fpga`.

    PYBLADERF_TUNING_MODE_HOST is the default tuning mode.

    PYBLADERF_TUNING_MODE_FPGA requirements:
    - libbladeRF >= v1.3.0
    - FPGA       >= v0.2.0

    ! NOTE !
        Overriding this value with a mode not supported by the FPGA will result in failures or unexpected behavior.
    '''
    PYBLADERF_TUNING_MODE_INVALID = ...
    '''Indicates an invalid mode is set'''
    PYBLADERF_TUNING_MODE_HOST = ...
    '''Perform tuning algorithm on the host. This is slower, but provides easier accessiblity to diagnostic information.'''
    PYBLADERF_TUNING_MODE_FPGA = ...
    '''Perform tuning algorithm on the FPGA for faster tuning.'''

    def __str__(self) -> str:
        ...

class pybladerf_feature(IntEnum):
    '''Feature Set'''
    PYBLADERF_FEATURE_DEFAULT = ...
    '''No feature enabled'''
    PYBLADERF_FEATURE_OVERSAMPLE = ...
    '''Enforces AD9361 OC and 8bit mode'''

    def __str__(self) -> str:
        ...

class pybladerf_log_level(IntEnum):
    '''Severity levels for logging functions'''
    PYBLADERF_LOG_LEVEL_VERBOSE = ...
    '''Verbose level logging'''
    PYBLADERF_LOG_LEVEL_DEBUG = ...
    '''Debug level logging'''
    PYBLADERF_LOG_LEVEL_INFO = ...
    '''Information level logging'''
    PYBLADERF_LOG_LEVEL_WARNING = ...
    '''Warning level logging'''
    PYBLADERF_LOG_LEVEL_ERROR = ...
    '''Error level logging'''
    PYBLADERF_LOG_LEVEL_CRITICAL = ...
    '''Fatal error level logging'''
    PYBLADERF_LOG_LEVEL_SILENT = ...
    '''No output'''

    def __str__(self) -> str:
        ...

class pybladerf_rfic_rxfir(IntEnum):
    '''RFIC RX FIR filter choices'''
    PYBLADERF_RFIC_RXFIR_BYPASS = ...
    '''No filter'''
    PYBLADERF_RFIC_RXFIR_CUSTOM = ...
    '''Custom FIR filter (currently unused)'''
    PYBLADERF_RFIC_RXFIR_DEC1 = ...
    '''Decimate by 1 (default)'''
    PYBLADERF_RFIC_RXFIR_DEC2 = ...
    '''Decimate by 2'''
    PYBLADERF_RFIC_RXFIR_DEC4 = ...
    '''Decimate by 4'''

    def __str__(self) -> str:
        ...

class pybladerf_rfic_txfir(IntEnum):
    '''RFIC TX FIR filter choices'''
    PYBLADERF_RFIC_TXFIR_BYPASS = ...
    '''No filter (default)'''
    PYBLADERF_RFIC_TXFIR_CUSTOM = ...
    '''Custom FIR filter (currently unused)'''
    PYBLADERF_RFIC_TXFIR_INT1 = ...
    '''Interpolate by 1'''
    PYBLADERF_RFIC_TXFIR_INT2 = ...
    '''Interpolate by 2'''
    PYBLADERF_RFIC_TXFIR_INT4 = ...
    '''Interpolate by 4'''

    def __str__(self) -> str:
        ...

class pybladerf_power_sources(IntEnum):
    '''Power sources'''
    PYBLADERF_UNKNOWN = ...
    '''Unknown; manual observation may be required'''
    PYBLADERF_PS_DC = ...
    '''DC Barrel Plug'''
    PYBLADERF_PS_USB_VBUS = ...
    '''USB Bus'''

    def __str__(self) -> str:
        ...

class pybladerf_clock_select(IntEnum):
    '''Available clock sources'''
    PYCLOCK_SELECT_ONBOARD = ...
    '''Use onboard VCTCXO'''
    PYCLOCK_SELECT_EXTERNAL = ...
    '''Use external clock input'''

    def __str__(self) -> str:
        ...

class pybladerf_pmic_register(IntEnum):
    '''Register identifiers for PMIC'''
    PYBLADERF_PMIC_CONFIGURATION = ...
    '''Configuration register (uint16_t)'''
    PYBLADERF_PMIC_VOLTAGE_SHUNT = ...
    '''Shunt voltage (float)'''
    PYBLADERF_PMIC_VOLTAGE_BUS = ...
    '''Bus voltage (float)'''
    PYBLADERF_PMIC_POWER = ...
    '''Load power (float)'''
    PYBLADERF_PMIC_CURRENT = ...
    '''Load current (float)'''
    PYBLADERF_PMIC_CALIBRATION = ...
    '''Calibration (uint16_t)'''

    def __str__(self) -> str:
        ...

class pybladerf_sweep_style(IntEnum):
    '''
    Sweep mode enum

    Used by `pybladerf_init_sweep`, to set sweep parameters.
    '''
    PYBLADERF_SWEEP_STYLE_LINEAR = ...
    '''step_width is added to the current frequency at each step.'''
    PYBLADERF_SWEEP_STYLE_INTERLEAVED = 1
    '''each step is divided into two interleaved sub-steps, allowing the host to select the best portions of the FFT of each sub-step and discard the rest.'''

    def __str__(self) -> str:
        ...

# ---- STRUCT ---- #
class pybladerf_devinfo:
    '''Information about a bladeRF attached to the system'''

    def __init__(self,
                 backend: pybladerf_backend = None,
                 serial: str = None,
                 usb_bus: int = None,
                 usb_addr: int = None,
                 instance: int = None,
                 manufacturer: str = None,
                 product: str = None) -> None:
        ...

    @property
    def backend(self) -> pybladerf_backend:
        '''Backend to use when connecting to device'''
        ...

    @property
    def serial(self) -> str:
        '''Device serial number string'''
        ...

    @property
    def usb_bus(self) -> int:
        '''Bus # device is attached to'''
        ...

    @property
    def usb_addr(self) -> int:
        '''Device address on bus'''
        ...

    @property
    def instance(self) -> int:
        '''Device instance or ID'''
        ...

    @property
    def manufacturer(self) -> str:
        '''Manufacturer description string'''
        ...

    @property
    def product(self) -> str:
        '''Product description string'''
        ...

class pybladerf_version:
    '''Version structure for python_bladerf, FPGA, firmware, libbladeRF, and associated utilities'''

    def __init__(self,
                 major: int = None,
                 minor: int = None,
                 patch: int = None,
                 describe: str = None) -> None:
        ...

    def __str__(self) -> str:
        ...

    @property
    def major(self) -> int:
        '''Major version'''
        ...

    @property
    def minor(self) -> int:
        '''Minor version'''
        ...

    @property
    def patch(self) -> int:
        '''Patch version'''
        ...

    @property
    def describe(self) -> str:
        '''Version string with any additional suffix information.'''
        ...

class pybladerf_trigger:
    '''
    Trigger configuration

    It is highly recommended to keep a 1:1 relationship between triggers in the physical setup and instances of this structure. (i.e., do not re-use and change the same pybladerf_trigger) for multiple triggers.)
    '''

    def __init__(self,
                   channel: int = None,
                   role: pybladerf_trigger_role = None,
                   signal: pybladerf_trigger_signal = None,
                   options: int = None) -> None:
        ...

    def __str__(self) -> str:
        ...

    @property
    def channel(self) -> int:
        '''RX/TX channel associated with trigger'''
        ...

    @property
    def role(self) -> pybladerf_trigger_role:
        '''Role of the device in a trigger chain'''
        ...

    @property
    def signal(self) -> pybladerf_trigger_signal:
        '''Pin or signal being used'''
        ...

    @property
    def options(self) -> int:
        '''Reserved field for future options. This is unused and should be set to 0.'''
        ...

class pybladerf_quick_tune:
    '''
    Quick Re-tune parameters.

    ! NOTE !
        These parameters, which are associated with the RFIC's register values, are sensitive to changes in the operating environment (e.g., temperature).

    This structure should be filled in via pybladerf_get_quick_tune().
    '''

    def __init__(self,
                 freqsel: int = None,
                 vcocap: int = None,
                 nint: int = None,
                 nfrac: int = None,
                 flags: int = None,
                 xb_gpio: int = None,
                 nios_profile: int = None,
                 rffe_profile: int = None,
                 port: int = None,
                 spdt: int = None) -> None:
        ...

    @property
    def freqsel(self) -> int:
        '''Choice of VCO and VCO division factor'''
        ...

    @property
    def vcocap(self) -> int:
        '''VCOCAP value'''
        ...

    @property
    def nint(self) -> int:
        '''Integer portion of LO frequency value'''
        ...

    @property
    def nfrac(self) -> int:
        '''Fractional portion of LO frequency value'''
        ...

    @property
    def flags(self) -> int:
        '''Flag bits used internally by libbladeRF'''
        ...

    @property
    def xb_gpio(self) -> int:
        '''Flag bits used to configure XB'''
        ...

    @property
    def nios_profile(self) -> int:
        '''Profile number in Nios'''
        ...

    @property
    def rffe_profile(self) -> int:
        '''Profile number in RFFE'''
        ...

    @property
    def port(self) -> int:
        '''RFFE port settings'''
        ...

    @property
    def spdt(self) -> int:
        '''External SPDT settings'''
        ...

class pybladerf_metadata:
    '''
    Sample metadata

    This structure is used in conjunction with the PYBLADERF_FORMAT_SC16_Q11_META PYBLADERF_FORMAT_SC8_Q7_META format to TX scheduled bursts or retrieve timestamp information about received samples.
    '''

    def __init__(self,
                 timestamp: int = None,
                 flags: int = None,
                 status: int = None,
                 actual_count: int = None) -> None:
        ...

    def __str__(self):
        ...

    @property
    def timestamp(self) -> int:
        '''Free-running FPGA counter that monotonically increases at the sample rate of the associated channel.'''
        ...

    @property
    def flags(self) -> int:
        '''
        Input bit field to control the behavior of the call that the metadata structure is passed to. API calls read this field from the provided data structure, and do not modify it.

        Valid flags include
        * PYBLADERF_META_FLAG_TX_BURST_START,
        * PYBLADERF_META_FLAG_TX_BURST_END,
        * PYBLADERF_META_FLAG_TX_NOW,
        * PYBLADERF_META_FLAG_TX_UPDATE_TIMESTAMP
        * PYBLADERF_META_FLAG_RX_NOW
        '''
        ...

    @property
    def status(self) -> int:
        '''
        Output bit field to denoting the status of transmissions/receptions. API calls will write this field.

        Possible status flags include
        * PYBLADERF_META_STATUS_OVERRUN
        * PYBLADERF_META_STATUS_UNDERRUN.
        '''
        ...

    @property
    def actual_count(self) -> int:
        '''
        This output parameter is updated to reflect the actual number of contiguous samples that have been populated in an RX buffer during a pybladerf_sync_rx() call.

        This will not be equal to the requested count in the event of a discontinuity (i.e., when the status field has the PYBLADERF_META_STATUS_OVERRUN flag set). When an overrun occurs, it is important not to read past the number of samples specified by this value, as the remaining contents of the buffer are undefined.

        ! NOTE !
            This parameter is not currently used by pybladerf_sync_tx().
        '''
        ...

class pybladerf_rf_switch_config:
    '''RF switch configuration structure'''

    def __init__(self,
                 tx1_rfic_port: int = None,
                 tx1_spdt_port: int = None,
                 tx2_rfic_port: int = None,
                 tx2_spdt_port: int = None,
                 rx1_rfic_port: int = None,
                 rx1_spdt_port: int = None,
                 rx2_rfic_port: int = None,
                 rx2_spdt_port: int = None) -> None:
        ...

    @property
    def tx1_rfic_port(self) -> int:
        '''Active TX1 output from RFIC'''
        ...

    @property
    def tx1_spdt_port(self) -> int:
        '''RF switch configuration for the TX1 path'''
        ...

    @property
    def tx2_rfic_port(self) -> int:
        '''Active TX2 output from RFIC'''
        ...

    @property
    def tx2_spdt_port(self) -> int:
        '''RF switch configuration for the TX2 path'''
        ...

    @property
    def rx1_rfic_port(self) -> int:
        '''Active RX1 input to RFIC'''
        ...

    @property
    def rx1_spdt_port(self) -> int:
        '''RF switch configuration for the RX1 path'''
        ...

    @property
    def rx2_rfic_port(self) -> int:
        '''Active RX2 input to RFIC'''
        ...

    @property
    def rx2_spdt_port(self) -> int:
        '''RF switch configuration for the RX2 path'''
        ...

# ---- READONLY STRUCT ---- #
class pybladerf_range:
    '''
    Range structure

    ! NOTE !
        This class is read-only
    '''

    def __str__(self) -> str:
        ...

    @property
    def min(self) -> int:
        '''Minimum value'''
        ...

    @property
    def max(self) -> int:
        '''Maximum value'''
        ...

    @property
    def step(self) -> int:
        '''Step of value'''
        ...

    @property
    def scale(self) -> float:
        '''Unit scale'''
        ...

class pybladerf_stream:
    '''
    Async stream data

    ! NOTE !
        This class is read-only
    '''

    def __init__(self) -> None:
        ...

    @property
    def layout(self) -> pybladerf_channel_layout:
        '''Stream channel layout'''
        ...

    @property
    def data_format(self) -> pybladerf_format:
        '''Sample format'''
        ...

    @property
    def transfer_timeout(self) -> int:
        '''transmission timeout'''
        ...

    @property
    def samples_per_buffer(self) -> int:
        '''buffer size'''
        ...

    @property
    def num_buffers(self) -> int:
        '''number of buffers'''
        ...

    @property
    def state(self) -> pybladerf_stream_state:
        '''Async stream state'''
        ...

    @property
    def error_code(self) -> str:
        '''Async stream error code'''
        ...

# ---- WRAPPER ---- #
class PyBladeRFDeviceList:
    '''Class implementing list of BladeRF devices.'''

    @property
    def device_count(self) -> int:
        '''Number of devices found'''
        ...

    @property
    def devstrs(self) -> list[str]:
        '''List of devstr of found devices'''
        ...

    @property
    def backends(self) -> list[pybladerf_backend]:
        '''List of backend to use when connecting to device of found devices'''
        ...

    @property
    def serial_numbers(self) -> list[str]:
        '''List of serial number string of found devices'''
        ...

    @property
    def usb_buses(self) -> list[int]:
        '''List of buses # of found devices connected to'''
        ...

    @property
    def usb_addresses(self) -> list[int]:
        '''List of addresses of found devices on the bus'''
        ...

    @property
    def instances(self) -> list[int]:
        '''
        List of instances or ID's of found devices.
        On Android list of file descriptors of found devices.
        '''
        ...

    @property
    def manufacturers(self) -> list[str]:
        '''List of manufacturer description string of found devices'''
        ...

    @property
    def products(self) -> list[str]:
        '''List of product description string of found devices'''
        ...


class PyBladerfDevice:
    '''
    Class implementing interaction with the device.

    If any of the functions returns not `0`, then an exception will be raised.

    **Do not use this class directly**
        To open the device, use one of the functions: `pybladerf_open`, `pybladerf_open_with_devinfo`

    Notes:
    - After finishing, it is recommended to call `pybladerf_close()` to properly close the device.
    - When using callbacks, ensure they are optimized for real-time processing to avoid data loss.
    '''

    # ---- device ---- #
    def pybladerf_close(self) -> None:
        '''Close device'''
        ...

    def pybladerf_get_devinfo(self) -> pybladerf_devinfo:
        '''Return the pybladerf_devinfo structure'''
        ...

    def pybladerf_get_serial(self) -> str:
        '''Return device serial number'''
        ...

    def pybladerf_get_fpga_size(self) -> pybladerf_fpga_size:
        '''Return device FPGA size'''
        ...

    def pybladerf_get_fpga_bytes(self) -> int:
        '''Query a device's expected FPGA bitstream length, in bytes'''
        ...

    def pybladerf_get_flash_size(self) -> tuple[int, bool]:
        '''
        Query a device's Flash size

        Will return size of the onboard flash, in bytes as well as True if the flash size is a guess (using FPGA size). False if the flash ID was queried and its size was successfully decoded.
        '''
        ...

    def pybladerf_fw_version(self) -> pybladerf_version:
        '''Query firmware version'''
        ...

    def pybladerf_is_fpga_configured(self) -> bool:
        '''Check FPGA configuration status'''
        ...

    def pybladerf_fpga_version(self) -> pybladerf_version:
        '''Query FPGA version'''
        ...

    def pybladerf_get_fpga_source(self) -> pybladerf_fpga_source:
        '''
        Query FPGA configuration source

        Determine whether the FPGA image was loaded from flash, or if it was loaded from the host, by asking the firmware for the last-known FPGA configuration source.
        '''
        ...

    def pybladerf_device_speed(self) -> pybladerf_dev_speed:
        '''Obtain the bus speed at which the device is operating'''
        ...

    def pybladerf_get_board_name(self) -> str:
        '''Get the board name'''
        ...

    def pybladerf_get_channel_count(self, direction: pybladerf_direction) -> int:
        '''Get the number of RX or TX channels supported by device'''
        ...

    def pybladerf_set_gain(self, channel: int, gain: int) -> None:
        '''
        Set overall system gain

        This sets an overall system gain, optimally proportioning the gain between multiple gain stages if applicable.

        Use pybladerf_get_gain_range() to determine the range of system gain.

        On receive channels, 60 dB is the maximum gain level.

        On transmit channels, 60 dB is defined as approximately 0 dBm. Note that this is not a calibrated value, and the actual output power will vary based on a multitude of factors.

        ! NOTE !
            Values outside the valid gain range will be clamped.
        '''
        ...

    def pybladerf_get_gain(self, channel: int) -> int:
        '''Get overall system gain'''
        ...

    def pybladerf_set_gain_mode(self, channel: int, mode: pybladerf_gain_mode) -> None:
        '''
        Set gain control mode

        Sets the mode for hardware AGC. Not all channels or boards will support all possible values (e.g. transmit channels); invalid combinations will raise PYBLADERF_ERR_UNSUPPORTED.

        The special value of PYBLADERF_GAIN_DEFAULT will return hardware AGC to its default value at initialization.

        See pybladerf_gain_mode for implementation guidance
        '''
        ...

    def pybladerf_get_gain_mode(self, channel: int) -> pybladerf_gain_mode:
        '''
        Get gain control mode

        Gets the current mode for hardware AGC. If the channel or board does not meaningfully have a gain mode (e.g. transmit channels), mode will be PYBLADERF_GAIN_DEFAULT.
        '''
        ...

    def pybladerf_get_gain_modes(self, channel: int) -> list[pybladerf_gain_mode]:
        '''Get list of available gain control modes'''
        ...

    def pybladerf_get_gain_range(self, channel: int) -> pybladerf_range:
        '''
        Get range of overall system gain

        ! NOTE !
            This may vary depending on the configured frequency, so it should be checked after setting the desired frequency.
        '''
        ...

    def pybladerf_set_gain_stage(self, channel: int, stage: str, gain: int) -> None:
        '''
        Set the gain for a specific gain stage

        ! NOTE !
            Values outside the valid gain range will be clipped.
        '''
        ...

    def pybladerf_get_gain_stage(self, channel: int, stage: str) -> int:
        '''
        Get gain of a specific gain stage

        ! NOTE !
            Note that, in some cases, gain may be negative (e.g. transmit channels).
        '''
        ...

    def pybladerf_get_gain_stage_range(self, channel: int, stage: str) -> pybladerf_range:
        '''
        Get gain range of a specific gain stage

        ! NOTE !
            This may vary depending on the configured frequency, so it should be checked after setting the desired frequency.
        '''
        ...

    def pybladerf_get_gain_stages(self, channel: int) -> list[str]:
        '''Get a list of available gain stages'''
        ...

    def pybladerf_set_sample_rate(self, channel: int, sample_rate: int) -> int:
        '''
        Configure the channel's sample rate to the specified rate in Hz.

        ! NOTE !
            This requires the sample rate is an integer value of Hz.  Use pybladerf_set_rational_sample_rate() for more arbitrary values.
        '''
        ...

    def pybladerf_set_rational_sample_rate(self, channel: int, integer: int, num: int, den: int) -> tuple[int, int, int]:
        '''
        Configure the channel's sample rate as a rational fraction of Hz.

        Use pybladerf_get_sample_rate_range() to determine the range of supported sample rates.
        '''
        ...

    def pybladerf_get_sample_rate(self, channel: int) -> int:
        '''Get the channel's current sample rate in Hz'''
        ...

    def pybladerf_get_sample_rate_range(self, channel: int) -> pybladerf_range:
        '''Get the channel's supported range of sample rates'''
        ...

    def pybladerf_get_rational_sample_rate(self, channel: int) -> tuple[int, int, int]:
        '''Get the channel's sample rate in rational Hz'''
        ...

    def pybladerf_set_bandwidth(self, channel: int, bandwidth: int) -> int:
        '''
        Set the bandwidth of the channel to the specified value in Hz

        The underlying device is capable of a discrete set of bandwidth values. The caller should check the `actual` parameter to determine which of these discrete bandwidth values is actually used for the requested bandwidth.

        Use pybladerf_get_bandwidth_range() to determine the range of supported bandwidths.
        '''
        ...

    def pybladerf_get_bandwidth(self, channel: int) -> int:
        '''Get the bandwidth of the channel'''
        ...

    def pybladerf_get_bandwidth_range(self, channel: int) -> pybladerf_range:
        '''Get the supported range of bandwidths for a channel'''
        ...

    def pybladerf_select_band(self, channel: int, frequency: int) -> None:
        '''
        Select the appropriate band path given a frequency in Hz.

        ! NOTE !
            Most API users will not need to use this function, as pybladerf_set_frequency() calls this internally after tuning the device.

        The high band is used for `frequency` above 1.5 GHz on bladeRF1 and above 3.0 GHz on bladeRF2. Otherwise, the low band is used.

        Use pybladerf_get_frequency_range() to determine the range of supported frequencies.
        '''
        ...

    def pybladerf_set_frequency(self, channel: int, frequency: int) -> None:
        '''
        Set channel's frequency in Hz.

        ! NOTE !
            On the bladeRF1 platform, it is recommended to keep the RX and TX frequencies at least 1 MHz apart, and to digitally mix on the RX side if reception closer to the TX frequency is required.

            On the bladeRF2, there is one oscillator for all RX channels and one oscillator for all TX channels. Therefore, changing one channel will change the frequency of all channels in that direction.
        Use pybladerf_get_frequency_range() to determine the range of supported frequencies.
        '''
        ...

    def pybladerf_get_frequency(self, channel: int) -> int:
        '''Get channel's current frequency in Hz'''
        ...

    def pybladerf_get_frequency_range(self, channel: int) -> pybladerf_range:
        '''Get the supported range of frequencies for a channel'''
        ...

    def pybladerf_get_loopback_modes(self) -> list[pybladerf_loopback]:
        '''Get list of supported loopback modes'''
        ...

    def pybladerf_is_loopback_mode_supported(self, mode: pybladerf_loopback) -> bool:
        '''Test if a given loopback mode is supported on this device.'''
        ...

    def pybladerf_set_loopback(self, lb: pybladerf_loopback) -> None:
        '''
        Apply specified loopback mode

        ! NOTE !
             Loopback modes should only be enabled or disabled while the RX and TX channels are both disabled (and therefore, when no samples are being actively streamed). Otherwise, unexpected behavior may occur.
        '''
        ...

    def pybladerf_get_loopback(self) -> pybladerf_loopback:
        '''Get current loopback mode'''
        ...

    def pybladerf_trigger_init(self, channel: int, trigger_signal: pybladerf_trigger_signal) -> pybladerf_trigger:
        '''
        Initialize a bladerf_trigger structure based upon the current configuration of the specified trigger signal.

        While it is possible to simply declare and manually fill in a pybladerf_trigger structure, it is recommended to use this function to retrieve the current `role` and `options` values.
        '''
        ...

    def pybladerf_trigger_arm(self, trigger: pybladerf_trigger, arm: bool) -> None:
        '''
        Configure and (dis)arm a trigger on the specified device.

        ! NOTE !
            If trigger->role is set to PYBLADERF_TRIGGER_ROLE_DISABLED, this will inherently disarm an armed trigger and clear any fire requests, regardless of the value of `arm`.

        ! WARNING !
            Configuring two devices in the trigger chain (or both RX and TX on a single device) as masters can damage the associated FPGA pins, as this would cause contention over the trigger signal. Ensure only one device in the chain is configured as the master!
        '''
        ...

    def pybladerf_trigger_fire(self, trigger: pybladerf_trigger) -> None:
        '''
        Fire a trigger event.

        Calling this function with a trigger whose role is anything other than PYBLADERF_TRIGGER_REG_MASTER will raise a BLADERF_ERR_INVAL error.
        '''
        ...

    def pybladerf_trigger_state(self, trigger: pybladerf_trigger) -> tuple[bool, bool, bool]:
        '''Query the fire request status of a master trigger'''
        ...

    def pybladerf_set_rx_mux(self, mux: pybladerf_rx_mux) -> None:
        '''Set the current RX Mux mode'''
        ...

    def pybladerf_get_rx_mux(self) -> pybladerf_rx_mux:
        '''Gets the current RX Mux mode'''
        ...

    def pybladerf_schedule_retune(self, channel: int, timestamp: int, frequency: int, quick_tune: pybladerf_quick_tune = None) -> None:
        '''
        Schedule a frequency retune to occur at specified sample timestamp value.

        pybladerf_sync_config() must have been called with the PYBLADERF_FORMAT_SC16_Q11_META or PYBLADERF_FORMAT_SC8_Q7_META format for the associated channel in order to enable timestamps. (The timestamped metadata format must be enabled in order to use this function.)

        ! NOTE !
            If the underlying queue of scheduled retune requests becomes full, PYBLADERF_ERR_QUEUE_FULL will be returned. In this case, it should be possible to schedule a retune after the timestamp of one of the earlier requests occurs.
            You can add to the queue no more than 8 requests for frequency reconfiguration for rx and separately no more than 8 requests for frequency reconfiguration for tx.
            Otherwise, new requests will overwrite the frequency settings even if the timestamp is very far away.
        '''
        ...

    def pybladerf_cancel_scheduled_retunes(self, channel: int) -> None:
        '''
        Cancel all pending scheduled retune operations for the specified channel.

        This will be done automatically during pybladerf_close() to ensure that previously queued retunes do not continue to occur after closing and then later re-opening a device.
        '''
        ...

    def pybladerf_get_quick_tune(self, channel: int) -> pybladerf_quick_tune:
        '''
        Fetch parameters used to tune the transceiver to the current frequency for use with pybladerf_schedule_retune() to perform a "quick retune."

        This allows for a faster retune, with a potential trade off of increased phase noise.

        ! NOTE !
            These parameters are sensitive to changes in the operating environment, and should be "refreshed" if planning to use the "quick retune" functionality over a long period of time.

        pybladerf_set_frequency() or pybladerf_schedule_retune() have previously been used to retune to the desired frequency.
        '''
        ...

    def pybladerf_set_correction(self, channel: int, correction: pybladerf_correction, value: int) -> None:
        '''
        Set the value of the specified configuration parameter

        See pybladerf_correction description for the valid ranges of the `value` parameter.
        '''
        ...

    def pybladerf_get_correction(self, channel: int, correction: pybladerf_correction) -> int:
        '''Obtain the current value of the specified configuration parameter'''
        ...

    def pybladerf_interleave_stream_buffer(self, layout: pybladerf_channel_layout, data_format: pybladerf_format, buffer_size: int, samples: np.ndarray) -> None:
        '''Interleaves contiguous blocks of samples in preparation for MIMO TX.'''
        ...

    def pybladerf_deinterleave_stream_buffer(self, layout: pybladerf_channel_layout, data_format: pybladerf_format, buffer_size: int, samples: np.ndarray) -> None:
        '''Deinterleaves samples into contiguous blocks after MIMO RX.'''
        ...

    def pybladerf_enable_module(self, channel: int, enable: bool) -> None:
        '''
        Enable or disable the RF front end of the specified direction.

        RF front ends must always be enabled prior to streaming samples on the associated interface.

        When a synchronous stream is associated with the specified channel, this will shut down the underlying asynchronous stream when `enable` = false.

        When transmitting samples, be sure to provide ample time for TX samples reach the RF front-end before calling this function with `enable` = false. (This can be achieved easily when using metadata.)
        '''
        ...

    def pybladerf_get_timestamp(self, direction: pybladerf_direction) -> int:
        '''
        Retrieve the specified stream's current timestamp counter value from the FPGA.

        This function is only intended to be used to retrieve a coarse estimate of the current timestamp when starting up a stream. It <b>should not</b> be used as a means to accurately retrieve the current timestamp of individual samples within a running stream. The reasons for this are:
            - The timestamp counter will have advanced during the time that the captured value is propagated back from the FPGA to the host
            - The value retrieved in this manner is not tightly-coupled with specific sample positions in the stream.

        When actively receiving a sample stream, instead use the pybladerf_metadata.timestamp field (provided when using the PYBLADERF_FORMAT_SC16_Q11_META or PYBLADERF_FORMAT_SC8_Q7_META format) to retrieve the timestamp value associated with a block of samples.

        An example use-case of this function is to schedule an initial TX burst in a set of bursts:
            - Configure and start a TX stream using the PYBLADERF_FORMAT_SC16_Q11_META or PYBLADERF_FORMAT_SC8_Q7_META format.
            - Retrieve timestamp `T`, a coarse estimate the TX's current timestamp via this function.
            - Schedule the first burst, `F` to occur in the future: `F = T + N`. Generally, adding `N` in tens to low hundreds of milliseconds is sufficient to account for timestamp retrieval overhead and stream startup.
            - Schedule additional bursts relative to the first burst `F`.
        '''
        ...

    def pybladerf_sync_config(self, layout: pybladerf_channel_layout, data_format: pybladerf_format, num_buffers: int, buffer_size: int, num_transfers: int, stream_timeout: int) -> None:
        '''
        (Re)Configure a device for synchronous transmission or reception

        This function sets up the device for the specified format and initializes the underlying asynchronous stream parameters

        This function does not call pybladerf_enable_module(). The API user is responsible for enabling/disable streams when desired.

        Note that (re)configuring the TX direction does not affect the RX direction, and vice versa. This call configures each direction independently.

        Memory allocated by this function will be deallocated when pybladerf_close() is called.

        See the pybladerf_init_stream() documentation for information on determining appropriate values for `buffers_size`, `num_transfers`, and `stream_timeout`.

        ! NOTE !
            The `num_buffers` parameter should generally be increased as the amount of work done between bladerf_sync_rx() or bladerf_sync_tx() calls increases.
        '''
        ...

    def pybladerf_sync_tx(self, samples: np.ndarray, num_samples: int, metadata: pybladerf_metadata = None, timeout_ms: int = 0) -> None:
        '''
        Transmit IQ samples.

        Under the hood, this call starts up an underlying asynchronous stream as needed. This stream can be stopped by disabling the TX channel. (See pybladerf_enable_module for more details.)

        Samples will only be sent to the FPGA when a buffer have been filled. The number of samples required to fill a buffer corresponds to the `buffer_size` parameter passed to pybladerf_sync_config().

        A pybladerf_sync_config() call has been to configure the device for synchronous data transfer.

        ! NOTE !
            A call to pybladerf_enable_module() should be made before attempting to transmit samples. Failing to do this may result in timeouts and other errors.
        '''
        ...

    def pybladerf_sync_rx(self, samples: np.ndarray, num_samples: int, metadata: pybladerf_metadata = None, timeout_ms: int = 0) -> None:
        '''
        Receive IQ samples.

        Under the hood, this call starts up an underlying asynchronous stream as needed. This stream can be stopped by disabling the RX channel. (See pybladerf_enable_module for more details.)

        A pybladerf_sync_config() call has been to configure the device for synchronous data transfer.

        ! NOTE !
            A call to pybladerf_enable_module() should be made before attempting to receive samples. Failing to do this may result in timeouts and other errors.
        '''
        ...

    def pybladerf_init_rx_stream(self, num_buffers: int, data_format: pybladerf_format, samples_per_buffer: int, num_transfers: int) -> pybladerf_stream:
        '''
        Initialize a rx stream for use with asynchronous routines.

        This function will internally allocate data buffers, which will be provided to the API user in callback functions.

        The `buffers` output parameter populates a pointer to the list of allocated buffers. This allows the API user to implement a buffer management scheme to best suit his or her specific use case.

        Generally, one will want to set the `buffers` parameter to a value larger than the `num_transfers` parameter, and keep track of which buffers are currently "in-flight", versus those available for use.

        For example, for a transmit stream, modulated data can be actively written into free buffers while transfers of other buffers are occurring. Once a buffer has been filled with data, it can be marked 'in-flight' and be returned in a successive callback to transmit.

        The choice of values for the `num_transfers` and `buffer_size` should be made based upon the desired samplerate, and the stream timeout value specified via bladerf_set_stream_timeout(), which defaults to 1 second.

        For a given sample rate, the below relationship must be upheld to transmit or receive data without timeouts or dropped data.

        `Sample Rate > (Num Transfers  / Timeout) x Buffer Size`

        ...where Sample Rate is in samples per second, and Timeout is in seconds.

        To account for general system overhead, it is recommended to multiply the righthand side by 1.1 to 1.25.

        While increasing the number of buffers available provides additional elasticity, be aware that it also increases latency.
        '''
        ...

    def pybladerf_init_tx_stream(self, num_buffers: int, data_format: pybladerf_format, samples_per_buffer: int, num_transfers: int) -> pybladerf_stream:
        '''
        Initialize a tx stream for use with asynchronous routines.

        This function will internally allocate data buffers, which will be provided to the API user in callback functions.

        The `buffers` output parameter populates a pointer to the list of allocated buffers. This allows the API user to implement a buffer management scheme to best suit his or her specific use case.

        Generally, one will want to set the `buffers` parameter to a value larger than the `num_transfers` parameter, and keep track of which buffers are currently "in-flight", versus those available for use.

        For example, for a transmit stream, modulated data can be actively written into free buffers while transfers of other buffers are occurring. Once a buffer has been filled with data, it can be marked 'in-flight' and be returned in a successive callback to transmit.

        The choice of values for the `num_transfers` and `buffer_size` should be made based upon the desired samplerate, and the stream timeout value specified via bladerf_set_stream_timeout(), which defaults to 1 second.

        For a given sample rate, the below relationship must be upheld to transmit or receive data without timeouts or dropped data.

        `Sample Rate > (Num Transfers  / Timeout) x Buffer Size`

        ...where Sample Rate is in samples per second, and Timeout is in seconds.

        To account for general system overhead, it is recommended to multiply the righthand side by 1.1 to 1.25.

        While increasing the number of buffers available provides additional elasticity, be aware that it also increases latency.
        '''
        ...

    def pybladerf_start_stream(self, stream: pybladerf_stream, layout: pybladerf_channel_layout) -> None:
        '''
        Begin running a stream. This call will block until the stream completes.

        Only 1 RX stream and 1 TX stream may be running at a time. Attempting to call pybladerf_stream() with more than one stream will yield unexpected (and most likely undesirable) results.

        This function should be preceded by a call to pybladerf_enable_module() to enable the associated RX or TX directions before attempting to use it to stream data.
        '''
        ...

    def pybladerf_submit_stream_buffer(self, stream: pybladerf_stream, buffer: np.ndarray, timeout_ms: int) -> None:
        '''
        Submit a buffer to a stream from outside of a stream callback function.

        Use this only when returning PYBLADERF_STREAM_NO_DATA from callbacks. Do not use this function if the associated callback functions will be returning buffers for submission.

        This call may block if the device is not ready to submit a buffer for transfer. Use the `timeout_ms` to place an upper limit on the time this function can block.

        To safely submit buffers from outside the stream callback flow, this function internally acquires a per-stream lock (the same one that is held during the execution of a stream callback). Therefore, it is important to be aware of locks that may be held while making this call, especially those acquired during execution of the associated stream callback function. (i.e., be wary of the order of lock acquisitions, including the internal per-stream lock.)
        '''
        ...

    def pybladerf_submit_stream_buffer_nb(self, stream: pybladerf_stream, buffer: np.ndarray, timeout_ms: int) -> None:
        '''
        This is a non-blocking variant of pybladerf_submit_stream_buffer(). All of the caveats and important notes from pybladerf_submit_stream_buffer() apply.

        In the event that this call would need to block in order to submit a buffer, it raise PYBLADERF_ERR_WOULD_BLOCK. In this case, the caller could either wait and try again or defer buffer submission to the asynchronous callback.
        '''
        ...

    def pybladerf_deinit_stream(self, stream: pybladerf_stream) -> None:
        '''
        Deinitialize and deallocate stream resources.

        Stream is no longer being used (via pybladerf_submit_stream_buffer() or pybladerf_stream() calls.)

        Stream is deallocated and may no longer be used.
        '''
        ...

    def pybladerf_set_stream_timeout(self, direction: pybladerf_direction, timeout: int) -> None:
        '''Set stream transfer timeout in milliseconds'''
        ...

    def pybladerf_get_stream_timeout(self, direction: pybladerf_direction) -> int:
        '''Get transfer timeout in milliseconds'''
        ...

    def pybladerf_device_reset(self) -> None:
        '''Reset the device, causing it to reload its firmware from flash'''
        ...

    def pybladerf_get_fw_log(self, filename: str = None) -> None:
        '''
        Read firmware log data and write it to the specified file

        If filename set to None, log data will be printed to stdout.
        '''
        ...

    def pybladerf_set_vctcxo_tamer_mode(self, mode: pybladerf_vctcxo_tamer_mode) -> None:
        '''Set the VCTCXO tamer mode.'''
        ...

    def pybladerf_get_vctcxo_tamer_mode(self) -> pybladerf_vctcxo_tamer_mode:
        '''Get the current VCTCXO tamer mode'''
        ...

    def pybladerf_get_vctcxo_trim(self) -> int:
        '''Query a device's VCTCXO calibration trim'''
        ...

    def pybladerf_trim_dac_write(self, value: int) -> None:
        '''
        Write value to VCTCXO trim DAC.

        ! NOTE !
            This should not be used when the VCTCXO tamer is enabled.
        '''
        ...

    def pybladerf_trim_dac_read(self) -> int:
        '''
        Read value from VCTCXO trim DAC.

        This is similar to pybladerf_get_vctcxo_trim(), except that it returns the current trim DAC value, as opposed to the calibration value read from flash.

        Use this if you are trying to query the value after having previously made calls to pybladerf_trim_dac_write().
        '''
        ...

    def pybladerf_set_tuning_mode(self, mode: pybladerf_tuning_mode) -> None:
        '''Set the device's tuning mode'''
        ...

    def pybladerf_get_tuning_mode(self) -> pybladerf_tuning_mode:
        '''Get the device's current tuning mode'''
        ...

    def pybladerf_read_trigger(self, trigger_signal: pybladerf_trigger_signal) -> int:
        '''Read trigger control register'''
        ...

    def pybladerf_write_trigger(self, trigger_signal: pybladerf_trigger, value: int) -> None:
        '''Write trigger control register'''
        ...

    def pybladerf_set_rf_port(self, channel: int, port: str) -> None:
        '''Set the RF port'''
        ...

    def pybladerf_get_rf_port(self, channel: int) -> str:
        '''Get the RF port'''
        ...

    def pybladerf_get_rf_ports(self, channel: int) -> list[str]:
        '''Get available RF ports'''
        ...

    def pybladerf_enable_feature(self, feature: pybladerf_feature, enable: bool) -> None:
        '''Enables a feature.'''
        ...

    def pybladerf_get_feature(self) -> pybladerf_feature:
        '''Gets currently enabled feature.'''
        ...

    # ---- BLADERF2 ---- #
    def pybladerf_get_bias_tee(self, channel: int) -> bool:
        '''Get current bias tee state'''
        ...

    def pybladerf_set_bias_tee(self, channel: int, enable: bool) -> None:
        '''Set bias tee state'''
        ...

    def pybladerf_get_rfic_register(self, address: int) -> int:
        '''Read a RFIC register'''
        ...

    def pybladerf_set_rfic_register(self, address: int, value: int) -> None:
        '''Write a RFIC register'''
        ...

    def pybladerf_get_rfic_temperature(self) -> float:
        '''Read the temperature from the RFIC'''
        ...

    def pybladerf_get_rfic_rssi(self, channel: int) -> tuple[int]:
        '''
        Read the RSSI for the selected channel from the RFIC

        ! NOTE !
            This is a relative value, not an absolute value. If an absolute value (e.g. in dBm) is desired, a calibration should be performed against a reference signal.
        '''
        ...

    def pybladerf_get_rfic_ctrl_out(self) -> int:
        '''Read the CTRL_OUT pins from the RFIC'''
        ...

    def pybladerf_get_rfic_rx_fir(self) -> pybladerf_rfic_rxfir:
        '''Get the current status of the RX FIR filter on the RFIC.'''
        ...

    def pybladerf_set_rfic_rx_fir(self, rxfir: pybladerf_rfic_rxfir) -> None:
        '''Set the RX FIR filter on the RFIC.'''
        ...

    def pybladerf_get_rfic_tx_fir(self) -> pybladerf_rfic_txfir:
        '''Get the current status of the TX FIR filter on the RFIC.'''
        ...

    def pybladerf_set_rfic_tx_fir(self, txfir: pybladerf_rfic_txfir) -> None:
        '''Set the TX FIR filter on the RFIC.'''
        ...

    def pybladerf_get_pll_lock_state(self) -> bool:
        '''Fetch the lock state of the Phase Detector/Frequency Synthesizer'''
        ...

    def pybladerf_get_pll_enable(self) -> bool:
        '''Fetch the state of the Phase Detector/Frequency Synthesizer'''
        ...

    def pybladerf_set_pll_enable(self, enable: bool) -> None:
        '''
        Enable the Phase Detector/Frequency Synthesizer

        Enabling this disables the VCTCXO trimmer DAC, and vice versa.
        '''
        ...

    def pybladerf_get_pll_refclk_range(self) -> pybladerf_range:
        '''Get the valid range of frequencies for the reference clock input'''
        ...

    def pybladerf_get_pll_refclk(self) -> int:
        '''Get the currently-configured frequency for the reference clock input.'''
        ...

    def pybladerf_set_pll_refclk(self, frequency: int) -> None:
        '''Set the expected frequency for the reference clock input.'''
        ...

    def pybladerf_get_pll_register(self, address: int) -> int:
        '''
        Read value from Phase Detector/Frequency Synthesizer

        The `address` is interpreted as the control bits (DB1 and DB0) used to write to a specific latch.
        '''
        ...

    def pybladerf_set_pll_register(self, address: int, value: int) -> None:
        '''
        Write value to Phase Detector/Frequency Synthesizer

        The `address` is interpreted as the control bits (DB1 and DB0) used to write to a specific latch.  These bits are masked out in `val`
        '''
        ...

    def pybladerf_get_power_source(self) -> pybladerf_power_sources:
        '''Get the active power source reported by the power multiplexer'''
        ...

    def pybladerf_get_clock_select(self) -> pybladerf_clock_select:
        '''Get the selected clock source'''
        ...

    def pybladerf_set_clock_select(self, sel: pybladerf_clock_select) -> None:
        '''Set the clock source'''
        ...

    def pybladerf_get_clock_output(self) -> bool:
        '''Get the current state of the clock output'''
        ...

    def pybladerf_set_clock_output(self, enable: bool) -> None:
        '''Set the clock output (enable/disable)'''
        ...

    def pybladerf_get_pmic_register(self, reg: pybladerf_pmic_register) -> int | float:
        '''Read value from Power Monitor IC'''

    def pybladerf_get_rf_switch_config(self) -> pybladerf_rf_switch_config:
        '''
        Read the current RF switching configuration from the bladeRF hardware.

        Queries both the RFIC and the RF switch and passes back a pybladerf_rf_switch_config stucture.
        '''

    # ---- new function ---- #
    def pybladerf_enable_tx_block_complete_callback(self) -> None:
        '''
        Setup callback to be called when an USB transfer is completed.

        This callback will be called whenever an USB transfer to the device is completed, regardless if it was successful or not

        ! NOTE !
            Only for async mode
        '''

    # ---- python callbacks setters ---- #
    def set_rx_callback(self, rx_callback_function: Callable[[Self, pybladerf_stream, np.ndarray, int], int]) -> None:
        '''
        Accept a 4 args that contains the device, pystream, buffer and number of complex samples in the buffer data.
        device: PyBladerfDevice, pystream: pybladerf_stream, buffer: numpy.array(dtype=numpy.int8 | numpy.int16), num_samples: int

        Should copy/process the contents of the buffer's valid part.

        The callback should return 0 if it wants to be called again, and any other value otherwise.
        '''
        ...

    def set_tx_callback(self, tx_callback_function: Callable[[Self, pybladerf_stream, np.ndarray, int, int], int]) -> None:
        '''
        Accept a 5 args that contains the device, pystream, buffer, the number of complex samples and the valid complex samples in the buffer data.
        device: PyBladerfDevice, pystream: pybladerf_stream, buffer: numpy.array(dtype=numpy.int8 | numpy.int16), num_samples: int, valid_num_samples: int

        The callback should return 0 or 1 if it should be called again, and any other value otherwise.
        You should change the value of the valid_num_samples variable to the number of modified samples in the buffer.

        return 1 if you will call pybladerf_submit_stream_buffer() or pybladerf_submit_stream_buffer_nb()
        '''
        ...

    def set_tx_complete_callback(self, tx_complete_callback_function: Callable[[Self, pybladerf_stream, np.ndarray, int], None]) -> None:
        '''
        Accept a 4 args that contains the device, buffer and number of complex samples in the buffer data.
        device: PyBladerfDevice, pystream: pybladerf_stream, buffer: numpy.array(dtype=numpy.int8 | numpy.int16), num_samples: int
        '''
        ...

def pybladerf_open() -> PyBladerfDevice | None:
    '''Open first available bladeRF device'''
    ...

def pybladerf_open_by_serial(desired_serial_number: str) -> PyBladerfDevice | None:
    '''Open bladeRF device by serial number'''
    ...

def pybladerf_open_with_devinfo(devinfo: pybladerf_devinfo) -> PyBladerfDevice | None:
    '''
    Opens device specified by provided pybladerf_devinfo structure

    This function is generally preferred over bladerf_open() when a device identifier string is not already provided.

    The most common uses of this function are to:
        - Open a device based upon the results of PyBladeRFDeviceList()
        - Open a specific device based upon its serial number
    '''
    ...

def pybladerf_get_devinfo_from_str(devstr: str) -> pybladerf_devinfo:
    '''Populate a device identifier information structure using the provided device identifier string.'''
    ...

def pybladerf_devinfo_matches(a: pybladerf_devinfo, b: pybladerf_devinfo) -> bool:
    '''Test whether two device identifier information structures match, taking wildcard values into account.'''
    ...

def pybladerf_devstr_matches(dev_str: str, info: pybladerf_devinfo) -> bool:
    '''Test whether a provided device string matches a device described by the provided bladerf_devinfo structure'''
    ...

def pybladerf_set_usb_reset_on_open(enabled: bool) -> None:
    '''
    Enable or disable USB device reset operation upon opening a device for future pybladerf_open() and pybladerf_open_with_devinfo() calls.

    This operation has been found to be necessary on Linux-based systems for some USB 3.0 controllers on Linux.

    This does not reset the state of the device in terms of its frequency, gain, sample rate, etc. settings.
    '''
    ...

def pybladerf_log_set_verbosity(level: pybladerf_log_level) -> None:
    '''
    Sets the filter level for displayed log messages.

    Messages that are at or above the specified log level will be printed, while messages with a lower log level will be suppressed.
    '''
    ...

def pybladerf_library_version() -> pybladerf_version:
    '''Get libbladeRF version information'''
    ...

def python_bladerf_library_version() -> pybladerf_version:
    '''Get python_bladerf version information '''
    ...
