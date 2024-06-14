from pathlib import Path
from os import getenv, environ
import sys

from setuptools import setup, Extension, find_packages
from setuptools.command.build_ext import build_ext
import numpy

libraries = ['usb-1.0', 'bladeRF']

LIBBLADERF_FILES = list(Path('python_bladerf/pylibbladerf').rglob('*.pyx'))
PYBLADERF_TOOLS_FILES = list(Path('python_bladerf/pybladerf_tools').rglob('*.pyx'))

INSTALL_REQUIRES = []
SETUP_REQUIRES = []

PLATFORM = sys.platform

if getenv('LIBLINK'):
    PLATFORM = 'android'

# detect cython
if PLATFORM != 'android':
    SETUP_REQUIRES.append('cython==0.29.36')
    INSTALL_REQUIRES.append('cython==0.29.36')
    INSTALL_REQUIRES.append('numpy>=1.26')

    cflags = environ.get('CFLAGS', '')
    ldflags = environ.get('LDFLAGS', '')

    if PLATFORM == 'darwin':
        new_cflags = '-I/opt/homebrew/include/libusb-1.0 -I/opt/homebrew/include'
        new_ldflags = '-L/opt/homebrew/lib'
    elif PLATFORM.startswith('linux'):
        new_cflags = '-I/usr/include/libusb-1.0 -I/usr/include'
        new_ldflags = '-L/usr/lib64 -L/usr/lib'
    elif PLATFORM == 'win32':
        pass

    environ['CFLAGS'] = f'{cflags} {new_cflags}'.strip()
    environ['LDFLAGS'] = f'{ldflags} {new_ldflags}'.strip()
else:
    libraries = ['usb1.0', 'bladeRF']

source_files = [str(fn) for fn in LIBBLADERF_FILES]

setup(
    name='python_bladerf',
    cmdclass={'build_ext': build_ext},
    install_requires=INSTALL_REQUIRES,
    setup_requires=SETUP_REQUIRES,
    ext_modules=[
        Extension(
            name='python_bladerf.pylibbladerf.pybladerf',
            sources=source_files,
            libraries=libraries,
            include_dirs=['python_bladerf/pylibbladerf', numpy.get_include()],
            extra_compile_args=['-w'],
        ),
        Extension(
            name='python_bladerf.pybladerf_tools.pybladerf_sweep',
            sources=[str(fn) for fn in PYBLADERF_TOOLS_FILES],
            include_dirs=['python_bladerf/pybladerf_tools', numpy.get_include()],
            extra_compile_args=['-w'],
        )
    ],
    packages=find_packages(),
    package_dir={'': '.'},
    include_package_data=True,
)
