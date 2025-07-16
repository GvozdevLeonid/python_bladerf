IF ANDROID:
    cdef extern from *:
        """
        #include <time.h>
        #define timespec_get(ts, base) (clock_gettime(CLOCK_REALTIME, ts) == 0 ? (base) : 0)
        """


cdef extern from "<time.h>" nogil:
    ctypedef long time_t
    struct timespec:
        time_t tv_sec
        long   tv_nsec
    int timespec_get(timespec *ts, int base)


cdef inline double get_time() nogil:
    cdef timespec ts

    if timespec_get(&ts, 1) != 1:
        return 0.0
    return  <double>ts.tv_sec + <double>ts.tv_nsec / 1000000000.0
