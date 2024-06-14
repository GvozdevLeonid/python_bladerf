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
from python_bladerf import __version__
from libc.stdint cimport uint8_t, int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t
from libc.stdlib cimport malloc, free
from . cimport cbladerf

from enum import IntEnum
cimport numpy as np
import numpy as np


def PYBLADERF_CHANNEL_RX(ch: int) -> int:
    return <cbladerf.bladerf_channel> (((ch) << 1) | 0x0)


def PYBLADERF_CHANNEL_TX(ch: int) -> int:
    return <cbladerf.bladerf_channel> (((ch) << 1) | 0x1)


def PYBLADERF_CHANNEL_INVALID(ch: int) -> int:
    return -1


def PYBLADERF_CHANNEL_IS_TX(ch) -> bool:
    return (ch & cbladerf.BLADERF_TX)


PYBLADERF_DIRECTION_MASK = 0x1

PYBLADERF_GAIN_AUTOMATIC = cbladerf.BLADERF_GAIN_DEFAULT
PYBLADERF_GAIN_MANUAL = cbladerf.BLADERF_GAIN_MGC

PYBLADERF_RX_MUX_BASEBAND_LMS = cbladerf.BLADERF_RX_MUX_BASEBAND

PYBLADERF_RETUNE_NOW = <cbladerf.bladerf_timestamp> 0

PYBLADERF_CORR_LMS_DCOFF_I = cbladerf.BLADERF_CORR_DCOFF_I
PYBLADERF_CORR_LMS_DCOFF_Q = cbladerf.BLADERF_CORR_DCOFF_Q
PYBLADERF_CORR_FPGA_PHASE = cbladerf.BLADERF_CORR_PHASE
PYBLADERF_CORR_FPGA_GAIN = cbladerf.BLADERF_CORR_GAIN

PYBLADERF_META_STATUS_OVERRUN = (1 << 0)
PYBLADERF_META_STATUS_UNDERRUN = (1 << 1)
PYBLADERF_META_FLAG_TX_BURST_START = (1 << 0)
PYBLADERF_META_FLAG_TX_BURST_END = (1 << 1)
PYBLADERF_META_FLAG_TX_NOW = (1 << 2)
PYBLADERF_META_FLAG_TX_UPDATE_TIMESTAMP = (1 << 3)
PYBLADERF_META_FLAG_RX_NOW = (1 << 31)
PYBLADERF_META_FLAG_RX_HW_UNDERFLOW = (1 << 0)
PYBLADERF_META_FLAG_RX_HW_MINIEXP1 = (1 << 16)
PYBLADERF_META_FLAG_RX_HW_MINIEXP2 = (1 << 17)

cdef void* PYBLADERF_STREAM_SHUTDOWN = NULL
cdef void* PYBLADERF_STREAM_NO_DATA = cbladerf.BLADERF_STREAM_NO_DATA

PYBLADERF_IMAGE_MAGIC_LEN = cbladerf.BLADERF_IMAGE_MAGIC_LEN
PYBLADERF_IMAGE_CHECKSUM_LEN = cbladerf.BLADERF_IMAGE_CHECKSUM_LEN
PYBLADERF_IMAGE_RESERVED_LEN = cbladerf.BLADERF_IMAGE_RESERVED_LEN

PYBLADERF_TRIGGER_REG_ARM = <uint8_t> (1 << 0)
PYBLADERF_TRIGGER_REG_FIRE = <uint8_t> (1 << 1)
PYBLADERF_TRIGGER_REG_MASTER = <uint8_t> (1 << 2)
PYBLADERF_TRIGGER_REG_LINE = <uint8_t> (1 << 3)


# ---- ERROR ---- #
class PYBLADERF_ERR(Exception):
    def __init__(self, message, code):
        super().__init__(message + f' failed: {cbladerf.bladerf_strerror(code).decode("utf-8")} ({code})')
        self.code = code


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


PYBLADERF_ERROR_MAP = {
    -1: PYBLADERF_ERR_UNEXPECTED,
    -2: PYBLADERF_ERR_RANGE,
    -3: PYBLADERF_ERR_INVAL,
    -4: PYBLADERF_ERR_MEM,
    -5: PYBLADERF_ERR_IO,
    -6: PYBLADERF_ERR_TIMEOUT,
    -7: PYBLADERF_ERR_NODEV,
    -8: PYBLADERF_ERR_UNSUPPORTED,
    -9: PYBLADERF_ERR_MISALIGNED,
    -10: PYBLADERF_ERR_CHECKSUM,
    -11: PYBLADERF_ERR_NO_FILE,
    -12: PYBLADERF_ERR_UPDATE_FPGA,
    -13: PYBLADERF_ERR_UPDATE_FW,
    -14: PYBLADERF_ERR_TIME_PAST,
    -15: PYBLADERF_ERR_QUEUE_FULL,
    -16: PYBLADERF_ERR_FPGA_OP,
    -17: PYBLADERF_ERR_PERMISSION,
    -18: PYBLADERF_ERR_WOULD_BLOCK,
    -19: PYBLADERF_ERR_NOT_INIT,
}


def raise_error(message, err):
    if err < 0:
        error_class = PYBLADERF_ERROR_MAP.get(err, PYBLADERF_ERR)
        raise error_class(message, err)


# ---- ENUM ---- #
class pybladerf_backend(IntEnum):
    PYBLADERF_BACKEND_ANY = cbladerf.BLADERF_BACKEND_ANY
    PYBLADERF_BACKEND_LINUX = cbladerf.BLADERF_BACKEND_LINUX
    PYBLADERF_BACKEND_LIBUSB = cbladerf.BLADERF_BACKEND_LIBUSB
    PYBLADERF_BACKEND_CYPRESS = cbladerf.BLADERF_BACKEND_CYPRESS
    PYBLADERF_BACKEND_DUMMY = cbladerf.BLADERF_BACKEND_DUMMY

    def __str__(self):
        return self.name


class pybladerf_fpga_size(IntEnum):
    PYBLADERF_FPGA_UNKNOWN = cbladerf.BLADERF_FPGA_UNKNOWN
    PYBLADERF_FPGA_40KLE = cbladerf.BLADERF_FPGA_40KLE
    PYBLADERF_FPGA_115KLE = cbladerf.BLADERF_FPGA_115KLE
    PYBLADERF_FPGA_A4 = cbladerf.BLADERF_FPGA_A4
    PYBLADERF_FPGA_A5 = cbladerf.BLADERF_FPGA_A5
    PYBLADERF_FPGA_A9 = cbladerf.BLADERF_FPGA_A9

    def __str__(self):
        return self.name


class pybladerf_dev_speed(IntEnum):
    PYBLADERF_DEVICE_SPEED_UNKNOWN = cbladerf.BLADERF_DEVICE_SPEED_UNKNOWN
    PYBLADERF_DEVICE_SPEED_HIGH = cbladerf.BLADERF_DEVICE_SPEED_HIGH
    PYBLADERF_DEVICE_SPEED_SUPER = cbladerf.BLADERF_DEVICE_SPEED_SUPER

    def __str__(self):
        if self.value == pybladerf_dev_speed.PYBLADERF_DEVICE_SPEED_HIGH:
            return 'HighSpeed'
        elif self.value == pybladerf_dev_speed.PYBLADERF_DEVICE_SPEED_SUPER:
            return 'SuperSpeed'
        else:
            return 'Unknown'


class pybladerf_fpga_source(IntEnum):
    PYBLADERF_FPGA_SOURCE_UNKNOWN = cbladerf.BLADERF_FPGA_SOURCE_UNKNOWN
    PYBLADERF_FPGA_SOURCE_FLASH = cbladerf.BLADERF_FPGA_SOURCE_FLASH
    PYBLADERF_FPGA_SOURCE_HOST = cbladerf.BLADERF_FPGA_SOURCE_HOST

    def __str__(self):
        return self.name


class pybladerf_direction(IntEnum):
    PYBLADERF_RX = cbladerf.BLADERF_RX
    PYBLADERF_TX = cbladerf.BLADERF_TX

    def __str__(self):
        return self.name


class pybladerf_channel_layout(IntEnum):
    PYBLADERF_RX_X1 = cbladerf.BLADERF_RX_X1
    PYBLADERF_TX_X1 = cbladerf.BLADERF_TX_X1
    PYBLADERF_RX_X2 = cbladerf.BLADERF_RX_X2
    PYBLADERF_TX_X2 = cbladerf.BLADERF_TX_X2

    def __str__(self):
        return self.name


class pybladerf_gain_mode(IntEnum):
    PYBLADERF_GAIN_DEFAULT = cbladerf.BLADERF_GAIN_DEFAULT
    PYBLADERF_GAIN_MGC = cbladerf.BLADERF_GAIN_MGC
    PYBLADERF_GAIN_FASTATTACK_AGC = cbladerf.BLADERF_GAIN_FASTATTACK_AGC
    PYBLADERF_GAIN_SLOWATTACK_AGC = cbladerf.BLADERF_GAIN_SLOWATTACK_AGC
    PYBLADERF_GAIN_HYBRID_AGC = cbladerf.BLADERF_GAIN_HYBRID_AGC

    def __str__(self):
        return self.name


class pybladerf_loopback(IntEnum):
    PYBLADERF_LB_NONE = cbladerf.BLADERF_LB_NONE
    PYBLADERF_LB_FIRMWARE = cbladerf.BLADERF_LB_FIRMWARE
    PYBLADERF_LB_BB_TXLPF_RXVGA2 = cbladerf.BLADERF_LB_BB_TXLPF_RXVGA2
    PYBLADERF_LB_BB_TXVGA1_RXVGA2 = cbladerf.BLADERF_LB_BB_TXVGA1_RXVGA2
    PYBLADERF_LB_BB_TXLPF_RXLPF = cbladerf.BLADERF_LB_BB_TXLPF_RXLPF
    PYBLADERF_LB_BB_TXVGA1_RXLPF = cbladerf.BLADERF_LB_BB_TXVGA1_RXLPF
    PYBLADERF_LB_RF_LNA1 = cbladerf.BLADERF_LB_RF_LNA1
    PYBLADERF_LB_RF_LNA2 = cbladerf.BLADERF_LB_RF_LNA2
    PYBLADERF_LB_RF_LNA3 = cbladerf.BLADERF_LB_RF_LNA3
    PYBLADERF_LB_RFIC_BIST = cbladerf.BLADERF_LB_RFIC_BIST

    def __str__(self):
        return self.name


