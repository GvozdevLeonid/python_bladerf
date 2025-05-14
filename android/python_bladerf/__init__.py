import os

from pythonforandroid.archs import Arch
from pythonforandroid.recipe import (
    CythonRecipe,
    Recipe,
)


class PythonBladerfRecipe(CythonRecipe):
    url = 'https://github.com/GvozdevLeonid/python_bladerf/releases/download/v.{version}/python_bladerf-{version}.tar.gz'
    depends = ('python3', 'setuptools', 'numpy', 'pyjnius', 'libbladerf')
    site_packages_name = 'python_bladerf'
    name = 'python_bladerf'
    version = '1.3.0'

    def get_recipe_env(self, arch: Arch) -> dict:
        env = super().get_recipe_env(arch)

        libbladerf_recipe = Recipe.get_recipe('libbladerf', arch)

        libbladerf_h_dir = os.path.join(libbladerf_recipe.get_build_dir(arch), 'host', 'libraries', 'libbladeRF', 'include')

        env['LDFLAGS'] += f' -L{self.ctx.get_libs_dir(arch.arch)}'
        env['CFLAGS'] += f' -I{libbladerf_h_dir}'

        return env


recipe = PythonBladerfRecipe()
