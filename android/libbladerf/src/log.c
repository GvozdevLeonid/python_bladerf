/*
 * This file is part of the bladeRF project:
 *   http://www.github.com/nuand/bladeRF
 *
 * Copyright (c) 2013 Nuand LLC.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

 #ifdef LOGGING_ENABLED
 #include <log.h>
 #include <android/log.h>
 static bladerf_log_level filter_level = BLADERF_LOG_LEVEL_INFO;
 
 void log_write(bladerf_log_level level, const char *format, ...) {
    if (level >= filter_level) {
        va_list args;
        va_start(args, format);

        int android_log_level;
        switch (level) {
            case BLADERF_LOG_LEVEL_VERBOSE:
                android_log_level = ANDROID_LOG_VERBOSE;
                break;
            case BLADERF_LOG_LEVEL_DEBUG:
                android_log_level = ANDROID_LOG_DEBUG;
                break;
            case BLADERF_LOG_LEVEL_INFO:
                android_log_level = ANDROID_LOG_INFO;
                break;
            case BLADERF_LOG_LEVEL_WARNING:
                android_log_level = ANDROID_LOG_WARN;
                break;
            case BLADERF_LOG_LEVEL_ERROR:
                android_log_level = ANDROID_LOG_ERROR;
                break;
            case BLADERF_LOG_LEVEL_CRITICAL:
                android_log_level = ANDROID_LOG_FATAL;
                break;
            default:
                android_log_level = ANDROID_LOG_DEBUG;
                break;
        }

        __android_log_vprint(android_log_level, "libbladeRF", format, args);

        va_end(args);
    }
 }

 void log_set_verbosity(bladerf_log_level level)
 {
     filter_level = level;
 }
 
 bladerf_log_level log_get_verbosity()
 {
     return filter_level;
 }
 #endif