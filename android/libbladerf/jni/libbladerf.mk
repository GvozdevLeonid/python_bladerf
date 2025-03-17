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

# LIBBLADERF
include $(CLEAR_VARS)
LIBBLADERF_ROOT_ABS := $(GLOBAL_LOCAL_PATH)/../..

LOCAL_SRC_FILES := \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/bladerf.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/backend/backend.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/driver/spi_flash.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/driver/fx3_fw.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/driver/fpga_trigger.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/driver/si5338.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/driver/ina219.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/driver/dac161s055.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/driver/smb_clock.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/board.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/expansion/xb100.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/expansion/xb200.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/expansion/xb300.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/streaming/async.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/streaming/sync.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/streaming/sync_worker.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/init_fini.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/helpers/timeout.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/helpers/file.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/helpers/version.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/helpers/wallclock.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/helpers/interleave.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/helpers/configfile.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/devinfo.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/device_calibration.c \
	\
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/backend/usb/nios_access.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/backend/usb/nios_legacy_access.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/backend/usb/usb.c \
	\
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/backend/usb/libusb.c \
	\
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf1/bladerf1.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf1/capabilities.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf1/compatibility.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf1/calibration.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf1/flash.c \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf1/image.c \
	\
    $(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf2/bladerf2.c \
    $(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf2/capabilities.c \
    $(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf2/common.c \
    $(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf2/compatibility.c \
    $(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf2/rfic_fpga.c \
    $(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf2/rfic_host.c \
	\
	${LIBBLADERF_ROOT_ABS}/host/common/src/sha256.c \
	${LIBBLADERF_ROOT_ABS}/host/common/src/conversions.c \
	${LIBBLADERF_ROOT_ABS}/host/common/src/log.c \
	${LIBBLADERF_ROOT_ABS}/host/common/src/parse.c \
	${LIBBLADERF_ROOT_ABS}/host/common/src/range.c \
	\
	${LIBBLADERF_ROOT_ABS}/fpga_common/src/ad936x_helpers.c \
	${LIBBLADERF_ROOT_ABS}/fpga_common/src/band_select.c \
	${LIBBLADERF_ROOT_ABS}/fpga_common/src/bladerf2_common.c \
	${LIBBLADERF_ROOT_ABS}/fpga_common/src/lms.c

LOCAL_EXPORT_C_INCLUDES := \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/version.h \
	$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/ \
	${LIBBLADERF_ROOT_ABS}/host/common/src/ \
	${LIBBLADERF_ROOT_ABS}/fpga_common/src/ \
	$(LIBBLADERF_ROOT_ABS)/firmware_common/

LOCAL_CFLAGS := \
	-I$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/include \
	-I$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src \
	-I$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf1 \
	-I$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board/bladerf2 \
	-I$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/backend \
	-I$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/driver \
	-I$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/board \
	-I$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/expansion \
	-I$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/streaming \
	-I$(LIBBLADERF_ROOT_ABS)/host/libraries/libbladeRF/src/helpers \
	-I$(LIBBLADERF_ROOT_ABS)/host/common/include \
	-I$(LIBBLADERF_ROOT_ABS)/fpga_common/include \
	-I$(LIBBLADERF_ROOT_ABS)/firmware_common \
	-I$(LIBBLADERF_ROOT_ABS)/android/libusb \
	-DLIBBLADERF_SEARCH_PREFIX="" \
	-DLOGGING_ENABLED

LOCAL_LDFLAGS := -pthread

LOCAL_LDLIBS := -L$(GLOBAL_LOCAL_PATH) -lusb1.0 -llog

LOCAL_MODULE := libbladeRF

LOCAL_STATIC_LIBRARIES := libad936x

include $(BUILD_SHARED_LIBRARY)
