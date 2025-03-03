# Set libbladerf version
set(VERSION_INFO_MAJOR ${LIBBLADERF_VERSION_MAJOR})
set(VERSION_INFO_MINOR ${LIBBLADERF_VERSION_MINOR})
set(VERSION_INFO_PATCH ${LIBBLADERF_VERSION_PATCH})
set(VERSION ${LIBBLADERF_VERSION})

# Configure backend variables
set(ENABLE_BACKEND_LIBUSB 1)
set(ENABLE_BACKEND_USB 1)
set(BLADERF_OS_LINUX 1)

# Setup LIBAD936X library
set(LIBAD936X_FILES
    ad9361.c
    ad9361.h
    ad9361_api.c
    ad9361_api.h
    ad9361_conv.c
    common.h
    util.c
    util.h
)

foreach(cpfile IN ITEMS ${LIBAD936X_FILES})
    configure_file(
        "${LIBBLADERF_ROOT_DIR}/thirdparty/analogdevicesinc/no-OS/ad9361/sw/${cpfile}"
        "${LIBBLADERF_ROOT_DIR}/host/common/thirdparty/ad9361/sw/${cpfile}"
        COPYONLY
    )
endforeach(cpfile)

set(LIBAD936X_PATCHES
    0001-0bba46e-nuand-modifications.patch
    0002-0bba46e-pr-561.patch
    0003-0bba46e-pr-573.patch
    0004-0bba46e-pr-598.patch
    0005-0bba46e-rm-ad9361_parse_fir.patch
    0006-0bba46e-compilefix.patch
)

foreach(patchfile IN ITEMS ${LIBAD936X_PATCHES})
    message(STATUS "libad936x: Applying patch: ${patchfile}")

    execute_process(
        COMMAND patch -p3 -i ${LIBBLADERF_ROOT_DIR}/thirdparty/analogdevicesinc/no-OS_local/patches/${patchfile}
        WORKING_DIRECTORY "${LIBBLADERF_ROOT_DIR}/host/common/thirdparty/ad9361/sw/"
        RESULT_VARIABLE resultcode
        ERROR_VARIABLE errvar
    )

    if(resultcode)
        message(FATAL_ERROR "Failed to apply ${patchfile}: ${resultcode} ${errvar}")
    endif(resultcode)
endforeach(patchfile)

# Setup host_config and version header files
configure_file(
    ${LIBBLADERF_HOST_CONFIG_FILE_DIR}/host_config.h.in
    ${LIBBLADERF_HOST_CONFIG_FILE_DIR}/host_config.h
    @ONLY
)

configure_file(
    ${LIBBLADERF_VERSION_FILE_DIR}/version.h.in
    ${LIBBLADERF_VERSION_FILE_DIR}/version.h
    @ONLY
)


configure_file(
    ${LIBBLADERF_BACKEND_CONFIG_DIR}/backend_config.h.in
    ${LIBBLADERF_BACKEND_CONFIG_DIR}/backend_config.h
    @ONLY
)
