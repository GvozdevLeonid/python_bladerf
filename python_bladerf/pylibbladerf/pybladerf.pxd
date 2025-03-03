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
from . cimport cbladerf

cdef struct pybladerf_async_data:
    void* pystream

    int bytes_per_sample

    int package_size
    int packages_per_buffer
    int samples_per_package

    bint tx_complete

# ---- STRUCT ---- #
cdef class pybladerf_devinfo:
    cdef cbladerf.bladerf_devinfo *__bladerf_devinfo

    cdef cbladerf.bladerf_devinfo *get_ptr(self)

    cdef cbladerf.bladerf_devinfo **get_double_ptr(self)

cdef class pybladerf_version:
    cdef cbladerf.bladerf_version *__bladerf_version

    cdef cbladerf.bladerf_version *get_ptr(self)

    cdef cbladerf.bladerf_version **get_double_ptr(self)

cdef class pybladerf_trigger:
    cdef cbladerf.bladerf_trigger *__bladerf_trigger

    cdef cbladerf.bladerf_trigger *get_ptr(self)

    cdef cbladerf.bladerf_trigger **get_double_ptr(self)

cdef class pybladerf_quick_tune:
    cdef cbladerf.bladerf_quick_tune *__bladerf_quick_tune

    cdef cbladerf.bladerf_quick_tune *get_ptr(self)

    cdef cbladerf.bladerf_quick_tune **get_double_ptr(self)

cdef class pybladerf_metadata:
    cdef cbladerf.bladerf_metadata *__bladerf_metadata

    cdef cbladerf.bladerf_metadata *get_ptr(self)

    cdef cbladerf.bladerf_metadata **get_double_ptr(self)

cdef class pybladerf_rf_switch_config:
    cdef cbladerf.bladerf_rf_switch_config *__bladerf_rf_switch_config

    cdef cbladerf.bladerf_rf_switch_config *get_ptr(self)

    cdef cbladerf.bladerf_rf_switch_config **get_double_ptr(self)

# ---- READONLY STRUCT ---- #
cdef class pybladerf_range:
    cdef cbladerf.bladerf_range *__bladerf_range

    cdef cbladerf.bladerf_range *get_ptr(self)

    cdef cbladerf.bladerf_range **get_double_ptr(self)

cdef class pybladerf_stream:
    cdef cbladerf.bladerf_stream *__bladerf_stream
    cdef int idx

    cdef pybladerf_async_data get_async_data(self)

    cdef void *get_next_buffer_ptr(self)

    cdef cbladerf.bladerf_stream *get_ptr(self)

    cdef cbladerf.bladerf_stream **get_double_ptr(self)

# ---- WRAPPER ---- #
cdef class PyBladerfDevice:
    cdef cbladerf.bladerf *__bladerf_device
    cdef public str serialno

    cdef cbladerf.bladerf *get_ptr(self)

    cdef cbladerf.bladerf **get_double_ptr(self)

    cdef cbladerf.bladerf_backendinfo pybladerf_get_backendinfo(self)

    cdef void _setup_device(self)