class pybladerf_trigger_role(IntEnum):
    PYBLADERF_TRIGGER_ROLE_INVALID = cbladerf.BLADERF_TRIGGER_ROLE_INVALID
    PYBLADERF_TRIGGER_ROLE_DISABLED = cbladerf.BLADERF_TRIGGER_ROLE_DISABLED
    PYBLADERF_TRIGGER_ROLE_MASTER = cbladerf.BLADERF_TRIGGER_ROLE_MASTER
    PYBLADERF_TRIGGER_ROLE_SLAVE = cbladerf.BLADERF_TRIGGER_ROLE_SLAVE

    def __str__(self):
        return self.name


class pybladerf_trigger_signal(IntEnum):
    PYBLADERF_TRIGGER_INVALID = cbladerf.BLADERF_TRIGGER_INVALID
    PYBLADERF_TRIGGER_J71_4 = cbladerf.BLADERF_TRIGGER_J71_4
    PYBLADERF_TRIGGER_J51_1 = cbladerf.BLADERF_TRIGGER_J51_1
    PYBLADERF_TRIGGER_MINI_EXP_1 = cbladerf.BLADERF_TRIGGER_MINI_EXP_1
    PYBLADERF_TRIGGER_USER_0 = cbladerf.BLADERF_TRIGGER_USER_0
    PYBLADERF_TRIGGER_USER_1 = cbladerf.BLADERF_TRIGGER_USER_1
    PYBLADERF_TRIGGER_USER_2 = cbladerf.BLADERF_TRIGGER_USER_2
    PYBLADERF_TRIGGER_USER_3 = cbladerf.BLADERF_TRIGGER_USER_3
    PYBLADERF_TRIGGER_USER_4 = cbladerf.BLADERF_TRIGGER_USER_4
    PYBLADERF_TRIGGER_USER_5 = cbladerf.BLADERF_TRIGGER_USER_5
    PYBLADERF_TRIGGER_USER_6 = cbladerf.BLADERF_TRIGGER_USER_6
    PYBLADERF_TRIGGER_USER_7 = cbladerf.BLADERF_TRIGGER_USER_7

    def __str__(self):
        return self.name


class pybladerf_rx_mux(IntEnum):
    PYBLADERF_RX_MUX_INVALID = cbladerf.BLADERF_RX_MUX_INVALID
    PYBLADERF_RX_MUX_BASEBAND = cbladerf.BLADERF_RX_MUX_BASEBAND
    PYBLADERF_RX_MUX_12BIT_COUNTER = cbladerf.BLADERF_RX_MUX_12BIT_COUNTER
    PYBLADERF_RX_MUX_32BIT_COUNTER = cbladerf.BLADERF_RX_MUX_32BIT_COUNTER
    PYBLADERF_RX_MUX_DIGITAL_LOOPBACK = cbladerf.BLADERF_RX_MUX_DIGITAL_LOOPBACK

    def __str__(self):
        return self.name


class pybladerf_correction(IntEnum):
    PYBLADERF_CORR_DCOFF_I = cbladerf.BLADERF_CORR_DCOFF_I
    PYBLADERF_CORR_DCOFF_Q = cbladerf.BLADERF_CORR_DCOFF_Q
    PYBLADERF_CORR_PHASE = cbladerf.BLADERF_CORR_PHASE
    PYBLADERF_CORR_GAIN = cbladerf.BLADERF_CORR_GAIN

    def __str__(self):
        return self.name


class pybladerf_format(IntEnum):
    PYBLADERF_FORMAT_SC16_Q11 = cbladerf.BLADERF_FORMAT_SC16_Q11
    PYBLADERF_FORMAT_SC16_Q11_META = cbladerf.BLADERF_FORMAT_SC16_Q11_META
    PYBLADERF_FORMAT_PACKET_META = cbladerf.BLADERF_FORMAT_PACKET_META
    PYBLADERF_FORMAT_SC8_Q7 = cbladerf.BLADERF_FORMAT_SC8_Q7
    PYBLADERF_FORMAT_SC8_Q7_META = cbladerf.BLADERF_FORMAT_SC8_Q7_META

    def __str__(self):
        return self.name


class pybladerf_image_type(IntEnum):
    PYBLADERF_IMAGE_TYPE_INVALID = cbladerf.BLADERF_IMAGE_TYPE_INVALID
    PYBLADERF_IMAGE_TYPE_RAW = cbladerf.BLADERF_IMAGE_TYPE_RAW
    PYBLADERF_IMAGE_TYPE_FIRMWARE = cbladerf.BLADERF_IMAGE_TYPE_FIRMWARE
    PYBLADERF_IMAGE_TYPE_FPGA_40KLE = cbladerf.BLADERF_IMAGE_TYPE_FPGA_40KLE
    PYBLADERF_IMAGE_TYPE_FPGA_115KLE = cbladerf.BLADERF_IMAGE_TYPE_FPGA_115KLE
    PYBLADERF_IMAGE_TYPE_FPGA_A4 = cbladerf.BLADERF_IMAGE_TYPE_FPGA_A4
    PYBLADERF_IMAGE_TYPE_FPGA_A9 = cbladerf.BLADERF_IMAGE_TYPE_FPGA_A9
    PYBLADERF_IMAGE_TYPE_CALIBRATION = cbladerf.BLADERF_IMAGE_TYPE_CALIBRATION
    PYBLADERF_IMAGE_TYPE_RX_DC_CAL = cbladerf.BLADERF_IMAGE_TYPE_RX_DC_CAL
    PYBLADERF_IMAGE_TYPE_TX_DC_CAL = cbladerf.BLADERF_IMAGE_TYPE_TX_DC_CAL
    PYBLADERF_IMAGE_TYPE_RX_IQ_CAL = cbladerf.BLADERF_IMAGE_TYPE_RX_IQ_CAL
    PYBLADERF_IMAGE_TYPE_TX_IQ_CAL = cbladerf.BLADERF_IMAGE_TYPE_TX_IQ_CAL
    PYBLADERF_IMAGE_TYPE_FPGA_A5 = cbladerf.BLADERF_IMAGE_TYPE_FPGA_A5

    def __str__(self):
        return self.name


class pybladerf_vctcxo_tamer_mode(IntEnum):
    PYBLADERF_VCTCXO_TAMER_INVALID = cbladerf.BLADERF_VCTCXO_TAMER_INVALID
    PYBLADERF_VCTCXO_TAMER_DISABLED = cbladerf.BLADERF_VCTCXO_TAMER_DISABLED
    PYBLADERF_VCTCXO_TAMER_1_PPS = cbladerf.BLADERF_VCTCXO_TAMER_1_PPS
    PYBLADERF_VCTCXO_TAMER_10_MHZ = cbladerf.BLADERF_VCTCXO_TAMER_10_MHZ

    def __str__(self):
        return self.name


class pybladerf_tuning_mode(IntEnum):
    PYBLADERF_TUNING_MODE_INVALID = cbladerf.BLADERF_TUNING_MODE_INVALID
    PYBLADERF_TUNING_MODE_HOST = cbladerf.BLADERF_TUNING_MODE_HOST
    PYBLADERF_TUNING_MODE_FPGA = cbladerf.BLADERF_TUNING_MODE_FPGA

    def __str__(self):
        return self.name


class pybladerf_feature(IntEnum):
    PYBLADERF_FEATURE_DEFAULT = cbladerf.BLADERF_FEATURE_DEFAULT
    PYBLADERF_FEATURE_OVERSAMPLE = cbladerf.BLADERF_FEATURE_OVERSAMPLE

    def __str__(self):
        return self.name


class pybladerf_xb(IntEnum):
    PYBLADERF_XB_NONE = cbladerf.BLADERF_XB_NONE
    PYBLADERF_XB_100 = cbladerf.BLADERF_XB_100
    PYBLADERF_XB_200 = cbladerf.BLADERF_XB_200
    PYBLADERF_XB_300 = cbladerf.BLADERF_XB_300

    def __str__(self):
        return self.name


class pybladerf_log_level(IntEnum):
    PYBLADERF_LOG_LEVEL_VERBOSE = cbladerf.BLADERF_LOG_LEVEL_VERBOSE
    PYBLADERF_LOG_LEVEL_DEBUG = cbladerf.BLADERF_LOG_LEVEL_DEBUG
    PYBLADERF_LOG_LEVEL_INFO = cbladerf.BLADERF_LOG_LEVEL_INFO
    PYBLADERF_LOG_LEVEL_WARNING = cbladerf.BLADERF_LOG_LEVEL_WARNING
    PYBLADERF_LOG_LEVEL_ERROR = cbladerf.BLADERF_LOG_LEVEL_ERROR
    PYBLADERF_LOG_LEVEL_CRITICAL = cbladerf.BLADERF_LOG_LEVEL_CRITICAL
    PYBLADERF_LOG_LEVEL_SILENT = cbladerf.BLADERF_LOG_LEVEL_SILENT

    def __str__(self):
        return self.name


class pybladerf_rfic_rxfir(IntEnum):
    PYBLADERF_RFIC_RXFIR_BYPASS = cbladerf.BLADERF_RFIC_RXFIR_BYPASS
    PYBLADERF_RFIC_RXFIR_CUSTOM = cbladerf.BLADERF_RFIC_RXFIR_CUSTOM
    PYBLADERF_RFIC_RXFIR_DEC1 = cbladerf.BLADERF_RFIC_RXFIR_DEC1
    PYBLADERF_RFIC_RXFIR_DEC2 = cbladerf.BLADERF_RFIC_RXFIR_DEC2
    PYBLADERF_RFIC_RXFIR_DEC4 = cbladerf.BLADERF_RFIC_RXFIR_DEC4

    def __str__(self):
        return self.name


