def stop_all() -> None:
    ...

def stop_sdr(serialno: str) -> None:
    ...

def pybladerf_scan(frequencies: list[int], samples_per_scan: int, queue: object, sample_rate: int = 61_000_000, baseband_filter_bandwidth: int | None = None,
                   gain: int = 20, channel: int = 0, oversample: bool = False, antenna_enable: bool = False, serial_number: str | None = None,
                   print_to_console: bool = True) -> None:
    ...
