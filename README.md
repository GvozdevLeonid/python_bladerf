# python_bladerf

python_bladerf is a cython wrapper for [bladerf](https://github.com/Nuand/bladeRF). It also contains some additional tools.

Before installing python_bladerf library, you must have bladerf host software installed. Because this library uses dynamic linking with an existing library file. Minimum libbladeRF version: 2.5.5

For windows users please use [additional steps](#installation-on-windows) to install python_bladerf
You can install this library using
```
pip install git+https://github.com/GvozdevLeonid/python_bladerf.git
```

If your bladerf files are in non-standard paths and during installation the python_bladerf cannot find libbladeRF.h and bladeRF2.h or the library files, you can specify the paths via environment variables
```
export/set {linux and macos / windows}  PYTHON_BLADERF_CFLAGS=path_to_libbladeRF.h_andbladeRF2.h
export/set {linux and macos / windows}  PYTHON_BLADERF_LDFLAGS=path_to_libbladerf.(so, dylib, dll)
```

## Requirements:
* Numpy>=2.2.1
* Scipy (optional, for faster work)
* pyFFTW (optional, for faster work)
* pyjnius and android (only for android)

## bladerf:
The library supports all bladerf2 functions, some of the functions can also work on the first versions.If there is a demand for full support of the first version, I will add it.

## pybladerf tools:
* pybladerf_info.py - Reading information about found devices.
* pybladerf_sweep.pyx - a function that allows you to obtain a sweep over a given frequency range ( same as hackrf_sweep)
* pybladerf_transfer.pyx - a function that allows you to record and play back samples

## usage
```
usage: python_bladerf [-h] {info, sweep, transfer} ...

python_bladerf is a Python wrapper for libbladerf. It also contains some additional tools.

options:
  -h, --help    show this help message and exit

Available commands:
  {info,sweep,transfer}
    info        Read device information from Bladerf such as serial number and FPGA version.
    sweep       a command-line spectrum analyzer.
    transfer    Send and receive signals using BladeRF. Input/output files consist of complex64 quadrature samples.
```
```
usage: python_bladerf info [-h] [-f] [-s]

options:
  -h, --help            show this help message and exit
  -f, --full            show full info
  -s, --serial_numbers  show only founded serial_numbers
```
```
usage: python_bladerf sweep [-h] [-d] [-f] [-g] [-w] [-c] [-1] [-N] [-o] [-B] [-S] [-s] [-b] [-r]

options:
  -h, --help  show this help message and exit
  -d          serial number of desired BladeRF
  -f          freq_min:freq_max. minimum and maximum frequencies in MHz start:stop or start1:stop1,start2:stop2. Default
  -g          RX gain, -15 - 60dB, 1dB steps
  -w          FFT bin width (frequency resolution) in Hz
  -c          RX channel. which channel to use (0, 1). Default is 0
  -1          one shot mode. If specified = Enable
  -N          Number of sweeps to perform
  -o          oversample. If specified = Enable
  -B          binary output. If specified = Enable
  -S          sweep style ("L" - LINEAR, "I" - INTERLEAVED). Default is INTERLEAVED
  -s          sample rate in MHz  (0.5 MHz - 122 MHz). Default is 61. To use a sample rate higher than 61, specify oversample
  -b          baseband filter bandwidth in MHz (0.2 MHz - 56 MHz). Default .75 * sample rate
  -r          filename. output file
```
```
python_bladerf transfer [-h] [-d] [-r] [-t] [-f] [-p] [-c] [-g] [-N] [-R] [-s] -[b] [-H] -[o]

options:
  -d                  serial number of desired BladeRF
  -r                  <filename> receive data into file (use "-" for stdout)
  -t                  <filename> transmit data from file (use "-" for stdout)
  -f, --freq_hz       frequency in Hz (0MHz to 6000MHz supported). Default is 900MHz
  -p                  antenna port power. If specified = Enable
  -c                  RX or TX channel. which channel to use (0, 1). Default is 0
  -g                  RX or TX gain, RX: -15 - 60dB, 1dB steps, TX: -24 - 66 dB, 1dB steps
  -N                  number of samples to transfer (default is unlimited)
  -R                  repeat TX mode. Fefault is off
  -s                  sample rate in MHz  (0.5 MHz - 122 MHz). Default is 61. To use a sample rate higher than 61, specify oversample'
  -b                  baseband filter bandwidth in MHz (0.2 MHz - 56 MHz). Default .75 * sample rate
  -H                  synchronize RX/TX to external trigger input
  -o                  oversample. If specified = Enable
```

## Android
This library can work on android. To do this, go to the android directory and download 3 recipes for [p4a](https://github.com/kivy/python-for-android).

buildozer.spec
```
requirements = python3,android,pyjnius,numpy,libusb,libbladerf,python_bladerf
p4a.local_recipes = path_to_pythonforandroidrecipes_folder
```

#### Your recipes folder should contain at least the following files:
```
pythonforandroidrecipes/
    __init__.py
    libusb/
        __init__.py
    python_bladerf/
        __init__.py
    libbladerf/
        __init__.py
        bladerf_android.patch
        pre_install.cmake
        jni/
            Android.mk
            Application.mk
            libbladerf.mk
            libad936x.mk
        src/
            libusb.c
            log.c
```

## Examples
Please use the original bladerf documentation

## Installation on Windows
To install python_bladerf, you must first install the BladeRF software. Official installation instructions are available on the [BladeRF documentation site](https://github.com/Nuand/bladeRF/wiki/Getting-Started%3A-Windows).
Alternatively, you can download the ZIP archive from the Releases tab of this repository. Extract the archive and move its contents to the standard location: `C:\Program Files\BladeRF`

The BladeRF directory should contain the following subfolders and files:
```
├── include
│ └── libbladeRF.h
│ └── bladeRF2.h
│ └── bladeRF1.h
│ └── pthread.h
├── lib
│ └── bladeRF.dll
│ └── bladeRF.lib ← for MSVC
│ └── libbladeRF.a ← for MinGW
│ └── libusb-1.0.dll
│ └── pthreadVC2.dll
│ └── msvcr100.dll
```


In addition, the archive includes other required DLLs and dependencies to ensure proper operation of HackRF on Windows.
libusb-1.0.dll
pthreadVC2.dll
msvcr100.dll

If you install bladerf yourself or via another path, set the following environment variables

MSVC:
```
  set PYTHON_BLADERF_CFLAGS=/I"{path to .h file directory}"
  set PYTHON_BLADERF_LDFLAGS=/LIBPATH:"{path to .dll and .lib file directory}" bladeRF.lib
  set BLADERF_LIB_DIR="{path to .dll and .lib file directory}"
```
MinGW:
```
  set PYTHON_BLADERF_CFLAGS=-I"{path to .h file directory}"
  set PYTHONBLADERFF_LDFLAGS=-L"{path to .dll and .a file directory}" -lbladeRF'
  set BLADERF_LIB_DIR="{path to .dll and .lib file directory}"
```