class pybladerf_rfic_txfir(IntEnum):
    PYBLADERF_RFIC_TXFIR_BYPASS = cbladerf.BLADERF_RFIC_TXFIR_BYPASS
    PYBLADERF_RFIC_TXFIR_CUSTOM = cbladerf.BLADERF_RFIC_TXFIR_CUSTOM
    PYBLADERF_RFIC_TXFIR_INT1 = cbladerf.BLADERF_RFIC_TXFIR_INT1
    PYBLADERF_RFIC_TXFIR_INT2 = cbladerf.BLADERF_RFIC_TXFIR_INT2
    PYBLADERF_RFIC_TXFIR_INT4 = cbladerf.BLADERF_RFIC_TXFIR_INT4

    def __str__(self):
        return self.name


class pybladerf_power_sources(IntEnum):
    PYBLADERF_UNKNOWN = cbladerf.BLADERF_UNKNOWN
    PYBLADERF_PS_DC = cbladerf.BLADERF_PS_DC
    PYBLADERF_PS_USB_VBUS = cbladerf.BLADERF_PS_USB_VBUS

    def __str__(self):
        return self.name


class pybladerf_clock_select(IntEnum):
    PYCLOCK_SELECT_ONBOARD = cbladerf.CLOCK_SELECT_ONBOARD
    PYCLOCK_SELECT_EXTERNAL = cbladerf.CLOCK_SELECT_EXTERNAL

    def __str__(self):
        return self.name


class pybladerf_pmic_register(IntEnum):
    PYBLADERF_PMIC_CONFIGURATION = cbladerf.BLADERF_PMIC_CONFIGURATION
    PYBLADERF_PMIC_VOLTAGE_SHUNT = cbladerf.BLADERF_PMIC_VOLTAGE_SHUNT
    PYBLADERF_PMIC_VOLTAGE_BUS = cbladerf.BLADERF_PMIC_VOLTAGE_BUS
    PYBLADERF_PMIC_POWER = cbladerf.BLADERF_PMIC_POWER
    PYBLADERF_PMIC_CURRENT = cbladerf.BLADERF_PMIC_CURRENT
    PYBLADERF_PMIC_CALIBRATION = cbladerf.BLADERF_PMIC_CALIBRATION

    def __str__(self):
        return self.name


class pybladerf_sweep_style(IntEnum):
    PYBLADERF_SWEEP_STYLE_LINEAR = 0
    PYBLADERF_SWEEP_STYLE_INTERLEAVED = 1

    def __str__(self):
        return self.name


# ---- STRUCT ---- #
cdef class pybladerf_devinfo:
    cdef cbladerf.bladerf_devinfo* __bladerf_devinfo

    def __init__(self,
                 backend: pybladerf_backend = None,
                 serial: str = None,
                 usb_bus: int = None,
                 usb_addr: int = None,
                 instance: int = None,
                 manufacturer: str = None,
                 product: str = None) -> None:

        self.__bladerf_devinfo = <cbladerf.bladerf_devinfo*> malloc(sizeof(cbladerf.bladerf_devinfo))

        self.backend = backend
        self.serial = serial
        self.usb_bus = usb_bus
        self.usb_addr = usb_addr
        self.instance = instance
        self.manufacturer = manufacturer
        self.product = product

    def __dealloc__(self):
        if self.__bladerf_devinfo != NULL:
            free(self.__bladerf_devinfo)

    def __str__(self) -> str:
        return f'{pybladerf_backend_str(self.backend)}:device={self.usb_bus}:{self.usb_addr} instance={self.instance} serial={self.serial}'

    property backend:
        def __get__(self):
            return self.__bladerf_devinfo[0].backend

        def __set__(self, value):
            if value is not None:
                self.__bladerf_devinfo[0].backend = value

    property serial:
        def __get__(self):
            return self.__bladerf_devinfo[0].serial.decode('utf-8')

        def __set__(self, value):
            if value is not None:
                self.__bladerf_devinfo[0].serial = value.encode('utf-8')

    property usb_bus:
        def __get__(self):
            return self.__bladerf_devinfo[0].usb_bus

        def __set__(self, value):
            if value is not None:
                self.__bladerf_devinfo[0].usb_bus = <uint8_t> value

    property usb_addr:
        def __get__(self):
            return self.__bladerf_devinfo[0].usb_addr

        def __set__(self, value):
            if value is not None:
                self.__bladerf_devinfo[0].usb_addr = <uint8_t> value

    property instance:
        def __get__(self):
            return self.__bladerf_devinfo[0].instance

        def __set__(self, value):
            if value is not None:
                self.__bladerf_devinfo[0].instance = <unsigned int> value

    property manufacturer:
        def __get__(self):
            return self.__bladerf_devinfo[0].manufacturer.decode('utf-8')

        def __set__(self, value):
            if value is not None:
                self.__bladerf_devinfo[0].manufacturer = value.encode('utf-8')

    property product:
        def __get__(self):
            return self.__bladerf_devinfo[0].product.decode('utf-8')

        def __set__(self, value):
            if value is not None:
                self.__bladerf_devinfo[0].product = value.encode('utf-8')

    cdef from_bladerf_devinfo(self, bladerf_devinfo: cbladerf.bladerf_devinfo):
        self.__bladerf_devinfo[0] = bladerf_devinfo

    cdef cbladerf.bladerf_devinfo get_obj(self):
        return self.__bladerf_devinfo[0]

    cdef cbladerf.bladerf_devinfo* get_ptr(self):
        return self.__bladerf_devinfo

    cdef cbladerf.bladerf_devinfo** get_double_ptr(self):
        return &self.__bladerf_devinfo


cdef class pybladerf_version:
    cdef cbladerf.bladerf_version* __bladerf_version

    def __init__(self,
                 major: int = None,
                 minor: int = None,
                 patch: int = None,
                 describe: str = None) -> None:

        self.__bladerf_version = <cbladerf.bladerf_version*> malloc(sizeof(cbladerf.bladerf_version))

        self.major = major
        self.minor = minor
        self.patch = patch
        self.describe = describe

    def __dealloc__(self):
        if self.__bladerf_version != NULL:
            free(self.__bladerf_version)

    def __str__(self):
        return f'{self.major}.{self.minor}.{self.patch} \"{self.describe}\"'

    property major:
        def __get__(self):
            return self.__bladerf_version[0].major

        def __set__(self, value):
            if value is not None:
                self.__bladerf_version[0].major = <uint16_t> value

    property minor:
        def __get__(self):
            return self.__bladerf_version[0].minor

        def __set__(self, value):
            if value is not None:
                self.__bladerf_version[0].minor = <uint16_t> value

    property patch:
        def __get__(self):
            return self.__bladerf_version[0].patch

        def __set__(self, value):
            if value is not None:
                self.__bladerf_version[0].patch = <uint16_t> value

    property describe:
        def __get__(self):
            return self.__bladerf_version[0].describe.decode('utf-8')

        def __set__(self, value):
            if value is not None:
                value_bytes = value.encode('utf-8')
                self.__bladerf_version[0].describe = value_bytes

    cdef from_bladerf_version(self, bladerf_version: cbladerf.bladerf_version):
        self.__bladerf_version[0] = bladerf_version

    cdef cbladerf.bladerf_version get_obj(self):
        return self.__bladerf_version[0]

    cdef cbladerf.bladerf_version* get_ptr(self):
        return self.__bladerf_version

    cdef cbladerf.bladerf_version** get_double_ptr(self):
        return &self.__bladerf_version


cdef class pybladerf_range:
    cdef cbladerf.bladerf_range* __bladerf_range

    def __init__(self,
                 min: int = None,
                 max: int = None,
                 step: int = None,
                 scale: float = None) -> None:

        # self.__bladerf_range = <cbladerf.bladerf_range*> malloc(sizeof(cbladerf.bladerf_range))

        self.min = min
        self.max = max
        self.step = step
        self.scale = scale

    # def __dealloc__(self):
    #     if self.__bladerf_range != NULL:
    #         free(self.__bladerf_range)

    def __str__(self):
        return f'min:{self.min} max:{self.max} step:{self.step} scale:{self.scale}'

    property min:
        def __get__(self):
            return self.__bladerf_range[0].min

        def __set__(self, value):
            if value is not None:
                self.__bladerf_range[0].min = <int64_t> value

    property max:
        def __get__(self):
            return self.__bladerf_range[0].max

        def __set__(self, value):
            if value is not None:
                self.__bladerf_range[0].max = <int64_t> value

    property step:
        def __get__(self):
            return self.__bladerf_range[0].step

        def __set__(self, value):
            if value is not None:
                self.__bladerf_range[0].step = <int64_t> value

    property scale:
        def __get__(self):
            return self.__bladerf_range[0].scale

        def __set__(self, value):
            if value is not None:
                self.__bladerf_range[0].scale = value

    cdef from_bladerf_range(self, bladerf_range):
        self.__bladerf_range[0] = bladerf_range

    cdef cbladerf.bladerf_range get_obj(self):
        return self.__bladerf_range[0]

    cdef cbladerf.bladerf_range* get_ptr(self):
        return self.__bladerf_range

    cdef cbladerf.bladerf_range** get_double_ptr(self):
        return &self.__bladerf_range


cdef class pybladerf_trigger:
    cdef cbladerf.bladerf_trigger* __bladerf_trigger

    def __init__(self,
                 channel: int = None,
                 role: pybladerf_trigger_role = None,
                 signal: pybladerf_trigger_signal = None,
                 options: int = None) -> None:

        self.__bladerf_trigger = <cbladerf.bladerf_trigger*> malloc(sizeof(cbladerf.bladerf_trigger))

        self.channel = channel
        self.role = role
        self.signal = signal
        self.options = options

    def __dealloc__(self):
        if self.__bladerf_trigger != NULL:
            free(self.__bladerf_trigger)

    def __str__(self):
        return f'channel:{self.channel} role:{self.role} signal:{self.signal} options:{self.options}'

    property channel:
        def __get__(self):
            return self.__bladerf_trigger[0].channel

        def __set__(self, value):
            if value is not None:
                self.__bladerf_trigger[0].channel = value

    property role:
        def __get__(self):
            return pybladerf_trigger_role(self.__bladerf_trigger[0].role)

        def __set__(self, value):
            if value is not None:
                self.__bladerf_trigger[0].role = value

    property signal:
        def __get__(self):
            return pybladerf_trigger_signal(self.__bladerf_trigger[0].signal)

        def __set__(self, value):
            if value is not None:
                self.__bladerf_trigger[0].signal = value

    property options:
        def __get__(self):
            return self.__bladerf_trigger[0].options

        def __set__(self, value):
            if value is not None:
                self.__bladerf_trigger[0].options = <uint64_t> value

    cdef from_bladerf_trigger(self, bladerf_trigger: cbladerf.bladerf_trigger):
        self.__bladerf_trigger[0] = bladerf_trigger

    cdef cbladerf.bladerf_trigger get_obj(self):
        return self.__bladerf_trigger[0]

    cdef cbladerf.bladerf_trigger* get_ptr(self):
        return self.__bladerf_trigger

    cdef cbladerf.bladerf_trigger** get_double_ptr(self):
        return &self.__bladerf_trigger


