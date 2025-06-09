# ruff: noqa: RUF012
import os
from typing import Any, override

from pythonforandroid.archs import Arch
from pythonforandroid.recipe import (
    PyProjectRecipe,
    Recipe,
)


class PythonBladerfRecipe(PyProjectRecipe):
    url = 'https://github.com/GvozdevLeonid/python_bladerf/releases/download/v.{version}/python_bladerf-{version}.tar.gz'
    depends = ['python3', 'setuptools', 'numpy', 'pyjnius', 'libbladerf']
    hostpython_prerequisites = ['Cython>=3.1.0,<3.2']
    site_packages_name = 'python_bladerf'
    name = 'python_bladerf'
    version = '1.4.0'

    @override
    def get_recipe_env(self, arch: Arch, **kwargs: Any) -> dict[str, Any]:
        env: dict[str, Any] = super().get_recipe_env(arch, **kwargs)

        libbladerf_recipe = Recipe.get_recipe('libbladerf', arch)
        libbladerf_h_dir = os.path.join(libbladerf_recipe.get_build_dir(arch), 'host', 'libraries', 'libbladeRF', 'include')

        env['LDFLAGS'] = env['LDFLAGS'] + f' -L{self.ctx.get_libs_dir(arch.arch)} -lbladeRF'
        env['CFLAGS'] = env['CFLAGS'] + f' -I{libbladerf_h_dir}'

        env['PYTHON_BLADERF_LIBBLADERF_H_PATH'] = libbladerf_h_dir
        env['LDSHARED'] = env['CC'] + ' -shared'
        env['LIBLINK'] = 'NOTNONE'

        return env


recipe = PythonBladerfRecipe()
