def stop_all() -> None:
    ...

def stop_sdr(serialno: str) -> None:
    ...

def pybladerf_transfer(frequency: int | None = None, sample_rate: int = 10_000_000, baseband_filter_bandwidth: int | None = None,
                       gain: int = 0, channel: int = 0, oversample: bool = False, antenna_enable: bool = False,
                       repeat_tx: bool = False, synchronize: bool = False, num_samples: int | None = None, serial_number: str | None = None,
                       rx_filename: str | None = None, tx_filename: str | None = None, rx_buffer: object | None = None, tx_buffer: object | None = None,
                       print_to_console: bool = True) -> None:
    ...