cdef class pybladerf_quick_tune:
    cdef cbladerf.bladerf_quick_tune* __bladerf_quick_tune

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

        self.__bladerf_quick_tune = <cbladerf.bladerf_quick_tune*> malloc(sizeof(cbladerf.bladerf_quick_tune))

        self.freqsel = freqsel
        self.vcocap = vcocap
        self.nint = nint
        self.nfrac = nfrac
        self.flags = flags
        self.xb_gpio = xb_gpio
        self.nios_profile = nios_profile
        self.rffe_profile = rffe_profile
        self.port = port
        self.spdt = spdt

    def __dealloc__(self):
        if self.__bladerf_quick_tune != NULL:
            free(self.__bladerf_quick_tune)

    property freqsel:
        def __get__(self):
            return self.__bladerf_quick_tune[0].freqsel

        def __set__(self, value):
            if value is not None:
                self.__bladerf_quick_tune[0].freqsel = <uint8_t> value

    property vcocap:
        def __get__(self):
            return self.__bladerf_quick_tune[0].vcocap

        def __set__(self, value):
            if value is not None:
                self.__bladerf_quick_tune[0].vcocap = <uint8_t> value

    property nint:
        def __get__(self):
            return self.__bladerf_quick_tune[0].nint

        def __set__(self, value):
            if value is not None:
                self.__bladerf_quick_tune[0].nint = <uint16_t> value

    property nfrac:
        def __get__(self):
            return self.__bladerf_quick_tune[0].nfrac

        def __set__(self, value):
            if value is not None:
                self.__bladerf_quick_tune[0].nfrac = <uint32_t> value

    property flags:
        def __get__(self):
            return self.__bladerf_quick_tune[0].flags

        def __set__(self, value):
            if value is not None:
                self.__bladerf_quick_tune[0].flags = <uint8_t> value

    property xb_gpio:
        def __get__(self):
            return self.__bladerf_quick_tune[0].xb_gpio

        def __set__(self, value):
            if value is not None:
                self.__bladerf_quick_tune[0].xb_gpio = <uint8_t> value

    property nios_profile:
        def __get__(self):
            return self.__bladerf_quick_tune[0].nios_profile

        def __set__(self, value):
            if value is not None:
                self.__bladerf_quick_tune[0].nios_profile = <uint16_t> value

    property rffe_profile:
        def __get__(self):
            return self.__bladerf_quick_tune[0].rffe_profile

        def __set__(self, value):
            if value is not None:
                self.__bladerf_quick_tune[0].rffe_profile = <uint8_t> value

    property port:
        def __get__(self):
            return self.__bladerf_quick_tune[0].port

        def __set__(self, value):
            if value is not None:
                self.__bladerf_quick_tune[0].port = <uint8_t> value

    property spdt:
        def __get__(self):
            return self.__bladerf_quick_tune[0].spdt

        def __set__(self, value):
            if value is not None:
                self.__bladerf_quick_tune[0].spdt = <uint8_t> value

    cdef from_bladerf_quick_tune(self, bladerf_quick_tune: cbladerf.bladerf_quick_tune):
        self.__bladerf_quick_tune[0] = bladerf_quick_tune

    cdef cbladerf.bladerf_quick_tune get_obj(self):
        return self.__bladerf_quick_tune[0]

    cdef cbladerf.bladerf_quick_tune* get_ptr(self):
        return self.__bladerf_quick_tune

    cdef cbladerf.bladerf_quick_tune** get_double_ptr(self):
        return &self.__bladerf_quick_tune


cdef class pybladerf_metadata:
    cdef cbladerf.bladerf_metadata* __bladerf_metadata

    def __init__(self,
                 timestamp: int = None,
                 flags: int = None,
                 status: int = None,
                 actual_count: int = None) -> None:

        self.__bladerf_metadata = <cbladerf.bladerf_metadata*> malloc(sizeof(cbladerf.bladerf_metadata))

        self.timestamp = timestamp
        self.flags = flags
        self.status = status
        self.actual_count = actual_count

    def __dealloc__(self):
        if self.__bladerf_metadata != NULL:
            free(self.__bladerf_metadata)

    def __str__(self):
        return f'timestamp:{self.timestamp} flags:{self.flags} status:{self.status} actual_count:{self.actual_count}'

    property timestamp:
        def __get__(self):
            return self.__bladerf_metadata[0].timestamp

        def __set__(self, value):
            if value is not None:
                self.__bladerf_metadata[0].timestamp = <uint64_t> value

    property flags:
        def __get__(self):
            return self.__bladerf_metadata[0].flags

        def __set__(self, value):
            if value is not None:
                self.__bladerf_metadata[0].flags = <uint32_t> value

    property status:
        def __get__(self):
            return self.__bladerf_metadata[0].status

        def __set__(self, value):
            if value is not None:
                self.__bladerf_metadata[0].status = <uint32_t> value

    property actual_count:
        def __get__(self):
            return self.__bladerf_metadata[0].actual_count

        def __set__(self, value):
            if value is not None:
                self.__bladerf_metadata[0].actual_count = <unsigned int> value

    cdef from_bladerf_metadata(self, bladerf_metadata: cbladerf.bladerf_metadata):
        self.__bladerf_metadata[0] = bladerf_metadata

    cdef cbladerf.bladerf_metadata get_obj(self):
        return self.__bladerf_metadata[0]

    cdef cbladerf.bladerf_metadata* get_ptr(self):
        return self.__bladerf_metadata

    cdef cbladerf.bladerf_metadata** get_double_ptr(self):
        return &self.__bladerf_metadata


cdef class pybladerf_rf_switch_config:
    cdef cbladerf.bladerf_rf_switch_config* __bladerf_rf_switch_config

    def __init__(self,
                 tx1_rfic_port: int = None,
                 tx1_spdt_port: int = None,
                 tx2_rfic_port: int = None,
                 tx2_spdt_port: int = None,
                 rx1_rfic_port: int = None,
                 rx1_spdt_port: int = None,
                 rx2_rfic_port: int = None,
                 rx2_spdt_port: int = None) -> None:

        self.__bladerf_rf_switch_config = <cbladerf.bladerf_rf_switch_config*> malloc(sizeof(cbladerf.bladerf_rf_switch_config))

        self.tx1_rfic_port = tx1_rfic_port
        self.tx1_spdt_port = tx1_spdt_port
        self.tx2_rfic_port = tx2_rfic_port
        self.tx2_spdt_port = tx2_spdt_port
        self.rx1_rfic_port = rx1_rfic_port
        self.rx1_spdt_port = rx1_spdt_port
        self.rx2_rfic_port = rx2_rfic_port
        self.rx2_spdt_port = rx2_spdt_port

    def __dealloc__(self):
        if self.__bladerf_rf_switch_config != NULL:
            free(self.__bladerf_rf_switch_config)

    property tx1_rfic_port:
        def __get__(self):
            return self.__bladerf_rf_switch_config[0].tx1_rfic_port

        def __set__(self, value):
            if value is not None:
                self.__bladerf_rf_switch_config[0].tx1_rfic_port = <uint32_t> value

    property tx1_spdt_port:
        def __get__(self):
            return self.__bladerf_rf_switch_config[0].tx1_spdt_port

        def __set__(self, value):
            if value is not None:
                self.__bladerf_rf_switch_config[0].tx1_spdt_port = <uint32_t> value

    property tx2_rfic_port:
        def __get__(self):
            return self.__bladerf_rf_switch_config[0].tx2_rfic_port

        def __set__(self, value):
            if value is not None:
                self.__bladerf_rf_switch_config[0].tx2_rfic_port = <uint32_t> value

    property tx2_spdt_port:
        def __get__(self):
            return self.__bladerf_rf_switch_config[0].tx2_spdt_port

        def __set__(self, value):
            if value is not None:
                self.__bladerf_rf_switch_config[0].tx2_spdt_port = <uint32_t> value

    property rx1_rfic_port:
        def __get__(self):
            return self.__bladerf_rf_switch_config[0].rx1_rfic_port

        def __set__(self, value):
            if value is not None:
                self.__bladerf_rf_switch_config[0].rx1_rfic_port = <uint32_t> value

    property rx1_spdt_port:
        def __get__(self):
            return self.__bladerf_rf_switch_config[0].rx1_spdt_port

        def __set__(self, value):
            if value is not None:
                self.__bladerf_rf_switch_config[0].rx1_spdt_port = <uint32_t> value

    property rx2_rfic_port:
        def __get__(self):
            return self.__bladerf_rf_switch_config[0].rx2_rfic_port

        def __set__(self, value):
            if value is not None:
                self.__bladerf_rf_switch_config[0].rx2_rfic_port = <uint32_t> value

    property rx2_spdt_port:
        def __get__(self):
            return self.__bladerf_rf_switch_config[0].rx2_spdt_port

        def __set__(self, value):
            if value is not None:
                self.__bladerf_rf_switch_config[0].rx2_spdt_port = <uint32_t> value

    cdef from_bladerf_rf_switch_config(self, bladerf_rf_switch_config: cbladerf.bladerf_rf_switch_config):
        self.__bladerf_rf_switch_config[0] = bladerf_rf_switch_config

    cdef cbladerf.bladerf_rf_switch_config get_obj(self):
        return self.__bladerf_rf_switch_config[0]

    cdef cbladerf.bladerf_rf_switch_config* get_ptr(self):
        return self.__bladerf_rf_switch_config

    cdef cbladerf.bladerf_rf_switch_config** get_double_ptr(self):
        return &self.__bladerf_rf_switch_config


