#include <libbladeRF.h>
#include <pthread.h>

typedef enum {
    STREAM_IDLE,
    STREAM_RUNNING,
    STREAM_SHUTTING_DOWN,
    STREAM_DONE
} bladerf_stream_state;

struct bladerf_stream {
    struct bladerf *dev;
    bladerf_channel_layout layout;
    bladerf_format format;
    unsigned int transfer_timeout;
    bladerf_stream_cb cb;
    void *user_data;
    size_t samples_per_buffer;
    size_t num_buffers;
    void **buffers;

    pthread_mutex_t lock;

    int error_code;
    bladerf_stream_state state;
    pthread_cond_t can_submit_buffer;
    pthread_cond_t stream_started;
    void *backend_data;
};