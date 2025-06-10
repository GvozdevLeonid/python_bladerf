import subprocess  # noqa I001
import sys
from os import environ, getenv, path

import numpy
from setuptools import Extension, find_packages, setup
from setuptools.command.install import install
from setuptools.command.build_ext import build_ext
from Cython.Build import cythonize

INSTALL_REQUIRES = ['Cython>=3.1.0,<3.2', 'numpy']
SETUP_REQUIRES = ['Cython>=3.1.0,<3.2', 'numpy']
libbladerf_h_path = ''

PLATFORM = sys.platform

if getenv('LIBLINK'):
    PLATFORM = 'android'

if PLATFORM != 'android':
    cflags = environ.get('CFLAGS', '')
    ldflags = environ.get('LDFLAGS', '')
    new_cflags = ''
    new_ldflags = ''

    if PLATFORM in {'linux', 'darwin'}:
        if environ.get('PYTHON_BLADERF_CFLAGS', None) is None:
            try:
                new_cflags = subprocess.check_output(['pkg-config', '--cflags', 'libbladeRF']).decode('utf-8').strip()
                libbladerf_h_path = new_cflags[2:]
            except Exception:
                raise RuntimeError('Unable to run pkg-config. Set cflags manually export PYTHON_BLADERF_CFLAGS=') from None
        else:
            new_cflags = environ.get('PYTHON_BLADERF_CFLAGS', '')
            libbladerf_h_path = new_cflags[2:]

        if environ.get('PYTHON_BLADERF_LDFLAGS', None) is None:
            try:
                new_ldflags = subprocess.check_output(['pkg-config', '--libs', 'libbladeRF']).decode('utf-8').strip()
            except Exception:
                raise RuntimeError('Unable to run pkg-config. Set libs manually export PYTHON_BLADERF_LDFLAGS=') from None
        else:
            new_ldflags = environ.get('PYTHON_BLADERF_LDFLAGS', '')

    elif PLATFORM.startswith('win'):
        include_path = 'C:\\Program Files\\BladeRF\\include'
        lib_path = 'C:\\Program Files\\BladeRF\\lib'
        libbladerf_h_path = include_path

        if environ.get('PYTHON_BLADERF_INCLUDE_PATH', None) is None:
            new_cflags = f'-I"{include_path}"'
        else:
            include_path = environ.get('PYTHON_BLADERF_INCLUDE_PATH', '')
            new_cflags = f'-I"{include_path}"'
            libbladerf_h_path = include_path

        if environ.get('PYTHON_BLADERF_LIB_PATH', None) is None:
            new_ldflags = f'-L"{lib_path}" -lbladeRF'
        else:
            lib_path = environ.get('PYTHON_BLADERF_LIB_PATH', '')
            new_ldflags = f'-L"{lib_path}" -lbladeRF'

        environ['CL'] = f'/I"{include_path}"'
        environ['LINK'] = f'/LIBPATH:"{lib_path}" bladeRF.lib'

    environ['CFLAGS'] = f'{cflags} {new_cflags}'.strip()
    environ['LDFLAGS'] = f'{ldflags} {new_ldflags}'.strip()

else:
    libbladerf_h_path = environ.get('PYTHON_BLADERF_LIBBLADERF_H_PATH', '')


class CustomBuildExt(build_ext):
    def run(self) -> None:  # type: ignore
        compile_env = {'ANDROID': PLATFORM == 'android'}
        self.distribution.ext_modules = cythonize(  # type: ignore
            self.distribution.ext_modules,
            compile_time_env=compile_env,
        )
        super().run()  # type: ignore


class InstallWithPth(install):
    def run(self) -> None:  # type: ignore
        super().run()  # type: ignore

        if PLATFORM.startswith('win'):
            pth_code = (
                'import os; '
                'os.add_dll_directory(os.getenv("BLADERF_LIB_DIR", r"C:\\Program Files\\BladeRF\\lib"))'
            )
            with open(path.join(self.install_lib, "python_bladerf.pth"), mode='w', encoding='utf-8') as file:  # type: ignore
                file.write(pth_code)


setup(  # type: ignore
    name='python_bladerf',
    cmdclass={'build_ext': CustomBuildExt, 'install': InstallWithPth},
    install_requires=INSTALL_REQUIRES,
    setup_requires=SETUP_REQUIRES,
    ext_modules=[
        Extension(  # type: ignore
            name='python_bladerf.pylibbladerf.pybladerf',
            sources=['python_bladerf/pylibbladerf/pybladerf.pyx'],
            include_dirs=['python_bladerf/pylibbladerf', libbladerf_h_path, numpy.get_include()],
            extra_compile_args=['-w'],
            language='c++',
        ),
        Extension(  # type: ignore
            name='python_bladerf.pybladerf_tools.pybladerf_sweep',
            sources=['python_bladerf/pybladerf_tools/pybladerf_sweep.pyx'],
            include_dirs=['python_bladerf/pylibbladerf', 'python_bladerf/pybladerf_tools', libbladerf_h_path, numpy.get_include()],
            extra_compile_args=['-w'],
            language='c++',
        ),
        Extension(  # type: ignore
            name='python_bladerf.pybladerf_tools.pybladerf_transfer',
            sources=['python_bladerf/pybladerf_tools/pybladerf_transfer.pyx'],
            include_dirs=['python_bladerf/pylibbladerf', 'python_bladerf/pybladerf_tools', libbladerf_h_path, numpy.get_include()],
            extra_compile_args=['-w'],
            language='c++',
        ),
    ],
    include_package_data=True,
    packages=find_packages(),
    package_dir={'': '.'},
    zip_safe=False,
)