# ---- WRAPPER ---- #
cdef class PyBladeRFDeviceList:
    cdef cbladerf.bladerf_devinfo* __bladerf_device_list
    cdef int _device_count

    def __cinit__(self):
        self._device_count = cbladerf.bladerf_get_device_list(&self.__bladerf_device_list)

    def __dealloc__(self):
        if self.__bladerf_device_list != NULL:
            cbladerf.bladerf_free_device_list(self.__bladerf_device_list)

    property device_count:
        def __get__(self):
            if self.__bladerf_device_list != NULL:
                return self._device_count

    property devstrs:
        def __get__(self):
            if self.__bladerf_device_list != NULL:
                return [f'{pybladerf_backend_str(self.__bladerf_device_list[i].backend)}:device={self.__bladerf_device_list[i].usb_bus}:{self.__bladerf_device_list[i].usb_addr} instance={self.__bladerf_device_list[i].instance} serial={self.__bladerf_device_list[i].serial.decode("utf-8")}' for i in range(self._device_count)]

    property backends:
        def __get__(self):
            if self.__bladerf_device_list != NULL:
                return [pybladerf_backend_str(self.__bladerf_device_list[i].backend) for i in range(self._device_count)]

    property serial_numbers:
        def __get__(self):
            if self.__bladerf_device_list != NULL:
                return [self.__bladerf_device_list[i].serial.decode('utf-8') for i in range(self._device_count)]

    property usb_bus:
        def __get__(self):
            if self.__bladerf_device_list != NULL:
                return [self.__bladerf_device_list[i].usb_bus for i in range(self._device_count)]

    property usb_addresses:
        def __get__(self):
            if self.__bladerf_device_list != NULL:
                return [self.__bladerf_device_list[i].usb_addr for i in range(self._device_count)]

    property instances:
        def __get__(self):
            if self.__bladerf_device_list != NULL:
                return [self.__bladerf_device_list[i].instance for i in range(self._device_count)]

    property manufacturers:
        def __get__(self):
            if self.__bladerf_device_list != NULL:
                return [self.__bladerf_device_list[i].manufacturer.decode('utf-8') for i in range(self._device_count)]

    property products:
        def __get__(self):
            if self.__bladerf_device_list != NULL:
                return [self.__bladerf_device_list[i].product.decode('utf-8') for i in range(self._device_count)]


