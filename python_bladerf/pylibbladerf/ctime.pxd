cdef extern from *:
    """
    #include <time.h>

    #ifndef timespec_get
    #  include <time.h>
    #  include <time.h>   /* для clock_gettime */
    #  define timespec_get(ts, base)  \
         (clock_gettime(CLOCK_REALTIME, ts) == 0 ? (base) : 0)
    #endif
    """

cdef extern from "<time.h>" nogil:
    ctypedef long time_t

    struct timespec:
        time_t tv_sec
        long   tv_nsec

    int timespec_get(timespec *spec, int base)