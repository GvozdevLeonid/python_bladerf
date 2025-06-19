cdef extern from *:
    """
    #include <time.h>
    #ifdef _WIN32
        #include <windows.h>
        #include <stdint.h>

        #ifndef _TIMESPEC_DEFINED
        #define _TIMESPEC_DEFINED
        struct timespec {
            int64_t tv_sec;
            int64_t tv_nsec;
        };
        #endif

        static LARGE_INTEGER _ts_freq = {0};

        static int timespec_get(struct timespec *ts, int base) {
            if (!_ts_freq.QuadPart)
                QueryPerformanceFrequency(&_ts_freq);
            if (!ts || base != 1 /* TIME_UTC */)
                return 0;
            LARGE_INTEGER cnt;
            QueryPerformanceCounter(&cnt);
            ts->tv_sec  = cnt.QuadPart / _ts_freq.QuadPart;
            ts->tv_nsec = (long)((cnt.QuadPart % _ts_freq.QuadPart)
                         * 1000000000ULL / _ts_freq.QuadPart);
            return base;
        }

    #else
        #ifndef timespec_get
            #define timespec_get(ts, base) (clock_gettime(CLOCK_REALTIME, ts) == 0 ? (base) : 0)
        #endif
    #endif
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