cdef class PyBladerfDevice:
    cdef cbladerf.bladerf* __bladerf_device

    def __cinit__(self):
        self.__bladerf_device = NULL

    def __dealloc__(self):
        if self.__bladerf_device != NULL:
            cbladerf.bladerf_close(self.__bladerf_device)
            self.__bladerf_device = NULL

    # ---- inner functions ---- #
    cdef cbladerf.bladerf* get_bladerf_device_ptr(self):
        return self.__bladerf_device

    cdef cbladerf.bladerf** get_bladerf_device_double_ptr(self):
        return &self.__bladerf_device

    # ---- device ---- #
    def pybladerf_close(self) -> None:
        cbladerf.bladerf_close(self.__bladerf_device)
        self.__bladerf_device = NULL

    def pybladerf_get_devinfo(self) -> pybladerf_devinfo:
        info = pybladerf_devinfo()
        result = cbladerf.bladerf_get_devinfo(self.__bladerf_device, info.get_ptr())
        raise_error('pybladerf_get_devinfo()', result)
        return info

    cdef cbladerf.bladerf_backendinfo pybladerf_get_backendinfo(self):
        cdef cbladerf.bladerf_backendinfo info
        result = cbladerf.bladerf_get_backendinfo(self.__bladerf_device, &info)
        raise_error('pybladerf_get_backendinfo()', result)
        return info

    def pybladerf_get_serial(self) -> str:
        cdef char* serial = <char*>malloc(cbladerf.BLADERF_SERIAL_LENGTH * sizeof(char))
        result = cbladerf.bladerf_get_serial(self.__bladerf_device, serial)
        raise_error('pybladerf_get_serial()', result)
        serial_str = serial.decode("utf-8")
        free(serial)
        return serial_str

    def pybladerf_get_serial_struct(self) -> cbladerf.bladerf_serial:
        cdef cbladerf.bladerf_serial serial
        result = cbladerf.bladerf_get_serial_struct(self.__bladerf_device, &serial)
        raise_error('pybladerf_get_serial_struct()', result)
        return serial

    def pybladerf_get_fpga_size(self) -> pybladerf_fpga_size:
        cdef cbladerf.bladerf_fpga_size size
        result = cbladerf.bladerf_get_fpga_size(self.__bladerf_device, &size)
        raise_error('pybladerf_get_fpga_size()', result)
        return pybladerf_fpga_size(size)

    def pybladerf_get_fpga_bytes(self) -> size_t:
        cdef size_t size
        result = cbladerf.bladerf_get_fpga_bytes(self.__bladerf_device, &size)
        raise_error('pybladerf_get_fpga_bytes()', result)
        return size

    def pybladerf_get_flash_size(self) -> tuple(int, bool):
        cdef uint32_t size
        cdef int is_guess
        result = cbladerf.bladerf_get_flash_size(self.__bladerf_device, &size, &is_guess)
        raise_error('pybladerf_get_flash_size()', result)
        return size, is_guess

    def pybladerf_fw_version(self) -> pybladerf_version:
        version = pybladerf_version()
        result = cbladerf.bladerf_fw_version(self.__bladerf_device, version.get_ptr())
        raise_error('pybladerf_fw_version()', result)
        return version

    def pybladerf_is_fpga_configured(self) -> bool:
        result = cbladerf.bladerf_is_fpga_configured(self.__bladerf_device)
        raise_error('pybladerf_is_fpga_configured()', result)
        return result

    def pybladerf_fpga_version(self) -> pybladerf_version:
        version = pybladerf_version()
        result = cbladerf.bladerf_fpga_version(self.__bladerf_device, version.get_ptr())
        raise_error('pybladerf_fpga_version()', result)
        return version

    def pybladerf_get_fpga_source(self) -> pybladerf_fpga_source:
        cdef cbladerf.bladerf_fpga_source source
        result = cbladerf.bladerf_get_fpga_source(self.__bladerf_device, &source)
        raise_error('pybladerf_get_fpga_source()', result)
        return pybladerf_fpga_source(source)

    def pybladerf_device_speed(self) -> pybladerf_dev_speed:
        return pybladerf_dev_speed(cbladerf.bladerf_device_speed(self.__bladerf_device))

    def pybladerf_get_board_name(self) -> str:
        return cbladerf.bladerf_get_board_name(self.__bladerf_device).decode('utf-8')

    def pybladerf_get_channel_count(self, dir: pybladerf_direction) -> size_t:
        return cbladerf.bladerf_get_channel_count(self.__bladerf_device, dir)

    def pybladerf_set_gain(self, ch: int, gain: int) -> None:
        result = cbladerf.bladerf_set_gain(self.__bladerf_device, ch, gain)
        raise_error('pybladerf_set_gain()', result)

    def pybladerf_get_gain(self, ch: int) -> int:
        cdef int gain
        result = cbladerf.bladerf_get_gain(self.__bladerf_device, ch, &gain)
        raise_error('pybladerf_get_gain()', result)
        return gain

    def pybladerf_set_gain_mode(self, ch: int, mode: pybladerf_gain_mode) -> None:
        result = cbladerf.bladerf_set_gain_mode(self.__bladerf_device, ch, mode)
        raise_error('pybladerf_set_gain_mode()', result)

    def pybladerf_get_gain_mode(self, ch: int) -> pybladerf_gain_mode:
        cdef cbladerf.bladerf_gain_mode mode
        result = cbladerf.bladerf_get_gain_mode(self.__bladerf_device, ch, &mode)
        raise_error('pybladerf_get_gain_mode()', result)
        return pybladerf_gain_mode(mode)

    def pybladerf_get_gain_modes(self, ch: int) -> list[pybladerf_gain_mode]:
        cdef const cbladerf.bladerf_gain_modes* modes_ptr
        result = cbladerf.bladerf_get_gain_modes(self.__bladerf_device, ch, &modes_ptr)
        raise_error('pybladerf_get_gain_modes()', result)
        return [pybladerf_gain_mode(modes_ptr[i].mode) for i in range(result)]

    def pybladerf_get_gain_range(self, ch: int) -> pybladerf_range:
        gain_range = pybladerf_range()
        result = cbladerf.bladerf_get_gain_range(self.__bladerf_device, ch, gain_range.get_double_ptr())
        raise_error('pybladerf_get_gain_range()', result)
        return gain_range

    def pybladerf_set_gain_stage(self, ch: int, stage: str, gain: int) -> None:
        result = cbladerf.bladerf_set_gain_stage(self.__bladerf_device, ch, stage.encode('utf-8'), gain)
        raise_error('pybladerf_set_gain_stage()', result)

    def pybladerf_get_gain_stage(self, ch: int, stage: str) -> int:
        cdef cbladerf.bladerf_gain gain
        result = cbladerf.bladerf_get_gain_stage(self.__bladerf_device, ch, stage.encode('utf-8'), &gain)
        raise_error('pybladerf_get_gain_stage()', result)
        return gain

    def pybladerf_get_gain_stage_range(self, ch: int, stage: str) -> pybladerf_range:
        gain_stage_range = pybladerf_range()
        result = cbladerf.bladerf_get_gain_stage_range(self.__bladerf_device, ch, stage.encode('utf-8'), gain_stage_range.get_double_ptr())
        raise_error('pybladerf_get_gain_stage_range()', result)
        return gain_stage_range

    def pybladerf_get_gain_stages(self, ch: int) -> list[str]:
        cdef char* stages_ptr
        result = cbladerf.bladerf_get_gain_stages(self.__bladerf_device, ch, &stages_ptr, 16)
        raise_error('pybladerf_get_gain_stages()', result)
        return [stages_ptr[i].decode('utf-8') for i in range(result)]

    def pybladerf_set_sample_rate(self, ch: int, rate: int) -> int:
        cdef cbladerf.bladerf_sample_rate actual_sample_rate
        result = cbladerf.bladerf_set_sample_rate(self.__bladerf_device, ch, rate, &actual_sample_rate)
        raise_error('pybladerf_set_sample_rate()', result)
        return actual_sample_rate

    def pybladerf_set_rational_sample_rate(self, ch: int, integer: int, num: int, den: int) -> tuple[int]:
        cdef cbladerf.bladerf_rational_rate rate
        cdef cbladerf.bladerf_rational_rate actual_sample_rate

        rate.integer = <uint64_t> integer
        rate.num = <uint64_t> num
        rate.den = <uint64_t> den

        result = cbladerf.bladerf_set_rational_sample_rate(self.__bladerf_device, ch, &rate, &actual_sample_rate)
        raise_error('pybladerf_set_rational_sample_rate()', result)
        return actual_sample_rate.integer, actual_sample_rate.num, actual_sample_rate.den

    def pybladerf_get_sample_rate(self, ch: int) -> int:
        cdef cbladerf.bladerf_sample_rate rate
        result = cbladerf.bladerf_get_sample_rate(self.__bladerf_device, ch, &rate)
        raise_error('pybladerf_get_sample_rate()', result)
        return rate

    def pybladerf_get_sample_rate_range(self, ch: int) -> pybladerf_range:
        sample_rate_range = pybladerf_range()
        result = cbladerf.bladerf_get_sample_rate_range(self.__bladerf_device, ch, sample_rate_range.get_double_ptr())
        raise_error('pybladerf_get_sample_rate_range()', result)
        return sample_rate_range

    def pybladerf_get_rational_sample_rate(self, ch: int) -> tuple[int]:
        cdef cbladerf.bladerf_rational_rate rate
        result = cbladerf.bladerf_get_rational_sample_rate(self.__bladerf_device, ch, &rate)
        raise_error('pybladerf_get_rational_sample_rate()', result)
        return (rate.integer, rate.num, rate.den)

    def pybladerf_set_bandwidth(self, ch: int, bandwidth: int) -> int:
        cdef cbladerf.bladerf_bandwidth actual_bandwidth
        result = cbladerf.bladerf_set_bandwidth(self.__bladerf_device, ch, <unsigned int> bandwidth, &actual_bandwidth)
        raise_error('pybladerf_set_bandwidth()', result)
        return actual_bandwidth

    def pybladerf_get_bandwidth(self, ch: int) -> int:
        cdef cbladerf.bladerf_bandwidth bandwidth
        result = cbladerf.bladerf_get_bandwidth(self.__bladerf_device, ch, &bandwidth)
        raise_error('pybladerf_get_bandwidth()', result)
        return bandwidth

    def pybladerf_get_bandwidth_range(self, ch: int) -> pybladerf_range:
        bandwidth_range = pybladerf_range()
        result = cbladerf.bladerf_get_bandwidth_range(self.__bladerf_device, ch, bandwidth_range.get_double_ptr())
        raise_error('pybladerf_get_bandwidth_range()', result)
        return bandwidth_range

    def pybladerf_select_band(self, ch: int, frequency: int) -> None:
        result = cbladerf.bladerf_select_band(self.__bladerf_device, ch, <uint64_t> frequency)
        raise_error('pybladerf_select_band()', result)

    def pybladerf_set_frequency(self, ch: int, frequency: int) -> None:
        result = cbladerf.bladerf_set_frequency(self.__bladerf_device, ch, <uint64_t> frequency)
        raise_error('pybladerf_set_frequency()', result)

    def pybladerf_get_frequency(self, ch: int) -> int:
        cdef cbladerf.bladerf_frequency frequency
        result = cbladerf.bladerf_get_frequency(self.__bladerf_device, ch, &frequency)
        raise_error('pybladerf_get_frequency()', result)
        return frequency

    def pybladerf_get_frequency_range(self, ch: int) -> pybladerf_range:
        frequency_range = pybladerf_range()
        result = cbladerf.bladerf_get_frequency_range(self.__bladerf_device, ch, frequency_range.get_double_ptr())
        raise_error('pybladerf_get_frequency_range()', result)
        return frequency_range

    def pybladerf_get_loopback_modes(self) -> list[pybladerf_loopback]:
        cdef cbladerf.bladerf_loopback_modes* modes_ptr
        result = cbladerf.bladerf_get_loopback_modes(self.__bladerf_device, &modes_ptr)
        raise_error('pybladerf_get_loopback_modes()', result)
        return [pybladerf_loopback(modes_ptr[i].mode) for i in range(result)]

    def pybladerf_is_loopback_mode_supported(self, mode: pybladerf_loopback) -> bool:
        return cbladerf.bladerf_is_loopback_mode_supported(self.__bladerf_device, mode)

    def pybladerf_set_loopback(self, lb: pybladerf_loopback) -> None:
        result = cbladerf.bladerf_set_loopback(self.__bladerf_device, lb)
        raise_error('pybladerf_set_loopback()', result)

    def pybladerf_get_loopback(self) -> pybladerf_loopback:
        cdef cbladerf.bladerf_loopback lb
        result = cbladerf.bladerf_get_loopback(self.__bladerf_device, &lb)
        raise_error('pybladerf_get_loopback()', result)
        return pybladerf_loopback(lb)

    def pybladerf_trigger_init(self, ch: int, signal: pybladerf_trigger_signal) -> pybladerf_trigger:
        trigger = pybladerf_trigger()
        result = cbladerf.bladerf_trigger_init(self.__bladerf_device, ch, signal, trigger.get_ptr())
        raise_error('pybladerf_trigger_init()', result)
        return trigger

    def pybladerf_trigger_arm(self, trigger: pybladerf_trigger, arm: bool, resv1: int, resv2: int) -> None:
        result = cbladerf.bladerf_trigger_arm(self.__bladerf_device, trigger.get_ptr(), arm, <uint64_t> resv1, <uint64_t> resv2)
        raise_error('pybladerf_trigger_arm()', result)

    def pybladerf_trigger_fire(self, trigger: pybladerf_trigger) -> None:
        result = cbladerf.bladerf_trigger_fire(self.__bladerf_device, trigger.get_ptr())
        raise_error('pybladerf_trigger_fire()', result)

    def pybladerf_trigger_state(self, trigger: pybladerf_trigger) -> tuple[bool]:
        cdef int is_armed, has_fired, fire_requested
        cdef uint64_t resv1, resv2
        result = cbladerf.bladerf_trigger_state(self.__bladerf_device, trigger.get_ptr(), &is_armed, &has_fired, &fire_requested, &resv1, &resv2)
        raise_error('pybladerf_trigger_state()', result)
        return (is_armed, has_fired, fire_requested)

    def pybladerf_set_rx_mux(self, mux: pybladerf_rx_mux) -> None:
        result = cbladerf.bladerf_set_rx_mux(self.__bladerf_device, mux)
        raise_error('pybladerf_set_rx_mux()', result)

    def pybladerf_get_rx_mux(self) -> pybladerf_rx_mux:
        cdef cbladerf.bladerf_rx_mux mux
        result = cbladerf.bladerf_get_rx_mux(self.__bladerf_device, &mux)
        raise_error('pybladerf_get_rx_mux()', result)
        return pybladerf_rx_mux(mux)

    def pybladerf_schedule_retune(self, ch: int, timestamp: int, frequency: int, quick_tune: pybladerf_quick_tune = None):
        cdef uint64_t c_timestamp
        cdef uint64_t c_frequency
        cdef cbladerf.bladerf_quick_tune* quick_tune_ptr
        cdef int c_ch
        cdef int result

        c_ch = ch
        c_timestamp = <uint64_t> timestamp
        c_frequency = <uint64_t> frequency
        quick_tune_ptr = quick_tune.get_ptr() if quick_tune is not None else NULL

        with nogil:
            result = cbladerf.bladerf_schedule_retune(self.__bladerf_device, c_ch, c_timestamp, c_frequency, quick_tune_ptr)
        raise_error('pybladerf_schedule_retune()', result)

    def pybladerf_cancel_scheduled_retunes(self, ch: int) -> None:
        result = cbladerf.bladerf_cancel_scheduled_retunes(self.__bladerf_device, ch)
        raise_error('pybladerf_cancel_scheduled_retunes()', result)

    def pybladerf_get_quick_tune(self, ch: int) -> pybladerf_quick_tune:
        quick_tune = pybladerf_quick_tune()
        result = cbladerf.bladerf_get_quick_tune(self.__bladerf_device, ch, quick_tune.get_ptr())
        raise_error('pybladerf_get_quick_tune()', result)
        return quick_tune

    def pybladerf_set_correction(self, ch: int, corr: pybladerf_correction, value: int) -> None:
        result = cbladerf.bladerf_set_correction(self.__bladerf_device, ch, corr, <int16_t> value)
        raise_error('pybladerf_set_correction()', result)

    def pybladerf_get_correction(self, ch: int, corr: pybladerf_correction) -> int:
        cdef cbladerf.bladerf_correction_value value
        result = cbladerf.bladerf_get_correction(self.__bladerf_device, ch, corr, &value)
        raise_error('pybladerf_get_correction()', result)
        return value

    def pybladerf_interleave_stream_buffer(self, layout: pybladerf_channel_layout, format: pybladerf_format, buffer_size: int, samples: np.ndarray) -> None:
        result = cbladerf.bladerf_interleave_stream_buffer(layout, format, buffer_size, <void*> <void*> samples.data)
        raise_error('pybladerf_interleave_stream_buffer()', result)

    def pybladerf_deinterleave_stream_buffer(self, layout: pybladerf_channel_layout, format: pybladerf_format, buffer_size: int, samples: np.ndarray) -> None:
        result = cbladerf.bladerf_deinterleave_stream_buffer(layout, format, buffer_size, <void*> samples.data)
        raise_error('pybladerf_deinterleave_stream_buffer()', result)

    def pybladerf_enable_module(self, ch: int, enable: bool) -> None:
        result = cbladerf.bladerf_enable_module(self.__bladerf_device, ch, enable)
        raise_error('pybladerf_enable_module()', result)

    def pybladerf_get_timestamp(self, dir: pybladerf_direction) -> int:
        cdef cbladerf.bladerf_timestamp timestamp
        cdef cbladerf.bladerf_direction c_dir
        cdef int result

        c_dir = dir

        with nogil:
            result = cbladerf.bladerf_get_timestamp(self.__bladerf_device, c_dir, &timestamp)
        raise_error('pybladerf_get_timestamp()', result)
        return timestamp

    def pybladerf_sync_config(self, layout: pybladerf_channel_layout, format: pybladerf_format, num_buffers: int, buffer_size: int, num_transfers: int, stream_timeout: int) -> None:
        result = cbladerf.bladerf_sync_config(self.__bladerf_device, layout, format, num_buffers, buffer_size, num_transfers, stream_timeout)
        raise_error('pybladerf_sync_config()', result)

    def pybladerf_sync_tx(self, samples: np.ndarray, num_samples: int, metadata: pybladerf_metadata = None, timeout_ms: int = 0) -> None:
        cdef void* samples_ptr
        cdef unsigned int c_num_samples
        cdef cbladerf.bladerf_metadata* metadata_ptr
        cdef unsigned int c_timeout_ms
        cdef int result

        samples_ptr = <void*> samples.data
        c_num_samples = <unsigned int> num_samples
        metadata_ptr = metadata.get_ptr() if metadata is not None else NULL
        c_timeout_ms = <unsigned int> timeout_ms

        with nogil:
            result = cbladerf.bladerf_sync_tx(self.__bladerf_device, samples_ptr, c_num_samples, metadata_ptr, c_timeout_ms)

        raise_error('pybladerf_sync_tx()', result)

    def pybladerf_sync_rx(self, samples: np.ndarray, num_samples: int, metadata: pybladerf_metadata = None, timeout_ms: int = 0) -> None:
        cdef void* samples_ptr
        cdef unsigned int c_num_samples
        cdef cbladerf.bladerf_metadata* metadata_ptr
        cdef unsigned int c_timeout_ms
        cdef int result

        samples_ptr = <void*> samples.data
        c_num_samples = <unsigned int> num_samples
        metadata_ptr = metadata.get_ptr() if metadata is not None else NULL
        c_timeout_ms = <unsigned int> timeout_ms

        with nogil:
            result = cbladerf.bladerf_sync_rx(self.__bladerf_device, samples_ptr, c_num_samples, metadata_ptr, c_timeout_ms)
        raise_error('pybladerf_sync_rx()', result)

    def pybladerf_init_stream(self):
        raise NotImplementedError()

    def pybladerf_stream(self):
        raise NotImplementedError()

    def pybladerf_submit_stream_buffer(self):
        raise NotImplementedError()

    def pybladerf_submit_stream_buffer_nb(self):
        raise NotImplementedError()

    def pybladerf_deinit_stream(self):
        raise NotImplementedError()

    def pybladerf_set_stream_timeout(self):
        raise NotImplementedError()

    def pybladerf_get_stream_timeout(self):
        raise NotImplementedError()

    def pybladerf_flash_firmware(self, firmware: str) -> None:
        result = cbladerf.bladerf_flash_firmware(self.__bladerf_device, firmware.encode('utf-8'))
        raise_error('pybladerf_flash_firmware()', result)

    def pybladerf_load_fpga(self, fpga: str) -> None:
        result = cbladerf.bladerf_load_fpga(self.__bladerf_device, fpga.encode('utf-8'))
        raise_error('pybladerf_load_fpga()', result)

    def pybladerf_flash_fpga(self, fpga_image) -> None:
        result = cbladerf.bladerf_flash_fpga(self.__bladerf_device, fpga_image.encode('utf-8'))
        raise_error('pybladerf_flash_fpga()', result)

    def pybladerf_erase_stored_fpga(self) -> None:
        result = cbladerf.bladerf_erase_stored_fpga(self.__bladerf_device)
        raise_error('pybladerf_erase_stored_fpga()', result)

    def pybladerf_device_reset(self) -> None:
        result = cbladerf.bladerf_device_reset(self.__bladerf_device)
        raise_error('pybladerf_device_reset()', result)

    def pybladerf_get_fw_log(self, filename: str = None) -> None:
        cdef char* c_filename = NULL
        if filename is not None:
            filename_bytes = filename.encode('utf-8')
            c_filename = filename_bytes

        result = cbladerf.bladerf_get_fw_log(self.__bladerf_device, c_filename)
        raise_error('pybladerf_get_fw_log()', result)

    def pybladerf_jump_to_bootloader(self) -> None:
        result = cbladerf.bladerf_jump_to_bootloader(self.__bladerf_device)
        raise_error('pybladerf_jump_to_bootloader()', result)

    def pybladerf_alloc_image(self):
        raise NotImplementedError()

    def pybladerf_alloc_cal_image(self):
        raise NotImplementedError()

    def pybladerf_free_image(self):
        raise NotImplementedError()

    def pybladerf_image_write(self):
        raise NotImplementedError()

    def pybladerf_image_read(self):
        raise NotImplementedError()

    def pybladerf_set_vctcxo_tamer_mode(self, mode: pybladerf_vctcxo_tamer_mode) -> None:
        result = cbladerf.bladerf_set_vctcxo_tamer_mode(self.__bladerf_device, mode)
        raise_error('pybladerf_set_vctcxo_tamer_mode()', result)

    def pybladerf_get_vctcxo_tamer_mode(self) -> pybladerf_vctcxo_tamer_mode:
        cdef cbladerf.bladerf_vctcxo_tamer_mode mode
        result = cbladerf.bladerf_get_vctcxo_tamer_mode(self.__bladerf_device, &mode)
        raise_error('pybladerf_get_vctcxo_tamer_mode()', result)
        return pybladerf_vctcxo_tamer_mode(mode)

    def pybladerf_get_vctcxo_trim(self) -> int:
        cdef uint16_t trim
        result = cbladerf.bladerf_get_vctcxo_trim(self.__bladerf_device, &trim)
        raise_error('pybladerf_get_vctcxo_trim()', result)
        return trim

    def pybladerf_trim_dac_write(self, val: int) -> None:
        result = cbladerf.bladerf_trim_dac_write(self.__bladerf_device, val)
        raise_error('pybladerf_trim_dac_write()', result)

    def pybladerf_trim_dac_read(self) -> int:
        cdef uint16_t val
        result = cbladerf.bladerf_trim_dac_read(self.__bladerf_device, &val)
        raise_error('pybladerf_trim_dac_read()', result)
        return val

    def pybladerf_set_tuning_mode(self, mode: pybladerf_tuning_mode) -> None:
        result = cbladerf.bladerf_set_tuning_mode(self.__bladerf_device, mode)
        raise_error('pybladerf_set_tuning_mode()', result)

    def pybladerf_get_tuning_mode(self) -> pybladerf_tuning_mode:
        cdef cbladerf.bladerf_tuning_mode mode
        result = cbladerf.bladerf_get_tuning_mode(self.__bladerf_device, &mode)
        raise_error('pybladerf_get_tuning_mode()', result)
        return pybladerf_tuning_mode(mode)

    def pybladerf_read_trigger(self):
        raise NotImplementedError()

    def pybladerf_write_trigger(self):
        raise NotImplementedError()

    def pybladerf_wishbone_master_read(self):
        raise NotImplementedError()

    def pybladerf_wishbone_master_write(self):
        raise NotImplementedError()

    def pybladerf_config_gpio_read(self):
        raise NotImplementedError()

    def pybladerf_config_gpio_write(self):
        raise NotImplementedError()

    def pybladerf_erase_flash(self):
        raise NotImplementedError()

    def pybladerf_erase_flash_bytes(self):
        raise NotImplementedError()

    def pybladerf_read_flash(self):
        raise NotImplementedError()

    def pybladerf_read_flash_bytes(self):
        raise NotImplementedError()

    def pybladerf_write_flash(self):
        raise NotImplementedError()

    def pybladerf_write_flash_bytes(self):
        raise NotImplementedError()

    def pybladerf_lock_otp(self):
        raise NotImplementedError()

    def pybladerf_read_otp(self):
        raise NotImplementedError()

    def pybladerf_write_otp(self):
        raise NotImplementedError()

    def pybladerf_set_rf_port(self, ch: int, port: str) -> None:
        result = cbladerf.bladerf_set_rf_port(self.__bladerf_device, ch, port.encode('utf-8'))
        raise_error('pybladerf_set_rf_port()', result)

    def pybladerf_get_rf_port(self, ch: int) -> str:
        cdef char** port
        result = cbladerf.bladerf_get_rf_port(self.__bladerf_device, ch, port)
        raise_error('pybladerf_get_rf_port()', result)
        return port[0].decode('utf-8')

    def pybladerf_get_rf_ports(self, ch: int) -> list[str]:
        result = cbladerf.bladerf_get_rf_ports(self.__bladerf_device, ch, NULL, 0)
        raise_error('pybladerf_get_rf_ports()', result)
        cdef char** ports
        result = cbladerf.bladerf_get_rf_ports(self.__bladerf_device, ch, ports, result)
        raise_error('pybladerf_get_rf_ports()', result)
        return [ports[i].decode('utf-8') for i in range(result)]

    def pybladerf_enable_feature(self, feature: pybladerf_feature, enable: bool) -> None:
        result = cbladerf.bladerf_enable_feature(self.__bladerf_device, feature, enable)
        raise_error('pybladerf_enable_feature()', result)

    def pybladerf_get_feature(self) -> pybladerf_feature:
        cdef cbladerf.bladerf_feature feature
        result = cbladerf.bladerf_get_feature(self.__bladerf_device, &feature)
        raise_error('pybladerf_get_feature()', result)
        return pybladerf_feature(feature)

    def pybladerf_expansion_attach(self):
        raise NotImplementedError()

    def pybladerf_expansion_get_attached(self):
        raise NotImplementedError()

    # ---- BLADERF2 ---- #
    def pybladerf_get_bias_tee(self, ch: int) -> bool:
        cdef int enable
        result = cbladerf.bladerf_get_bias_tee(self.__bladerf_device, ch, &enable)
        raise_error('pybladerf_get_bias_tee()', result)
        return enable

    def pybladerf_set_bias_tee(self, ch: int, enable: bool) -> None:
        result = cbladerf.bladerf_set_bias_tee(self.__bladerf_device, ch, enable)
        raise_error('pybladerf_set_bias_tee()', result)

    def pybladerf_get_rfic_register(self, address: int) -> int:
        cdef uint8_t val
        result = cbladerf.bladerf_get_rfic_register(self.__bladerf_device, <uint16_t> address, &val)
        raise_error('pybladerf_get_rfic_register()', result)
        return val

    def pybladerf_set_rfic_register(self, address: int, val: int) -> None:
        result = cbladerf.bladerf_set_rfic_register(self.__bladerf_device, <uint16_t> address, <uint8_t> val)
        raise_error('pybladerf_set_rfic_register()', result)

    def pybladerf_get_rfic_temperature(self) -> float:
        cdef float val
        result = cbladerf.bladerf_get_rfic_temperature(self.__bladerf_device, &val)
        raise_error('pybladerf_get_rfic_temperature()', result)
        return val

    def pybladerf_get_rfic_rssi(self, ch: int) -> tuple[int]:
        cdef int32_t pre_rssi, sym_rssi
        result = cbladerf.bladerf_get_rfic_rssi(self.__bladerf_device, ch, &pre_rssi, &sym_rssi)
        raise_error('pybladerf_get_rfic_rssi()', result)
        return pre_rssi, sym_rssi

    def pybladerf_get_rfic_ctrl_out(self) -> int:
        cdef uint8_t ctrl_out
        result = cbladerf.bladerf_get_rfic_ctrl_out(self.__bladerf_device, &ctrl_out)
        raise_error('pybladerf_get_rfic_ctrl_out()', result)
        return ctrl_out

    def pybladerf_get_rfic_rx_fir(self) -> pybladerf_rfic_rxfir:
        cdef cbladerf.bladerf_rfic_rxfir rxfir
        result = cbladerf.bladerf_get_rfic_rx_fir(self.__bladerf_device, &rxfir)
        raise_error('pybladerf_get_rfic_rx_fir()', result)
        return pybladerf_rfic_rxfir(rxfir)

    def pybladerf_set_rfic_rx_fir(self, rxfir: pybladerf_rfic_rxfir) -> None:
        result = cbladerf.bladerf_set_rfic_rx_fir(self.__bladerf_device, rxfir)
        raise_error('pybladerf_set_rfic_rx_fir()', result)

    def pybladerf_get_rfic_tx_fir(self) -> pybladerf_rfic_txfir:
        cdef cbladerf.bladerf_rfic_txfir txfir
        result = cbladerf.bladerf_get_rfic_tx_fir(self.__bladerf_device, &txfir)
        raise_error('pybladerf_get_rfic_tx_fir()', result)
        return pybladerf_rfic_txfir(txfir)

    def pybladerf_set_rfic_tx_fir(self, txfir: pybladerf_rfic_txfir) -> None:
        result = cbladerf.bladerf_set_rfic_tx_fir(self.__bladerf_device, txfir)
        raise_error('pybladerf_set_rfic_tx_fir()', result)

    def pybladerf_get_pll_lock_state(self) -> bool:
        cdef int locked
        result = cbladerf.bladerf_get_pll_lock_state(self.__bladerf_device, &locked)
        raise_error('pybladerf_get_pll_lock_state()', result)
        return locked

    def pybladerf_get_pll_enable(self) -> bool:
        cdef int enabled
        result = cbladerf.bladerf_get_pll_enable(self.__bladerf_device, &enabled)
        raise_error('pybladerf_get_pll_enable()', result)
        return enabled

    def pybladerf_set_pll_enable(self, enable: bool) -> None:
        result = cbladerf.bladerf_set_pll_enable(self.__bladerf_device, enable)
        raise_error('pybladerf_set_pll_enable()', result)

    def pybladerf_get_pll_refclk_range(self) -> pybladerf_range:
        pll_refclk_range = pybladerf_range()
        result = cbladerf.bladerf_get_pll_refclk_range(self.__bladerf_device, pll_refclk_range.get_double_ptr())
        raise_error('pybladerf_get_pll_refclk_range()', result)
        return pll_refclk_range

    def pybladerf_get_pll_refclk(self) -> int:
        cdef uint64_t frequency
        result = cbladerf.bladerf_get_pll_refclk(self.__bladerf_device, &frequency)
        raise_error('pybladerf_get_pll_refclk()', result)
        return frequency

    def pybladerf_set_pll_refclk(self, frequency: int) -> None:
        result = cbladerf.bladerf_set_pll_refclk(self.__bladerf_device, <uint64_t> frequency)
        raise_error('pybladerf_set_pll_refclk()', result)

    def pybladerf_get_pll_register(self, address: int) -> int:
        cdef uint32_t val
        result = cbladerf.bladerf_get_pll_register(self.__bladerf_device, <uint8_t> address, &val)
        raise_error('pybladerf_get_pll_register()', result)
        return val

    def pybladerf_set_pll_register(self, address: int, val: int) -> None:
        result = cbladerf.bladerf_set_pll_register(self.__bladerf_device, <uint8_t> address, <uint32_t> val)
        raise_error('pybladerf_set_pll_register()', result)

    def pybladerf_get_power_source(self) -> pybladerf_power_sources:
        cdef cbladerf.bladerf_power_sources val
        result = cbladerf.bladerf_get_power_source(self.__bladerf_device, &val)
        raise_error('pybladerf_get_power_source()', result)
        return pybladerf_power_sources(val)

    def pybladerf_get_clock_select(self) -> pybladerf_clock_select:
        cdef cbladerf.bladerf_clock_select sel
        result = cbladerf.bladerf_get_clock_select(self.__bladerf_device, &sel)
        raise_error('pybladerf_get_clock_select()', result)
        return pybladerf_clock_select(sel)

    def pybladerf_set_clock_select(self, sel: pybladerf_clock_select) -> None:
        result = cbladerf.bladerf_set_clock_select(self.__bladerf_device, sel)
        raise_error('pybladerf_set_clock_select()', result)

    def pybladerf_get_clock_output(self) -> bool:
        cdef int state
        result = cbladerf.bladerf_get_clock_output(self.__bladerf_device, &state)
        raise_error('pybladerf_get_clock_output()', result)
        return state

    def pybladerf_set_clock_output(self, enable: bool) -> None:
        result = cbladerf.bladerf_set_clock_output(self.__bladerf_device, enable)
        raise_error('pybladerf_set_clock_output()', result)

    def pybladerf_get_pmic_register(self, reg: pybladerf_pmic_register) -> int | float:
        cdef uint16_t i_val
        cdef float f_val
        if reg in (pybladerf_pmic_register.PYBLADERF_PMIC_CONFIGURATION, pybladerf_pmic_register.PYBLADERF_PMIC_CALIBRATION):
            result = cbladerf.bladerf_get_pmic_register(self.__bladerf_device, reg, &i_val)
            raise_error('pybladerf_get_pmic_register()', result)
            return i_val
        else:
            result = cbladerf.bladerf_get_pmic_register(self.__bladerf_device, reg, &f_val)
            raise_error('pybladerf_get_pmic_register()', result)
            return f_val

    def pybladerf_get_rf_switch_config(self) -> pybladerf_rf_switch_config:
        config = pybladerf_rf_switch_config()
        result = cbladerf.bladerf_get_rf_switch_config(self.__bladerf_device, config.get_ptr())
        raise_error('pybladerf_get_rf_switch_config()', result)
        return config


