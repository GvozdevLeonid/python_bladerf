# MIT License

# Copyright (c) 2024-2025 GvozdevLeonid

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from libc.stdint cimport *

cdef extern from 'bladerf_stream.h' nogil:
    ctypedef enum bladerf_stream_state:
        STREAM_IDLE,
        STREAM_RUNNING,
        STREAM_SHUTTING_DOWN,
        STREAM_DONE

    cdef struct bladerf_stream:
        bladerf *dev
        bladerf_channel_layout layout
        bladerf_format format
        unsigned int transfer_timeout
        void *user_data
        size_t samples_per_buffer
        size_t num_buffers
        void **buffers

        int error_code
        bladerf_stream_state state

cdef extern from 'libbladeRF.h' nogil:

    cdef struct bladerf:
        pass

    ctypedef enum bladerf_backend:
        BLADERF_BACKEND_ANY
        BLADERF_BACKEND_LINUX
        BLADERF_BACKEND_LIBUSB
        BLADERF_BACKEND_CYPRESS
        BLADERF_BACKEND_DUMMY

    const int BLADERF_DESCRIPTION_LENGTH
    const int BLADERF_SERIAL_LENGTH

    cdef struct bladerf_devinfo:
        bladerf_backend backend
        char serial[BLADERF_SERIAL_LENGTH]
        uint8_t usb_bus
        uint8_t usb_addr
        unsigned int instance
        char manufacturer[BLADERF_DESCRIPTION_LENGTH]
        char product[BLADERF_DESCRIPTION_LENGTH]

    cdef struct bladerf_backendinfo:
        int handle_count
        void *handle
        int lock_count
        void *lock

    int bladerf_open(bladerf **device, const char *device_identifier)

    void bladerf_close(bladerf *device)

    int bladerf_open_with_devinfo(bladerf **device, bladerf_devinfo *devinfo)

    int bladerf_get_device_list(bladerf_devinfo **devices)

    void bladerf_free_device_list(bladerf_devinfo *devices)

    int bladerf_get_devinfo(bladerf *dev, bladerf_devinfo *info)

    int bladerf_get_backendinfo(bladerf *dev, bladerf_backendinfo *info)

    int bladerf_get_devinfo_from_str(char *devstr, bladerf_devinfo *info)

    bint bladerf_devinfo_matches(const bladerf_devinfo *a, const bladerf_devinfo *b)

    bint bladerf_devstr_matches(const char *dev_str, bladerf_devinfo *info)

    char *bladerf_backend_str(bladerf_backend backend)

    void bladerf_set_usb_reset_on_open(bint enabled)

    cdef struct bladerf_range:
        int64_t min
        int64_t max
        int64_t step
        float scale

    cdef struct bladerf_serial:
        char serial[BLADERF_SERIAL_LENGTH]

    cdef struct bladerf_version:
        uint16_t major
        uint16_t minor
        uint16_t patch
        const char *describe

    ctypedef enum bladerf_fpga_size:
        BLADERF_FPGA_UNKNOWN
        BLADERF_FPGA_40KLE
        BLADERF_FPGA_115KLE
        BLADERF_FPGA_A4
        BLADERF_FPGA_A5
        BLADERF_FPGA_A9

    ctypedef enum bladerf_dev_speed:
        BLADERF_DEVICE_SPEED_UNKNOWN
        BLADERF_DEVICE_SPEED_HIGH
        BLADERF_DEVICE_SPEED_SUPER

    ctypedef enum bladerf_fpga_source:
        BLADERF_FPGA_SOURCE_UNKNOWN
        BLADERF_FPGA_SOURCE_FLASH
        BLADERF_FPGA_SOURCE_HOST

    int bladerf_get_serial_struct(bladerf *dev, bladerf_serial *serial)

    int bladerf_get_fpga_size(bladerf *dev, bladerf_fpga_size *size)

    int bladerf_get_fpga_bytes(bladerf *dev, size_t *size)

    int bladerf_get_flash_size(bladerf *dev, uint32_t *size, bint *is_guess)

    int bladerf_fw_version(bladerf *dev, bladerf_version *version)

    int bladerf_is_fpga_configured(bladerf *dev)

    int bladerf_fpga_version(bladerf *dev, bladerf_version *version)

    int bladerf_get_fpga_source(bladerf *dev, bladerf_fpga_source *source)

    bladerf_dev_speed bladerf_device_speed(bladerf *dev)

    const char* bladerf_get_board_name(bladerf *dev)

    ctypedef enum bladerf_direction:
        BLADERF_RX
        BLADERF_TX

    ctypedef enum bladerf_channel_layout:
        BLADERF_RX_X1
        BLADERF_TX_X1
        BLADERF_RX_X2
        BLADERF_TX_X2

    size_t bladerf_get_channel_count(bladerf *dev, bladerf_direction dir)

    ctypedef enum bladerf_gain_mode:
        BLADERF_GAIN_DEFAULT
        BLADERF_GAIN_MGC
        BLADERF_GAIN_FASTATTACK_AGC
        BLADERF_GAIN_SLOWATTACK_AGC
        BLADERF_GAIN_HYBRID_AGC

    cdef struct bladerf_gain_modes:
        const char *name
        bladerf_gain_mode mode

    int bladerf_set_gain(bladerf *dev, int ch, int gain)

    int bladerf_get_gain(bladerf *dev, int ch, int *gain)

    int bladerf_set_gain_mode(bladerf *dev, int ch, bladerf_gain_mode mode)

    int bladerf_get_gain_mode(bladerf *dev, int ch, bladerf_gain_mode *mode)

    int bladerf_get_gain_modes(bladerf *dev, int ch, const bladerf_gain_modes **modes)

    int bladerf_get_gain_range(bladerf *dev, int ch, const bladerf_range **range)

    int bladerf_set_gain_stage(bladerf *dev, int ch, const char *stage, int gain)

    int bladerf_get_gain_stage(bladerf *dev, int ch, const char *stage, int *gain)

    int bladerf_get_gain_stage_range(bladerf *dev, int ch, const char *stage, const bladerf_range **range)

    int bladerf_get_gain_stages(bladerf *dev, int ch, const char **stages, size_t count)

    cdef struct bladerf_rational_rate:
        uint64_t integer
        uint64_t num
        uint64_t den

    int bladerf_set_sample_rate(bladerf *dev, int ch, unsigned int rate, unsigned int *actual)

    int bladerf_set_rational_sample_rate(bladerf *dev, int ch, bladerf_rational_rate *rate, bladerf_rational_rate *actual)

    int bladerf_get_sample_rate(bladerf *dev, int ch, unsigned int *rate)

    int bladerf_get_sample_rate_range(bladerf *dev, int ch, const bladerf_range **range)

    int bladerf_get_rational_sample_rate(bladerf *dev, int ch, bladerf_rational_rate *rate)

    int bladerf_set_bandwidth(bladerf *dev, int ch, unsigned int bandwidth, unsigned int *actual)

    int bladerf_get_bandwidth(bladerf *dev, int ch, unsigned int *bandwidth)

    int bladerf_get_bandwidth_range(bladerf *dev, int ch, const bladerf_range **range)

    int bladerf_select_band(bladerf *dev, int ch, uint64_t frequency)

    int bladerf_set_frequency(bladerf *dev, int ch, uint64_t frequency)

    int bladerf_get_frequency(bladerf *dev, int ch, uint64_t *frequency)

    int bladerf_get_frequency_range(bladerf *dev, int ch, const bladerf_range **range)

    ctypedef enum bladerf_loopback:
        BLADERF_LB_NONE
        BLADERF_LB_FIRMWARE
        BLADERF_LB_BB_TXLPF_RXVGA2
        BLADERF_LB_BB_TXVGA1_RXVGA2
        BLADERF_LB_BB_TXLPF_RXLPF
        BLADERF_LB_BB_TXVGA1_RXLPF
        BLADERF_LB_RF_LNA1
        BLADERF_LB_RF_LNA2
        BLADERF_LB_RF_LNA3
        BLADERF_LB_RFIC_BIST

    cdef struct bladerf_loopback_modes:
        const char *name
        bladerf_loopback mode

    int bladerf_get_loopback_modes(bladerf *dev, const bladerf_loopback_modes **modes)

    bint bladerf_is_loopback_mode_supported(bladerf *dev, bladerf_loopback mode)

    int bladerf_set_loopback(bladerf *dev, bladerf_loopback lb)

    int bladerf_get_loopback(bladerf *dev, bladerf_loopback *lb)

    ctypedef enum bladerf_trigger_role:
        BLADERF_TRIGGER_ROLE_INVALID
        BLADERF_TRIGGER_ROLE_DISABLED
        BLADERF_TRIGGER_ROLE_MASTER
        BLADERF_TRIGGER_ROLE_SLAVE

    ctypedef enum bladerf_trigger_signal:
        BLADERF_TRIGGER_INVALID
        BLADERF_TRIGGER_J71_4
        BLADERF_TRIGGER_J51_1
        BLADERF_TRIGGER_MINI_EXP_1

        BLADERF_TRIGGER_USER_0
        BLADERF_TRIGGER_USER_1
        BLADERF_TRIGGER_USER_2
        BLADERF_TRIGGER_USER_3
        BLADERF_TRIGGER_USER_4
        BLADERF_TRIGGER_USER_5
        BLADERF_TRIGGER_USER_6
        BLADERF_TRIGGER_USER_7

    cdef struct bladerf_trigger:
        int channel
        bladerf_trigger_role role
        bladerf_trigger_signal signal
        uint64_t options

    int bladerf_trigger_init(bladerf *dev, int ch, bladerf_trigger_signal signal, bladerf_trigger *trigger)

    int bladerf_trigger_arm(bladerf *dev, const bladerf_trigger *trigger, bint arm, uint64_t resv1, uint64_t resv2)

    int bladerf_trigger_fire(bladerf *dev, const bladerf_trigger *trigger)

    int bladerf_trigger_state(bladerf *dev, const bladerf_trigger *trigger, bint *is_armed, bint *has_fired, bint *fire_requested, uint64_t *resv1, uint64_t *resv2)

    ctypedef enum bladerf_rx_mux:
        BLADERF_RX_MUX_INVALID
        BLADERF_RX_MUX_BASEBAND
        BLADERF_RX_MUX_12BIT_COUNTER
        BLADERF_RX_MUX_32BIT_COUNTER
        BLADERF_RX_MUX_DIGITAL_LOOPBACK

    int bladerf_set_rx_mux(bladerf *dev, bladerf_rx_mux mux)

    int bladerf_get_rx_mux(bladerf *dev, bladerf_rx_mux *mode)

    cdef struct bladerf_quick_tune:
        uint8_t freqsel
        uint8_t vcocap
        uint16_t nint
        uint32_t nfrac
        uint8_t flags
        uint8_t xb_gpio

        uint16_t nios_profile
        uint8_t rffe_profile
        uint8_t port
        uint8_t spdt

    int bladerf_schedule_retune(bladerf *dev, int ch, uint64_t timestamp, uint64_t frequency, bladerf_quick_tune *quick_tune)

    int bladerf_cancel_scheduled_retunes(bladerf *dev, int ch)

    int bladerf_get_quick_tune(bladerf *dev, int ch, bladerf_quick_tune *quick_tune)

    ctypedef enum bladerf_correction:
        BLADERF_CORR_DCOFF_I
        BLADERF_CORR_DCOFF_Q
        BLADERF_CORR_PHASE
        BLADERF_CORR_GAIN

    int bladerf_set_correction(bladerf *dev, int ch, bladerf_correction corr, int16_t value)

    int bladerf_get_correction(bladerf *dev, int ch, bladerf_correction corr, int16_t *value)

    ctypedef enum bladerf_format:
        BLADERF_FORMAT_SC16_Q11
        BLADERF_FORMAT_SC16_Q11_META
        BLADERF_FORMAT_PACKET_META
        BLADERF_FORMAT_SC8_Q7
        BLADERF_FORMAT_SC8_Q7_META

    cdef struct bladerf_metadata:
        uint64_t timestamp
        uint32_t flags
        uint32_t status
        unsigned int actual_count
        uint8_t reserved[32]

    int bladerf_interleave_stream_buffer(bladerf_channel_layout layout, bladerf_format format, unsigned int buffer_size, void *samples)

    int bladerf_deinterleave_stream_buffer(bladerf_channel_layout layout, bladerf_format format, unsigned int buffer_size, void *samples)

    int bladerf_enable_module(bladerf *dev, int ch, bint enable)

    int bladerf_get_timestamp(bladerf *dev, bladerf_direction dir, uint64_t *timestamp)

    int bladerf_sync_config(bladerf *dev, bladerf_channel_layout layout, bladerf_format format, unsigned int num_buffers, unsigned int buffer_size, unsigned int num_transfers, unsigned int stream_timeout)

    int bladerf_sync_tx(bladerf *dev, const void *samples, unsigned int num_samples, bladerf_metadata *metadata, unsigned int timeout_ms)

    int bladerf_sync_rx(bladerf *dev, void *samples, unsigned int num_samples, bladerf_metadata *metadata, unsigned int timeout_ms)

    void *BLADERF_STREAM_NO_DATA

    ctypedef void *(*bladerf_stream_cb)(bladerf *dev, bladerf_stream *stream, bladerf_metadata *meta, void *samples, size_t num_samples, void *user_data)

    int bladerf_init_stream(bladerf_stream **stream, bladerf *dev, bladerf_stream_cb callback, void ***buffers, size_t num_buffers, bladerf_format format, size_t samples_per_buffer, size_t num_transfers, void *user_data)

    int bladerf_start_stream 'bladerf_stream' (bladerf_stream *stream, bladerf_channel_layout layout)

    int bladerf_submit_stream_buffer(bladerf_stream *stream, void *buffer, unsigned int timeout_ms)

    int bladerf_submit_stream_buffer_nb(bladerf_stream *stream, void *buffer)

    void bladerf_deinit_stream(bladerf_stream *stream)

    int bladerf_set_stream_timeout(bladerf *dev, bladerf_direction dir, unsigned int timeout)

    int bladerf_get_stream_timeout(bladerf *dev, bladerf_direction dir, unsigned int *timeout)

    int bladerf_flash_firmware(bladerf *dev, const char *firmware)

    int bladerf_load_fpga(bladerf *dev, const char *fpga)

    int bladerf_flash_fpga(bladerf *dev, const char *fpga_image)

    int bladerf_erase_stored_fpga(bladerf *dev)

    int bladerf_device_reset(bladerf *dev)

    int bladerf_get_fw_log(bladerf *dev, const char *filename)

    int bladerf_jump_to_bootloader(bladerf *dev)

    int bladerf_get_bootloader_list(bladerf_devinfo **list)

    int bladerf_load_fw_from_bootloader(const char *device_identifier, bladerf_backend backend, uint8_t bus, uint8_t addr, const char *file)

    ctypedef enum bladerf_image_type:
        BLADERF_IMAGE_TYPE_INVALID
        BLADERF_IMAGE_TYPE_RAW
        BLADERF_IMAGE_TYPE_FIRMWARE
        BLADERF_IMAGE_TYPE_FPGA_40KLE
        BLADERF_IMAGE_TYPE_FPGA_115KLE
        BLADERF_IMAGE_TYPE_FPGA_A4
        BLADERF_IMAGE_TYPE_FPGA_A9
        BLADERF_IMAGE_TYPE_CALIBRATION
        BLADERF_IMAGE_TYPE_RX_DC_CAL
        BLADERF_IMAGE_TYPE_TX_DC_CAL
        BLADERF_IMAGE_TYPE_RX_IQ_CAL
        BLADERF_IMAGE_TYPE_TX_IQ_CAL
        BLADERF_IMAGE_TYPE_FPGA_A5

    const int BLADERF_IMAGE_MAGIC_LEN

    const int BLADERF_IMAGE_CHECKSUM_LEN

    const int BLADERF_IMAGE_RESERVED_LEN

    cdef struct bladerf_image:
        char magic[BLADERF_IMAGE_MAGIC_LEN + 1]
        uint8_t checksum[BLADERF_IMAGE_CHECKSUM_LEN]
        bladerf_version version
        uint64_t timestamp
        char serial[BLADERF_SERIAL_LENGTH + 1]
        char reserved[BLADERF_IMAGE_RESERVED_LEN]
        bladerf_image_type type
        uint32_t address
        uint32_t length
        uint8_t *data

    bladerf_image *bladerf_alloc_image(bladerf *dev, bladerf_image_type type, uint32_t address, uint32_t length)

    bladerf_image *bladerf_alloc_cal_image(bladerf *dev, bladerf_fpga_size fpga_size, uint16_t vctcxo_trim)

    void bladerf_free_image(bladerf_image *image)

    int bladerf_image_write(bladerf *dev, bladerf_image *image, const char *file)

    int bladerf_image_read(bladerf_image *image, const char *file)

    ctypedef enum bladerf_vctcxo_tamer_mode:
        BLADERF_VCTCXO_TAMER_INVALID
        BLADERF_VCTCXO_TAMER_DISABLED
        BLADERF_VCTCXO_TAMER_1_PPS
        BLADERF_VCTCXO_TAMER_10_MHZ

    int bladerf_set_vctcxo_tamer_mode(bladerf *dev, bladerf_vctcxo_tamer_mode mode)

    int bladerf_get_vctcxo_tamer_mode(bladerf *dev, bladerf_vctcxo_tamer_mode *mode)

    int bladerf_get_vctcxo_trim(bladerf *dev, uint16_t *trim)

    int bladerf_trim_dac_write(bladerf *dev, uint16_t val)

    int bladerf_trim_dac_read(bladerf *dev, uint16_t *val)

    ctypedef enum bladerf_tuning_mode:
        BLADERF_TUNING_MODE_INVALID
        BLADERF_TUNING_MODE_HOST
        BLADERF_TUNING_MODE_FPGA

    int bladerf_set_tuning_mode(bladerf *dev, bladerf_tuning_mode mode)

    int bladerf_get_tuning_mode(bladerf *dev, bladerf_tuning_mode *mode)

    int bladerf_read_trigger(bladerf *dev, int ch, bladerf_trigger_signal signal, uint8_t *val)

    int bladerf_write_trigger(bladerf *dev, int ch, bladerf_trigger_signal signal, uint8_t val)

    int bladerf_wishbone_master_read(bladerf *dev, uint32_t addr, uint32_t *data)

    int bladerf_wishbone_master_write(bladerf *dev, uint32_t addr, uint32_t val)

    int bladerf_config_gpio_read(bladerf *dev, uint32_t *val)

    int bladerf_config_gpio_write(bladerf *dev, uint32_t val)

    int bladerf_erase_flash(bladerf *dev, uint32_t erase_block, uint32_t count)

    int bladerf_erase_flash_bytes(bladerf *dev, uint32_t address, uint32_t length)

    int bladerf_read_flash(bladerf *dev, uint8_t *buf, uint32_t page, uint32_t count)

    int bladerf_read_flash_bytes(bladerf *dev, uint8_t *buf, uint32_t address, uint32_t bytes)

    int bladerf_write_flash(bladerf *dev, const uint8_t *buf, uint32_t page, uint32_t count)

    int bladerf_write_flash_bytes(bladerf *dev, const uint8_t *buf, uint32_t address, uint32_t length)

    int bladerf_lock_otp(bladerf *dev)

    int bladerf_read_otp(bladerf *dev, uint8_t *buf)

    int bladerf_write_otp(bladerf *dev, uint8_t *buf)

    int bladerf_set_rf_port(bladerf *dev, int ch, const char *port)

    int bladerf_get_rf_port(bladerf *dev, int ch, const char **port)

    int bladerf_get_rf_ports(bladerf *dev, int ch, const char **ports, unsigned int count)

    ctypedef enum bladerf_feature:
        BLADERF_FEATURE_DEFAULT
        BLADERF_FEATURE_OVERSAMPLE

    int bladerf_enable_feature(bladerf *dev, bladerf_feature feature, bint enable)

    int bladerf_get_feature(bladerf *dev, bladerf_feature *feature)

    cdef struct bladerf_gain_cal_entry:
        uint64_t freq
        double gain_corr
    
    ctypedef enum gain_cal_state:
        BLADERF_GAIN_CAL_UNINITIALIZED,
        BLADERF_GAIN_CAL_LOADED,
        BLADERF_GAIN_CAL_UNLOADED

    cdef struct bladerf_gain_cal_tbl:
        int ch
        bint enabled
        uint32_t n_entries
        uint64_t start_freq
        uint64_t stop_freq
        bladerf_gain_cal_entry *entries
        int gain_target
        size_t file_path_len
        char *filepath
        gain_cal_state state

    int bladerf_load_gain_calibration(bladerf *dev, int ch, char *cal_file_loc)

    int bladerf_enable_gain_calibration(bladerf *dev, int ch, bint en)

    int bladerf_get_gain_calibration(bladerf *dev, int ch, bladerf_gain_cal_tbl *tbl)

    int bladerf_get_gain_target(bladerf *dev, int ch, int *gain_target)

    ctypedef enum bladerf_log_level:
        BLADERF_LOG_LEVEL_VERBOSE
        BLADERF_LOG_LEVEL_DEBUG
        BLADERF_LOG_LEVEL_INFO
        BLADERF_LOG_LEVEL_WARNING
        BLADERF_LOG_LEVEL_ERROR
        BLADERF_LOG_LEVEL_CRITICAL
        BLADERF_LOG_LEVEL_SILENT

    void bladerf_log_set_verbosity(bladerf_log_level level)

    void bladerf_library_version 'bladerf_version' (bladerf_version *version)

    const char *bladerf_strerror(int error)

