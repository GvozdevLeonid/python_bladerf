# MIT License

# Copyright (c) 2023-2025 GvozdevLeonid

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


from threading import Event
from typing import Any

try:
    from jnius import (  # type: ignore
        autoclass,
        cast,
    )
except ImportError:
    def autoclass(item: Any) -> None:
        raise RuntimeError('autoclass not available')

    def cast(item: Any) -> None:
        raise RuntimeError('cast not available')

try:
    from android.broadcast import BroadcastReceiver  # type: ignore
    from android.runnable import run_on_ui_thread  # type: ignore
except ImportError:
    def BroadcastReceiver(item: Any) -> None:  # noqa N802
        raise RuntimeError('BroadcastReceiver not available')

    def run_on_ui_thread(f: Any) -> None:
        raise RuntimeError('run_on_ui_thread not available')


class USBBroadcastReceiver:
    def __init__(self, events: dict[Any, Any]) -> None:
        self.events = events

    @run_on_ui_thread  # type: ignore
    def start(self) -> None:
        self.br = BroadcastReceiver(self.on_broadcast, actions=['libusb.android.USB_PERMISSION'])
        self.br.start()

    def stop(self) -> None:
        self.br.stop()

    def on_broadcast(self, context: Any, intent: Any) -> None:
        action = intent.getAction()
        usb_manager = autoclass('android.hardware.usb.UsbManager')
        if action == 'libusb.android.USB_PERMISSION':
            usb_device = cast('android.hardware.usb.UsbDevice', intent.getParcelableExtra(usb_manager.EXTRA_DEVICE))

            if usb_device is not None:
                granted = intent.getBooleanExtra(usb_manager.EXTRA_PERMISSION_GRANTED, False)
                device_name = usb_device.getDeviceName()

                if device_name in self.events:
                    self.events[device_name]['granted'] = granted
                    self.events[device_name]['device'] = usb_device
                    self.events[device_name]['event'].set()


bladerf_usb_vids = (0x2cf0, 0x1d50)
bladerf_usb_pids = (0x5246, 0x5250, 0x6066)


def get_bladerf_device_list(num_devices: int | None = None) -> list[tuple[int, str, str, str]]:
    events: dict[Any, Any] = {}
    bladerf_device_list = []
    usb_broadcast_receiver = USBBroadcastReceiver(events)

    this = autoclass('org.kivy.android.PythonActivity').mActivity

    usb_manager = this.getSystemService(autoclass('android.content.Context').USB_SERVICE)
    device_list = usb_manager.getDeviceList()

    permission_intent = autoclass('android.app.PendingIntent').getBroadcast(
        this.getApplicationContext(),
        0,
        autoclass('android.content.Intent')('libusb.android.USB_PERMISSION'),
        autoclass('android.app.PendingIntent').FLAG_MUTABLE,
    )

    if device_list:
        for idx, usb_device in enumerate(device_list.values()):
            device_name = usb_device.getDeviceName()
            if (
                usb_device.getVendorId() in bladerf_usb_vids
                and usb_device.getProductId() in bladerf_usb_pids
            ):

                if usb_manager.hasPermission(usb_device):
                    usb_device_connection = usb_manager.openDevice(usb_device)
                    file_descriptor = usb_device_connection.getFileDescriptor()
                    bladerf_device_list.append((file_descriptor, usb_device.getSerialNumber(), usb_device.getManufacturerName(), usb_device.getProductName()))
                else:
                    events[device_name] = {'event': Event(), 'granted': False, 'device': None}
                    usb_manager.requestPermission(usb_device, permission_intent)

                if num_devices is not None and idx + 1 == num_devices:
                    break

        if events:
            usb_broadcast_receiver.start()
            for _, info in events.items():
                info['event'].wait()
            usb_broadcast_receiver.stop()

            for _, info in events.items():
                if info['granted']:
                    usb_device = info['device']
                    usb_device_connection = usb_manager.openDevice(usb_device)
                    file_descriptor = usb_device_connection.getFileDescriptor()
                    bladerf_device_list.append((file_descriptor, usb_device.getSerialNumber(), usb_device.getManufacturerName(), usb_device.getProductName()))

    return bladerf_device_list
