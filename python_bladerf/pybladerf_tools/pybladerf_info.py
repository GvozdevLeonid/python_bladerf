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

from python_bladerf import pybladerf


def pybladerf_info(print_to_console: bool = True) -> str | None:

    print_info = ''
    device_list = pybladerf.PyBladeRFDeviceList()
    print_info += f'python_bladerf version: {pybladerf.python_bladerf_library_version()}\n'
    print_info += f'libbladeRF version: {pybladerf.pybladerf_library_version()}\n'
    if device_list.device_count > 0:
        for i in range(device_list.device_count):
            device = pybladerf.pybladerf_open_by_serial(device_list.serial_numbers[i])
            print_info += 'Found BladeRF:\n'
            print_info += f'Board: {device.pybladerf_get_board_name()} ({device.pybladerf_get_fpga_size()})\n'
            print_info += f'Instance: {device_list.instances[i]}\n'
            print_info += f'Serial number: {device_list.serial_numbers[i]}\n'
            print_info += f'USB Bus Address: {device_list.usb_buses[i]} {device_list.usb_addresses[i]}\n'
            print_info += f'Backend: {device_list.backends[i]}\n'
            print_info += f'USB Speed: {device.pybladerf_device_speed()}\n'
            print_info += f'FPGA Version: {device.pybladerf_fpga_version()}\n'
            print_info += f'VCTCXO DAC calibration: {hex(device.pybladerf_get_vctcxo_trim())}\n'

            device.pybladerf_close()
    else:
        print_info += 'No BladeRF boards found.'

    if print_to_console:
        print(print_info)
        return None

    return print_info


def pybladerf_serial_numbers_list_info(print_to_console: bool = True) -> tuple[int, list] | None:
    device_list = pybladerf.PyBladeRFDeviceList()

    if print_to_console:
        print(f'Serial numbers [{device_list.device_count}]: {device_list.serial_numbers}')
        return None

    return device_list.device_count, device_list.serial_numbers
