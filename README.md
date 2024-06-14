# python_bladerf

python_bladerf is a cython wrapper for bladerf (https://github.com/Nuand/bladeRF). It also contains some additional tools.

You can install this library using
```
pip install python_bladerf
```
Or assemble it manually using the following steps:

In order to build the library you need to go to the python_bladerf directory
```
cd python_bladerf
```
call
```
python setup.py build_ext --inplace.
```
If the build fails, you will need to specify the paths for the libusb library.
```
CFLAGS="-I/path to libusb.h -I/path to libbladeRF.h" \
LDFLAGS="-L/path to libusb-1.0.so -L/path to libBladeRF.so" \
python setup.py build_ext --inplace
```

## Requirements:
* libusb-1.0 (https://github.com/libusb/libusb)
* libBladeRF (https://github.com/Nuand/bladeRF)
* Cython==0.29.36
* Numpy>=1.26
* Scipy (optional, for faster work)
* pyFFTW (optional, for faster work)

## bladerf:
Almost all the functionality of the standard library is implemented. Some features will be added later. (async recieve and transmit).

## pybladerf tools:
* pybladerf_info.py - Reading information about found devices.
* pybladerf_sweep.py - Possibility to get extended range fft ( same as hackrf_sweep)

## usage
```
usage: python_bladerf [-h] {info, sweep} ...

python_bladerf is a Python wrapper for libbladerf. It also contains some additional tools.

options:
  -h, --help    show this help message and exit

Available commands:
  {info,sweep}
    info        Read device information from Bladerf such as serial number and FPGA version.
    sweep       a command-line spectrum analyzer.
```
```
usage: python_bladerf info [-h] [-f] [-s]

options:
  -h, --help            show this help message and exit
  -f, --full            show full info
  -i, --device_identifiers
                        show only founded device_identifiers
```
```
usage: python_bladerf sweep [-h] [-d] [-f] [-g] [-w] [-ch] [-1] [-N] [-o] [-B] [-s] [-SR] [-BW] -[FIR] [-r]

options:
  -h, --help  show this help message and exit
  -d          device_identifier. device identifier of desired BladeRF
  -f          freq_min:freq_max. minimum and maximum frequencies in MHz start:stop. Default is 71:5999
  -g          gain_db. RX gain, -15 - 60dB, 1dB steps
  -w          bin_width. FFT bin width (frequency resolution) in Hz, 245-30000000
  -ch         RX channel. which channel to use (0, 1). Default is 0
  -1          one shot mode. If specified = Enable
  -N          num_sweeps. Number of sweeps to perform
  -o          oversample. If specified = Enable
  -B          binary output. If specified = Enable
  -s          sweep style ("L" - LINEAR, "I" - INTERLEAVED). Default is INTERLEAVED
  -SR         sample rate in Hz (0.5 MHz - 122 MHz). Default is 57. To use a sample rate higher than 61, specify oversample
  -BW         bandwidth in Hz (0.2 MHz - 56 MHz). Default is 56000000
  -FIR        RFIC RX FIR filter ("1" - Enable, "0" - Disable). Default is Disable
  -r          filename. output file
```
## Note
This library probably can work on android. To do this, go to the android directory and download two recipes for p4a.
## Examples
Examples will be added later.