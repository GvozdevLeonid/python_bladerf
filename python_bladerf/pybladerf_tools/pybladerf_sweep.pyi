from python_bladerf import pybladerf

run_available: dict[str, bool] = ...
'''run_available[device.serialno] = True | False'''

def pybladerf_sweep(frequencies: list[int] | None = None, sample_rate: int = 61_000_000, baseband_filter_bandwidth: int | None = None,
                    gain: int = 20, bin_width: int = 100_000, channel: int = 0, oversample: bool = False, antenna_enable: bool = False,
                    sweep_style: pybladerf.pybladerf_sweep_style = pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED, serial_number: str | None = None,
                    binary_output: bool = False, one_shot: bool = False, num_sweeps: int | None = None,
                    filename: str | None = None, queue: object | None = None,
                    print_to_console: bool = True,
                    ) -> None:
    ...
