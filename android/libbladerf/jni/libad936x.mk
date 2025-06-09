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

# LIBAD936X
include $(CLEAR_VARS)
LIBAD936X_ROOT_ABS := $(GLOBAL_LOCAL_PATH)/../..

LOCAL_SRC_FILES := \
	${LIBAD936X_ROOT_ABS}/host/common/thirdparty/ad9361/sw/ad9361.c \
	${LIBAD936X_ROOT_ABS}/host/common/thirdparty/ad9361/sw/ad9361_api.c \
	${LIBAD936X_ROOT_ABS}/host/common/thirdparty/ad9361/sw/ad9361_conv.c \
	${LIBAD936X_ROOT_ABS}/host/common/thirdparty/ad9361/sw/util.c \
	${LIBAD936X_ROOT_ABS}/thirdparty/analogdevicesinc/no-OS_local/platform_bladerf2/platform.c \
	${LIBAD936X_ROOT_ABS}/thirdparty/analogdevicesinc/no-OS_local/platform_bladerf2/adc_core.c \
	${LIBAD936X_ROOT_ABS}/thirdparty/analogdevicesinc/no-OS_local/platform_bladerf2/dac_core.c \
	${LIBAD936X_ROOT_ABS}/fpga_common/src/ad936x_params.c

LOCAL_EXPORT_C_INCLUDES := \
	$(LIBAD936X_ROOT_ABS)/host/common/thirdparty/ad9361/sw/ \
	${LIBAD936X_ROOT_ABS}/thirdparty/no-OS_local/platform_bladerf2/ \
	${LIBAD936X_ROOT_ABS}/fpga_common/src/ \
	${LIBAD936X_ROOT_ABS}/firmware_common/ \
	${LIBAD936X_ROOT_ABS}/host/common/include/ \
    ${LIBAD936X_ROOT_ABS}host/build/common/thirdparty/ad936x/ \
	${LIBAD936X_ROOT_ABS}/thirdparty/analogdevicesinc/no-OS_local/platform_bladerf2/

LOCAL_CFLAGS := \
	-I${LIBAD936X_ROOT_ABS}/thirdparty/analogdevicesinc/no-OS_local/platform_bladerf2 \
	-I${LIBAD936X_ROOT_ABS}/host/common/thirdparty/ad9361/sw \
	-I$(LIBAD936X_ROOT_ABS)/host/libraries/libbladeRF/src \
	-I$(LIBAD936X_ROOT_ABS)/host/libraries/libbladeRF/include \
	-I$(LIBAD936X_ROOT_ABS)/host/common/include \
	-I$(LIBAD936X_ROOT_ABS)/fpga_common/include \
	-I${LIBAD936X_ROOT_ABS}/firmware_common/ \
	-DNUAND_MODIFICATIONS

LOCAL_LDFLAGS := -pthread

LOCAL_LDLIBS := -L$(GLOBAL_LOCAL_PATH) -llog

LOCAL_MODULE := libad936x

include $(BUILD_STATIC_LIBRARY)
