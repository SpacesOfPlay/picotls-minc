// Imports added on export so this module resolves standalone (LSP).
import cstdlib_shim;

// Link-time fillers for picotls.

struct timeval {
    i64 tv_sec;
    i64 tv_usec;
}

i32 gettimeofday(timeval* tv, void* tz) {
    tv.tv_sec = 0;
    tv.tv_usec = 0;
    return 0;
}

// Aligned allocation (_picotls_aligned_malloc / _picotls_aligned_free / _picotls_posix_memalign)
// is provided by cstdlib_shim, backed by the program allocator.

when os(windows) {
    extern "msvcrt.dll" {
        i32 fprintf(void* stream, u8* fmt, ...);
    }
    extern "ucrtbase.dll" {
        void* memmove(void* dst, void* src, u64 n);
    }
}
