# ruff: noqa: RUF012
import os
import shutil
from typing import Any, override

import sh
from pythonforandroid.archs import Arch
from pythonforandroid.logger import shprint
from pythonforandroid.recipe import NDKRecipe, Recipe
from pythonforandroid.util import current_directory


class LibbladerfRecipe(NDKRecipe):

    url = 'git+https://github.com/Nuand/bladeRF.git'
    version = 'bb26efdd207ee185b3f7b72f8835d7e49384ae1c'
    generated_libraries = ['libbladerf.so']
    patches = ['bladerf_android.patch']
    site_packages_name = 'libbladerf'
    library_version_major = '2'
    library_version_minor = '6'
    library_version_patch = '0'

    depends = ['libusb']
    name = 'libbladerf'

    @override
    def should_build(self, arch: Arch) -> bool:
        return not os.path.exists(os.path.join(self.ctx.get_libs_dir(arch.arch), 'libbladerf.so'))

    @override
    def prebuild_arch(self, arch: Arch) -> None:
        super().prebuild_arch(arch)

        if not os.path.exists(os.path.join(self.get_build_dir(arch.arch), 'android')):
            libusb_recipe = Recipe.get_recipe('libusb', arch)

            os.mkdir(os.path.join(self.get_build_dir(arch.arch), 'android'))
            os.mkdir(os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))
            os.mkdir(os.path.join(self.get_build_dir(arch.arch), 'android', 'libusb'))

            shutil.copy(os.path.join(self.get_recipe_dir(), 'jni', 'Application.mk'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))
            shutil.copy(os.path.join(self.get_recipe_dir(), 'jni', 'libbladerf.mk'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))
            shutil.copy(os.path.join(self.get_recipe_dir(), 'jni', 'libad936x.mk'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))
            shutil.copy(os.path.join(self.get_recipe_dir(), 'jni', 'Android.mk'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))

            shutil.copy(os.path.join(self.get_recipe_dir(), 'src', 'libusb.c'), os.path.join(self.get_build_dir(arch.arch), 'host', 'libraries', 'libbladeRF', 'src', 'backend', 'usb'))
            shutil.copy(os.path.join(self.get_recipe_dir(), 'src', 'log.c'), os.path.join(self.get_build_dir(arch.arch), 'host', 'common', 'src'))

            shutil.copy(os.path.join(libusb_recipe.get_build_dir(arch), 'libusb', 'libusb.h'), os.path.join(self.get_build_dir(arch.arch), 'android', 'libusb'))

            shprint(
                sh.Command('cmake'),
                '-DLIBBLADERF_VERSION_MAJOR=' + str(self.library_version_major),
                '-DLIBBLADERF_VERSION_MINOR=' + str(self.library_version_minor),
                '-DLIBBLADERF_VERSION_PATCH=' + str(self.library_version_patch),
                '-DLIBBLADERF_VERSION=' + f'{self.library_version_major}.{self.library_version_minor}.{self.library_version_patch}-git',
                '-DLIBBLADERF_HOST_CONFIG_FILE_DIR=' + os.path.join(self.get_build_dir(arch.arch), 'host', 'common', 'include'),
                '-DLIBBLADERF_VERSION_FILE_DIR=' + os.path.join(self.get_build_dir(arch.arch), 'host', 'libraries', 'libbladeRF', 'src'),
                '-DLIBBLADERF_BACKEND_CONFIG_DIR=' + os.path.join(self.get_build_dir(arch.arch), 'host', 'libraries', 'libbladeRF', 'src', 'backend'),
                '-DLIBBLADERF_ROOT_DIR=' + self.get_build_dir(arch.arch),
                '-P',
                os.path.join(self.get_recipe_dir(), 'pre_install.cmake'),
            )

    @override
    def get_recipe_env(self, arch: Arch, **kwargs: Any) -> dict[str, Any]:
        env: dict[str, Any] = super().get_recipe_env(arch, **kwargs)
        env['LDFLAGS'] = env['LDFLAGS'] + f'-L{self.ctx.get_libs_dir(arch.arch)}'

        return env

    @override
    def get_jni_dir(self, arch: Arch) -> str:
        return os.path.join(self.get_build_dir(arch.arch), 'android', 'jni')

    @override
    def get_lib_dir(self, arch: Arch) -> str:
        return os.path.join(self.get_build_dir(arch.arch), 'android', 'obj', 'local', arch.arch)

    @override
    def build_arch(self, arch: Arch, *args: Any) -> None:
        env = self.get_recipe_env(arch)

        shutil.copyfile(os.path.join(self.ctx.get_libs_dir(arch.arch), 'libusb1.0.so'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni', 'libusb1.0.so'))

        with current_directory(self.get_build_dir(arch.arch)):

            shprint(
                sh.Command(os.path.join(self.ctx.ndk_dir, 'ndk-build')),
                'NDK_PROJECT_PATH=' + self.get_build_dir(arch.arch) + '/android',
                'APP_PLATFORM=android-' + str(self.ctx.ndk_api),
                'NDK=' + self.ctx.ndk_dir,
                'APP_ABI=' + arch.arch,
                *args,
                _env=env,
            )

        shutil.copyfile(os.path.join(self.get_build_dir(arch.arch), 'android', 'libs', arch.arch, 'libbladeRF.so'), os.path.join(self.ctx.get_libs_dir(arch.arch), 'libbladeRF.so'))


recipe = LibbladerfRecipe()