def pybladerf_open(device_identifier: str = ''):
    pybladerf_device = PyBladerfDevice()
    result = cbladerf.bladerf_open(pybladerf_device.get_bladerf_device_double_ptr(), device_identifier.encode('utf-8'))
    raise_error('pybladerf_open()', result)
    return pybladerf_device


def pybladerf_open_with_devinfo(devinfo: pybladerf_devinfo):
    pybladerf_device = PyBladerfDevice()
    result = cbladerf.bladerf_open_with_devinfo(pybladerf_device.get_bladerf_device_double_ptr(), devinfo.get_ptr())
    raise_error('pybladerf_open_with_devinfo()', result)
    return pybladerf_device


def pybladerf_get_devinfo_from_str(devstr: str) -> pybladerf_devinfo:
    info = pybladerf_devinfo()
    result = cbladerf.bladerf_get_devinfo_from_str(devstr.encode('utf-8'), info.get_ptr())
    raise_error('pybladerf_get_devinfo_from_str()', result)
    return info


def pybladerf_devinfo_matches(a: pybladerf_devinfo, b: pybladerf_devinfo) -> bool:
    return cbladerf.bladerf_devinfo_matches(a.get_ptr(), b.get_ptr())


def pybladerf_devstr_matches(dev_str: str, info: pybladerf_devinfo) -> bool:
    return cbladerf.bladerf_devstr_matches(dev_str.encode('utf-8'), info.get_ptr())


