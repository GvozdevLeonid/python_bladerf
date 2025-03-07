import subprocess
import sys
from os import environ, getenv

import numpy
from setuptools import Extension, find_packages, setup
from setuptools.command.build_ext import build_ext
from Cython.Build import cythonize

libraries = ['bladeRF']

INSTALL_REQUIRES = []
SETUP_REQUIRES = []

PLATFORM = sys.platform

if getenv('LIBLINK'):
    PLATFORM = 'android'

if PLATFORM != 'android':
    SETUP_REQUIRES.append('Cython==0.29.37')
    INSTALL_REQUIRES.append('Cython==0.29.37')

    SETUP_REQUIRES.append('numpy')
    INSTALL_REQUIRES.append('numpy')

    cflags = environ.get('CFLAGS', '')
    ldflags = environ.get('LDFLAGS', '')

    if PLATFORM in {'linux', 'darwin'}:
        if environ.get('PYTHON_BLADERF_CFLAGS', None) is None:
            try:
                new_cflags = subprocess.check_output(['pkg-config', '--cflags', 'libbladerf']).decode('utf-8').strip()
            except Exception:
                raise RuntimeError('Unable to run pkg-config. Set cflags manually export PYTHON_BLADERF_CFLAGS=') from None
        else:
            new_cflags = environ.get('PYTHON_BLADERF_CFLAGS', '')

        if environ.get('PYTHON_BLADERF_LDFLAGS', None) is None:
            try:
                new_ldflags = subprocess.check_output(['pkg-config', '--libs', 'libbladerf']).decode('utf-8').strip()
            except Exception:
                raise RuntimeError('Unable to run pkg-config. Set libs manually export PYTHON_BLADERF_LDFLAGS=') from None
        else:
            new_ldflags = environ.get('PYTHON_BLADERF_LDFLAGS', '')

    elif PLATFORM == 'win32':
        pass

    environ['CFLAGS'] = f'{cflags} {new_cflags}'.strip()
    environ['LDFLAGS'] = f'{ldflags} {new_ldflags}'.strip()


class CustomBuildExt(build_ext):
    def run(self) -> None:
        compile_env = {'ANDROID': PLATFORM == 'android'}
        self.distribution.ext_modules = cythonize(
            self.distribution.ext_modules,
            compile_time_env=compile_env,
        )
        super().run()


setup(
    name='python_bladerf',
    cmdclass={'build_ext': CustomBuildExt},
    install_requires=INSTALL_REQUIRES,
    setup_requires=SETUP_REQUIRES,
    ext_modules=[
        Extension(
            name='python_bladerf.pylibbladerf.pybladerf',
            sources=['python_bladerf/pylibbladerf/pybladerf.pyx', 'python_bladerf/pylibbladerf/cbladerf.pxd'],
            libraries=libraries,
            include_dirs=['python_bladerf/pylibbladerf', numpy.get_include()],
            extra_compile_args=['-w'],
        ),
        Extension(
            name='python_bladerf.pybladerf_tools.pybladerf_sweep',
            sources=['python_bladerf/pybladerf_tools/pybladerf_sweep.pyx'],
            include_dirs=['python_bladerf/pylibbladerf', 'python_bladerf/pybladerf_tools', numpy.get_include()],
            extra_compile_args=['-w'],
        ),
        Extension(
            name='python_bladerf.pybladerf_tools.pybladerf_transfer',
            sources=['python_bladerf/pybladerf_tools/pybladerf_transfer.pyx'],
            include_dirs=['python_bladerf/pybladerf_tools', numpy.get_include()],
            extra_compile_args=['-w'],
        ),
    ],
    include_package_data=True,
    packages=find_packages(),
    package_dir={'': '.'},
    zip_safe=False,
)
