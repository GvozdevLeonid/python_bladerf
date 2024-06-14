from .pybladerf_tools import (
    pybladerf_sweep,
    pybladerf_info,
)
from .pylibbladerf import pybladerf
import argparse
import sys


def main():
    parser = argparse.ArgumentParser(
        description="python_bladerf is a Python wrapper for libbladerf. It also contains some additional tools.",
        usage="python_bladerf [-h] {info, sweep} ..."
    )
    subparsers = parser.add_subparsers(dest="command", title="Available commands")
    subparsers.required = True
    pybladerf_info_parser = subparsers.add_parser(
        'info', help='Read device information from Bladerf such as serial number and FPGA version.', usage="python_bladerf info [-h] [-f] [-s]"
    )
    pybladerf_info_parser.add_argument('-f', '--full', action='store_true', help='show full info')
    pybladerf_info_parser.add_argument('-i', '--device_identifiers', action='store_true', help='show only founded device_identifiers')

    pybladerf_sweep_parser = subparsers.add_parser(
        'sweep', help='a command-line spectrum analyzer.', usage='python_bladerf sweep [-h] [-d] [-f] [-g] [-w] [-ch] [-1] [-N] [-o] [-B] [-s] [-SR] [-BW] -[FIR] [-r]'
    )
    pybladerf_sweep_parser.add_argument('-d', action='store', help='device_identifier. device identifier of desired BladeRF', metavar='', default='')
    pybladerf_sweep_parser.add_argument('-f', action='store', help='freq_min:freq_max. minimum and maximum frequencies in MHz start:stop. Default is 71:5999', metavar='', default='71:5999')
    pybladerf_sweep_parser.add_argument('-g', action='store', help='gain_db. RX gain, -15 - 60dB, 1dB steps', metavar='', default=20)
    pybladerf_sweep_parser.add_argument('-w', action='store', help='bin_width. FFT bin width (frequency resolution) in Hz, 245-30000000', metavar='', default=1000000)
    pybladerf_sweep_parser.add_argument('-ch', action='store', help='RX channel. which channel to use (0, 1). Default is 0', metavar='', default=0)
    pybladerf_sweep_parser.add_argument('-1', action='store_true', help='one shot mode. If specified = Enable')
    pybladerf_sweep_parser.add_argument('-N', action='store', help='num_sweeps. Number of sweeps to perform', metavar='')
    pybladerf_sweep_parser.add_argument('-o', action='store_true', help='oversample. If specified = Enable')
    pybladerf_sweep_parser.add_argument('-B', action='store_true', help='binary output. If specified = Enable')
    pybladerf_sweep_parser.add_argument('-s', action='store', help='sweep style ("L" - LINEAR, "I" - INTERLEAVED). Default is INTERLEAVED', metavar='', default='I')
    pybladerf_sweep_parser.add_argument('-SR', action='store', help='sample rate in Hz (0.5 MHz - 122 MHz). Default is 57. To use a sample rate higher than 61, specify oversample', metavar='', default=57)
    pybladerf_sweep_parser.add_argument('-BW', action='store', help='bandwidth in Hz (0.2 MHz - 56 MHz). Default is 56000000', metavar='', default=56.0)
    pybladerf_sweep_parser.add_argument('-FIR', action='store', help='RFIC RX FIR filter ("1" - Enable, "0" - Disable). Default is Disable', metavar='', default='0')
    pybladerf_sweep_parser.add_argument('-r', action='store', help='filename. output file', metavar='')

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)

    args, unparsed_args = parser.parse_known_args()
    if args.command == 'info':
        if args.device_identifiers:
            pybladerf_info.pybladerf_device_identifiers_list_info()
        else:
            pybladerf_info.pybladerf_info()

    elif args.command == 'sweep':
        frequency_range = args.f.split(':')
        frequencies = [71, 5999]
        freq_min, freq_max = None, None
        try:
            freq_min = int(frequency_range[0])
        except Exception:
            pass
        try:
            freq_max = int(frequency_range[1])
        except Exception:
            pass
        if freq_min is not None and freq_max is not None:
            frequencies = [freq_min, freq_max]

        pybladerf_sweep.pybladerf_sweep(frequencies=frequencies,
                                        gain=int(args.g),
                                        bin_width=int(args.w),
                                        sample_rate=float(args.SR) * 1e6,
                                        bandwidth=float(args.BW) * 1e6,
                                        channel=int(args.ch),
                                        oversample=args.o,
                                        num_sweeps=int(args.N) if args.N is not None else None,
                                        binary_output=args.B,
                                        one_shot=args.__dict__.get('1'),
                                        filename=args.r,
                                        device_identifier=args.d,
                                        rxfir=pybladerf.pybladerf_rfic_rxfir.PYBLADERF_RFIC_RXFIR_DEC1 if args.FIR == '1' else (pybladerf.pybladerf_rfic_rxfir.PYBLADERF_RFIC_RXFIR_BYPASS if args.FIR == '0' else -1),
                                        sweep_style=pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_LINEAR if args.s == 'L' else (pybladerf.pybladerf_sweep_style.PYBLADERF_SWEEP_STYLE_INTERLEAVED if args.s == 'I' else -1),
                                        print_to_console=True)


if __name__ == '__main__':
    main()