def pybladerf_backend_str(backend: cbladerf.bladerf_backend) -> str:
    return cbladerf.bladerf_backend_str(backend).decode('utf-8')


def pybladerf_set_usb_reset_on_open(enabled: bool) -> None:
    cbladerf.bladerf_set_usb_reset_on_open(enabled)


def pybladerf_get_bootloader_list() -> list[pybladerf_devinfo]:
    cdef cbladerf.bladerf_devinfo ** devices
    result = cbladerf.bladerf_get_bootloader_list(devices)
    raise_error('pybladerf_get_bootloader_list()', result)

    bootloader_list = []
    for i in range(result):
        devinfo = pybladerf_devinfo()
        devinfo.from_bladerf_devinfo(devices[0][i])
        bootloader_list.append(devinfo)

    return bootloader_list


def pybladerf_load_fw_from_bootloader(device_identifier: str, backend: pybladerf_backend, bus: int, addr: int, file: str):
    result = cbladerf.bladerf_load_fw_from_bootloader(device_identifier.encode('utf-8'), backend, <uint8_t> bus, <uint8_t> addr, file.encode('utf-8'))
    raise_error('pybladerf_load_fw_from_bootloader()', result)


def pybladerf_log_set_verbosity(level: pybladerf_log_level) -> None:
    cbladerf.bladerf_log_set_verbosity(level)


def pybladerf_library_version() -> pybladerf_version:
    version = pybladerf_version()
    cbladerf.bladerf_library_version(version.get_ptr())
    return version


def python_bladerf_library_version() -> pybladerf_version:
    major, minor, patch = __version__.split('.')
    version = pybladerf_version(
        int(major),
        int(minor),
        int(patch),
        ''
    )
    return version
