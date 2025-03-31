import argparse
import sys

from .pybladerf_tools import (
    pybladerf_info,
    pybladerf_sweep,
    pybladerf_transfer,
)
from .pylibbladerf import pybladerf


def main() -> None:

    parser = argparse.ArgumentParser(
        description='python_bladerf is a Python wrapper for libbladerf. It also contains some additional tools.',
        usage='python_bladerf [-h] {info, sweep} ...',
    )
    subparsers = parser.add_subparsers(dest='command', title='Available commands')
    subparsers.required = True
    pybladerf_info_parser = subparsers.add_parser(
        'info', help='Read device information from Bladerf such as serial number and FPGA version.', usage="python_bladerf info [-h] [-f] [-s]",
    )
    pybladerf_info_parser.add_argument('-f', '--full', action='store_true', help='show full info')
    pybladerf_info_parser.add_argument('-s', '--serial_numbers', action='store_true', help='show only founded serial_numbers')

    pybladerf_sweep_parser = subparsers.add_parser(
        'sweep', help='a command-line spectrum analyzer.', usage='python_bladerf sweep [-h] [-d] [-f] [-g] [-w] [-c] [-1] [-N] [-o] [-p] [-B] [-S] [-s] [-b] [-r]',
    )

    pybladerf_sweep_parser.add_argument('-d', action='store', help='serial number of desired BladeRF', metavar='', default='')
    pybladerf_sweep_parser.add_argument('-f', action='store', help='freq_min:freq_max. minimum and maximum frequencies in MHz start:stop or start1:stop1,start2:stop2', metavar='', default='70:6000')
    pybladerf_sweep_parser.add_argument('-g', action='store', help='RX gain, -15 - 60dB, 1dB steps', metavar='', default=20)
    pybladerf_sweep_parser.add_argument('-w', action='store', help='FFT bin width (frequency resolution) in Hz', metavar='', default=1000000)
    pybladerf_sweep_parser.add_argument('-c', action='store', help='RX channel. which channel to use (0, 1). Default is 0', metavar='', default=0)
    pybladerf_sweep_parser.add_argument('-1', action='store_true', help='one shot mode. If specified = Enable')
    pybladerf_sweep_parser.add_argument('-N', action='store', help='Number of sweeps to perform', metavar='')
    pybladerf_sweep_parser.add_argument('-o', action='store_true', help='oversample. If specified = Enable')
    pybladerf_sweep_parser.add_argument('-p', action='store_true', help='antenna port power. If specified = Enable')
    pybladerf_sweep_parser.add_argument('-B', action='store_true', help='binary output. If specified = Enable')
    pybladerf_sweep_parser.add_argument('-S', action='store', help='sweep style ("L" - LINEAR, "I" - INTERLEAVED). Default is INTERLEAVED', metavar='', default='I')
    pybladerf_sweep_parser.add_argument('-s', action='store', help='sample rate in MHz  (0.5 MHz - 122 MHz). Default is 61. To use a sample rate higher than 61, specify oversample', metavar='', default=61)
    pybladerf_sweep_parser.add_argument('-b', action='store', help='baseband filter bandwidth in MHz (0.2 MHz - 56 MHz). Default .75 * sample rate', metavar='')
    pybladerf_sweep_parser.add_argument('-r', action='store', help='<filename> output file', metavar='')

    pybladerf_transfer_parser = subparsers.add_parser(
        'transfer', help='Send and receive signals using BladeRF. Input/output files consist of complex64 quadrature samples.', usage='python_bladerf transfer [-h] [-d] [-r] [-t] [-f] [-p] [-c] [-g] [-N] [-R] [-s] -[b] [-H] -[o]',
    )
    pybladerf_transfer_parser.add_argument('-d', action='store', help='serial number of desired BladeRF', metavar='')
    pybladerf_transfer_parser.add_argument('-r', action='store', help='<filename> receive data into file (use "-" for stdout)', metavar='')
    pybladerf_transfer_parser.add_argument('-t', action='store', help='<filename> transmit data from file (use "-" for stdin)', metavar='')
    pybladerf_transfer_parser.add_argument('-f', '--freq_hz', action='store', help='frequency in Hz (0MHz to 6000MHz supported). Default is 900MHz', metavar='', default=900_000_000)
    pybladerf_transfer_parser.add_argument('-p', action='store_true', help='antenna port power. If specified = Enable')
    pybladerf_transfer_parser.add_argument('-c', action='store', help='RX or TX channel. which channel to use (0, 1). Default is 0', metavar='', default=0)
    pybladerf_transfer_parser.add_argument('-g', action='store', help='RX or TX gain, RX: -15 - 60dB, 1dB steps, TX: -24 - 66 dB, 1dB steps', metavar='', default=20)
    pybladerf_transfer_parser.add_argument('-N', action='store', help='number of samples to transfer (default is unlimited)', metavar='')
    pybladerf_transfer_parser.add_argument('-R', action='store_true', help='repeat TX mode. Fefault is off')
    pybladerf_transfer_parser.add_argument('-s', action='store', help='sample rate in MHz  (0.5 MHz - 122 MHz). Default is 61. To use a sample rate higher than 61, specify oversample', metavar='', default=61)
    pybladerf_transfer_parser.add_argument('-b', action='store', help='baseband filter bandwidth in MHz (0.2 MHz - 56 MHz). Default .75 * sample rate', metavar='')
    pybladerf_transfer_parser.add_argument('-H', action='store_true', help='synchronize RX/TX to external trigger input')
    pybladerf_transfer_parser.add_argument('-o', action='store_true', help='oversample. If specified = Enable')


    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)

    args, _ = parser.parse_known_args()
    if args.command == 'info':
        if args.serial_numbers:
            pybladerf_info.pybladerf_serial_numbers_list_info()
        else:
            pybladerf_info.pybladerf_info()

    elif args.command == 'sweep':
        str_frequencies = args.f.split(',')
        frequencies = []
        for frequency_range in str_frequencies:
            try:
                freq_min, freq_max = map(int, frequency_range.split(':'))
                frequencies.extend([freq_min, freq_max])
            except Exception:
                pass

        pybladerf_sweep.pybladerf_sweep(frequencies=frequencies,
                                        sample_rate=float(args.s) * 1e6,
                                        baseband_filter_bandwidth=float(args.b) * 1e6 if args.b is not None else None,
                                        gain=int(args.g),
                                        bin_width=int(args.w),
                                        channel=int(args.c),
                                        oversample=args.o,
                                        antenna_enable=args.p,
                                        sweep_style=pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_LINEAR if args.s == 'L' else (pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED if args.s == 'I' else -1),
                                        serial_number=args.d,
                                        binary_output=args.B,
                                        one_shot=args.__dict__.get('1'),
                                        num_sweeps=int(args.N) if args.N is not None else None,
                                        filename=args.r,
                                        print_to_console=True)

    elif args.command == 'transfer':
        pybladerf_transfer.pybladerf_transfer(
            frequency=int(args.freq_hz),
            sample_rate=int(args.s) * 1e6,
            baseband_filter_bandwidth=float(args.b) * 1e6 if args.b is not None else None,
            gain=int(args.g),
            channel=int(args.c),
            oversample=args.o,
            antenna_enable=args.p,
            repeat_tx=args.R,
            synchronize=args.H,
            num_samples=int(args.N) if args.N is not None else None,
            serial_number=args.d,
            rx_filename=args.r,
            tx_filename=args.t,
            print_to_console=True,
        )


if __name__ == '__main__':
    main()