cdef extern from 'bladeRF2.h' nogil:
    int bladerf_get_bias_tee(bladerf *dev, int ch, bint *enable)

    int bladerf_set_bias_tee(bladerf *dev, int ch, bint enable)

    int bladerf_get_rfic_register(bladerf *dev, uint16_t address, uint8_t *val)

    int bladerf_set_rfic_register(bladerf *dev, uint16_t address, uint8_t val)

    int bladerf_get_rfic_temperature(bladerf *dev, float *val)

    int bladerf_get_rfic_rssi(bladerf *dev, int ch, int32_t *pre_rssi, int32_t *sym_rssi)

    int bladerf_get_rfic_ctrl_out(bladerf *dev, uint8_t *ctrl_out)

    ctypedef enum bladerf_rfic_rxfir:
        BLADERF_RFIC_RXFIR_BYPASS
        BLADERF_RFIC_RXFIR_CUSTOM
        BLADERF_RFIC_RXFIR_DEC1
        BLADERF_RFIC_RXFIR_DEC2
        BLADERF_RFIC_RXFIR_DEC4

    ctypedef enum bladerf_rfic_txfir:
        BLADERF_RFIC_TXFIR_BYPASS
        BLADERF_RFIC_TXFIR_CUSTOM
        BLADERF_RFIC_TXFIR_INT1
        BLADERF_RFIC_TXFIR_INT2
        BLADERF_RFIC_TXFIR_INT4

    int bladerf_get_rfic_rx_fir(bladerf *dev, bladerf_rfic_rxfir *rxfir)

    int bladerf_set_rfic_rx_fir(bladerf *dev, bladerf_rfic_rxfir rxfir)

    int bladerf_get_rfic_tx_fir(bladerf *dev, bladerf_rfic_txfir *txfir)

    int bladerf_set_rfic_tx_fir(bladerf *dev, bladerf_rfic_txfir txfir)

    int bladerf_get_pll_lock_state(bladerf *dev, bint *locked)

    int bladerf_get_pll_enable(bladerf *dev, bint *enabled)

    int bladerf_set_pll_enable(bladerf *dev, bint enable)

    int bladerf_get_pll_refclk_range(bladerf *dev, const bladerf_range **range)

    int bladerf_get_pll_refclk(bladerf *dev, uint64_t *frequency)

    int bladerf_set_pll_refclk(bladerf *dev, uint64_t frequency)

    int bladerf_get_pll_register(bladerf *dev, uint8_t address, uint32_t *val)

    int bladerf_set_pll_register(bladerf *dev, uint8_t address, uint32_t val)

    ctypedef enum bladerf_power_sources:
        BLADERF_UNKNOWN
        BLADERF_PS_DC
        BLADERF_PS_USB_VBUS

    int bladerf_get_power_source(bladerf *dev, bladerf_power_sources *val)

    ctypedef enum bladerf_clock_select:
        CLOCK_SELECT_ONBOARD
        CLOCK_SELECT_EXTERNAL

    int bladerf_get_clock_select(bladerf *dev, bladerf_clock_select *sel)

    int bladerf_set_clock_select(bladerf *dev, bladerf_clock_select sel)

    int bladerf_get_clock_output(bladerf *dev, int *state)

    int bladerf_set_clock_output(bladerf *dev, int enable)

    ctypedef enum bladerf_pmic_register:
        BLADERF_PMIC_CONFIGURATION
        BLADERF_PMIC_VOLTAGE_SHUNT
        BLADERF_PMIC_VOLTAGE_BUS
        BLADERF_PMIC_POWER
        BLADERF_PMIC_CURRENT
        BLADERF_PMIC_CALIBRATION

    int bladerf_get_pmic_register(bladerf *dev, bladerf_pmic_register reg, void *val)

    ctypedef struct bladerf_rf_switch_config:
        uint32_t tx1_rfic_port
        uint32_t tx1_spdt_port
        uint32_t tx2_rfic_port
        uint32_t tx2_spdt_port
        uint32_t rx1_rfic_port
        uint32_t rx1_spdt_port
        uint32_t rx2_rfic_port
        uint32_t rx2_spdt_port

    int bladerf_get_rf_switch_config(bladerf *dev, bladerf_rf_switch_config *config)
