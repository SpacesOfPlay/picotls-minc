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

when os(windows) {
    extern "msvcrt.dll" {
        void* memmove(void* dst, void* src, u64 n);
        i32 fprintf(void* stream, u8* fmt, ...);
        @must_use void* _aligned_malloc(u64 size, u64 align);
        void _aligned_free(void* p);
    }
}

