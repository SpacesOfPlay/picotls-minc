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

