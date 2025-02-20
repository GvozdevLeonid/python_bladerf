import os
import shutil

import sh
from pythonforandroid.archs import Arch
from pythonforandroid.logger import shprint
from pythonforandroid.recipe import NDKRecipe, Recipe
from pythonforandroid.util import current_directory


class LibbladerfRecipe(NDKRecipe):

    # url = 'https://github.com/Nuand/bladeRF/archive/refs/tags/{version}.tar.gz'
    url = 'https://github.com/Nuand/bladeRF/archive/refs/heads/master.zip'
    # patches = ('hackrf_android.patch', )
    generated_libraries = ('libbladerf.so', )
    site_packages_name = 'libbladerf'
    version = '2023.02'
    library_version_major = 2
    library_version_minor = 5
    library_version_patch = 1

    depends = ('libusb', )
    name = 'libbladerf'

    def should_build(self, arch: Arch) -> bool:
        return not os.path.exists(os.path.join(self.ctx.get_libs_dir(arch.arch), 'libbladerf.so'))

    def prebuild_arch(self, arch: Arch) -> None:
        super().prebuild_arch(arch)

        if not os.path.exists(os.path.join(self.get_build_dir(arch.arch), 'android')):
            libusb_recipe = Recipe.get_recipe('libusb', arch)

            os.mkdir(os.path.join(self.get_build_dir(arch.arch), 'android'))
            os.mkdir(os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))
            os.mkdir(os.path.join(self.get_build_dir(arch.arch), 'android', 'libusb'))

            shutil.copy(os.path.join(self.get_recipe_dir(), 'jni', 'Application.mk'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))
            shutil.copy(os.path.join(self.get_recipe_dir(), 'jni', 'libbladerf.mk'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))
            shutil.copy(os.path.join(self.get_recipe_dir(), 'jni', 'Android.mk'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))

            shutil.copy(os.path.join(libusb_recipe.get_build_dir(arch), 'libusb', 'libusb.h'), os.path.join(self.get_build_dir(arch.arch), 'android', 'libusb'))

    def get_recipe_env(self, arch: Arch) -> dict:
        env = super().get_recipe_env(arch)
        env['LDFLAGS'] += f'-L{self.ctx.get_libs_dir(arch.arch)}'

        return env

    def get_jni_dir(self, arch: Arch) -> str:
        return os.path.join(self.get_build_dir(arch.arch), 'android', 'jni')

    def get_lib_dir(self, arch: Arch) -> str:
        return os.path.join(self.get_build_dir(arch.arch), 'android', 'obj', 'local', arch.arch)

    def build_arch(self, arch: Arch, *extra_args) -> None:
        env = self.get_recipe_env(arch)

        shutil.copyfile(os.path.join(self.ctx.get_libs_dir(arch.arch), 'libusb1.0.so'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni', 'libusb1.0.so'))

        with current_directory(self.get_build_dir(arch.arch)):
            shprint(
                sh.Command(os.path.join(self.ctx.ndk_dir, 'ndk-build')),
                'NDK_PROJECT_PATH=' + self.get_build_dir(arch.arch) + '/android',
                'APP_PLATFORM=android-' + str(self.ctx.ndk_api),
                'LIBBLADERF_VERSION_MAJOR=' + self.library_version_major,
                'LIBBLADERF_VERSION_MINOR=' + self.library_version_minor,
                'LIBBLADERF_VERSION_PATCH=' + self.library_version_patch,
                'NDK=' + self.ctx.ndk_dir,
                'APP_ABI=' + arch.arch,
                *extra_args,
                _env=env,
            )

        shutil.copyfile(os.path.join(self.get_build_dir(arch.arch), 'android', 'libs', arch.arch, 'libbladerf.so'), os.path.join(self.ctx.get_libs_dir(arch.arch), 'libbladerf.so'))


recipe = LibbladerfRecipe()
