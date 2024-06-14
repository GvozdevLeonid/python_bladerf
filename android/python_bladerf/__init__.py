from pythonforandroid.recipe import CythonRecipe  # type: ignore
from pythonforandroid.recipe import Recipe  # type: ignore
import shutil
import os


class PythonBladerfRecipe(CythonRecipe):
    version = '1.0.1'
    url = 'https://github.com/GvozdevLeonid/python_bladerf/releases/download/v.{version}/python_bladerf-{version}.tar.gz'
    depends = ['python3', 'setuptools', 'numpy', 'libusb', 'libbladeRF']
    site_packages_name = 'python_bladerf'
    name = 'python_bladerf'

    def get_recipe_env(self, arch):
        env = super().get_recipe_env(arch)

        libusb_recipe = Recipe.get_recipe('libusb', arch)
        libusb_h_dir = os.path.join(libusb_recipe.get_build_dir(arch), 'libusb')
        libusb_so_dir = libusb_recipe.get_lib_dir(arch)

        libbladeRF_recipe = Recipe.get_recipe('libbladeRF', arch)
        libbladeRF_h_dir = os.path.join(libbladeRF_recipe.get_build_dir(arch), 'libbladeRF')
        libbladeRF_so_dir = libbladeRF_recipe.get_lib_dir(arch)

        env['CFLAGS'] += ' -I' + libusb_h_dir + ' -I' + libbladeRF_h_dir
        env['LDFLAGS'] += ' -L' + libusb_so_dir + ' -L' + libbladeRF_so_dir

        return env

    def postbuild_arch(self, arch):
        super().postbuild_arch(arch)

        python_bladerf_dir = os.path.join(self.ctx.get_python_install_dir(arch.arch), 'python_bladerf')
        os.makedirs(python_bladerf_dir, exist_ok=True)
        try:
            shutil.move(os.path.join(self.ctx.get_python_install_dir(arch.arch), 'pylibbladerf'), os.path.join(python_bladerf_dir, 'pylibbladerf'))
            shutil.move(os.path.join(self.ctx.get_python_install_dir(arch.arch), 'pybladerf_tools'), os.path.join(python_bladerf_dir, 'pybladerf_tools'))

            shutil.copy(os.path.join(self.get_build_dir(arch.arch), '__init__.py'), python_bladerf_dir)
            shutil.copy(os.path.join(self.get_build_dir(arch.arch), '__main__.py'), python_bladerf_dir)
        except FileNotFoundError:
            pass


recipe = PythonBladerfRecipe()
