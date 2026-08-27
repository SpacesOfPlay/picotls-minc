

// Aligned allocation
void* _picotls_aligned_malloc(u64 size, u64 align) {
    i64 a = cast(i64, align);
    if a < 1 { a = 1; }
    i64 slot = 8;
    u8* base = cast(u8*, alloc(cast(i64, size) + a + slot));
    if base == null { return null; }
    i64 aligned = (cast(i64, base) + slot + (a - 1)) & ~(a - 1);
    void** store = cast(void**, cast(u8*, aligned - slot));
    *store = cast(void*, base);
    return cast(void*, cast(u8*, aligned));
}
void _picotls_aligned_free(void* p) {
    if p == null { return; }
    void** store = cast(void**, cast(u8*, cast(i64, p) - 8));
    free(*store);
}
i32 _picotls_posix_memalign(void** memptr, i32 alignment, u64 size) {
    ignore alignment;
    *memptr = alloc(cast(i64, size));
    if *memptr == null { return 12; }
    return 0;
}

when os(windows) {
    extern "msvcrt.dll" {
        i32 printf(u8* fmt, ...);
        i32 sprintf(u8* buf, u8* fmt, ...);
        i32 fprintf(void* stream, u8* fmt, ...);
        i64 clock();
        i32 strncmp(u8* a, u8* b, u64 n);
        i32 memcmp(void* a, void* b, u64 n);
        void* memchr(void* s, i32 c, u64 n);
        u64 strlen(u8* s);
        i32 atoi(u8* s);
        void abort();
    }
    extern "ucrtbase.dll" {
        f64 exp(f64 x);
        f64 round(f64 x);
        // snprintf / vsnprintf: provided by cvararg_shim.mc.
        // memcpy, memset: provided by the runtime.
        void* memmove(void* dst, void* src, u64 n);
    }
    // MSVC FP-usage sentinel.
    i32 _fltused = 0x9875;
    // POSIX errno; a process-wide slot (not thread-local).
    i32 errno = 0;
    // Win32 high-resolution timer. void* params so LARGE_INTEGER need
    // not be in scope; callers pass a pointer to their own.
    extern "kernel32.dll" {
        i32 QueryPerformanceFrequency(void* p);
        i32 QueryPerformanceCounter(void* p);
    }
    // MSVC bit-scan intrinsic over minc's clz builtin. Returns
    // nonzero iff mask != 0.
    u8 _BitScanReverse(u32* index, u32 mask) {
        if mask == 0 { return 0; }
        *index = cast(u32, 31 - clz(cast(i32, mask)));
        return 1;
    }
}
when os(linux) {
    extern "libc.so.6" {
        i32 printf(u8* fmt, ...);
        i32 sprintf(u8* buf, u8* fmt, ...);
        i32 fprintf(void* stream, u8* fmt, ...);
        i64 clock();
        i32 strncmp(u8* a, u8* b, u64 n);
        i32 memcmp(void* a, void* b, u64 n);
        void* memchr(void* s, i32 c, u64 n);
        u64 strlen(u8* s);
        i32 atoi(u8* s);
        // malloc, calloc, realloc, free: provided by the runtime allocator.
        void abort();
        void* memmove(void* dst, void* src, u64 n);
    }
    // glibc math functions in libm.so.6
    extern "libm.so.6" {
        f64 exp(f64 x);
        f64 round(f64 x);
    }
}
when os(android) {
    // Android Bionic
    extern "libc.so" {
        i32 printf(u8* fmt, ...);
        i32 sprintf(u8* buf, u8* fmt, ...);
        i32 fprintf(void* stream, u8* fmt, ...);
        i64 clock();
        i32 strncmp(u8* a, u8* b, u64 n);
        i32 memcmp(void* a, void* b, u64 n);
        void* memchr(void* s, i32 c, u64 n);
        u64 strlen(u8* s);
        i32 atoi(u8* s);
        void abort();
        void* memmove(void* dst, void* src, u64 n);
    }
    extern "libm.so" {
        f64 exp(f64 x);
        f64 round(f64 x);
    }
}
// Numeric constants. Values are stable across platforms.
const i32 MAX_PATH = 260;
const i32 S_IFMT = 0xF000;
const i32 S_IFREG = 0x8000;
const i32 S_IFDIR = 0x4000;
when os(macos) || os(ios) {
    // On macOS, libSystem.B.dylib provides both libc and libm.
    extern "libSystem.B.dylib" {
        i32 printf(u8* fmt, ...);
        i32 sprintf(u8* buf, u8* fmt, ...);
        i32 fprintf(void* stream, u8* fmt, ...);
        i64 clock();
        i32 strncmp(u8* a, u8* b, u64 n);
        i32 memcmp(void* a, void* b, u64 n);
        void* memchr(void* s, i32 c, u64 n);
        u64 strlen(u8* s);
        i32 atoi(u8* s);
        f64 exp(f64 x);
        f64 round(f64 x);
        // malloc, calloc, realloc, free: provided by the runtime allocator.
        void abort();
        void* memmove(void* dst, void* src, u64 n);
    }
}

// <float.h> limits + <stdlib.h> RAND_MAX, as constants.
const i32 RAND_MAX = 32767;

const f32 FLT_MAX = 3.40282347e38f;
const f32 FLT_MIN = 1.17549435e-38f;
const f32 FLT_EPSILON = 1.19209290e-7f;
const f64 DBL_MAX = 1.7976931348623157e308;
const f64 DBL_MIN = 2.2250738585072014e-308;
const f64 DBL_EPSILON = 2.2204460492503131e-16;

// <math.h> NAN / INFINITY as f32 constants.
const f32 NAN = 0.0f / 0.0f;
const f32 INFINITY = 1.0f / 0.0f;

// assert(cond): aborts on failure. Param is i64; nonzero = true.
void assert(i64 cond) {
    if cond == 0 {
        eprint("assertion failed\n");
        exit(1);
    }
}

// Count trailing zeros (64-bit). Returns 64 on 0.
i32 __builtin_ctzl(u64 x) {
    if x == 0 { return 64; }
    i32 c = 0;
    while (x & cast(u64, 1)) == 0 {
        x = x >> cast(u64, 1);
        c = c + 1;
    }
    return c;
}

// POSIX <time.h>: timespec + clock_gettime.
struct timespec { i64 tv_sec; i64 tv_nsec; }
when os(windows) {
    i32 clock_gettime(i32 clk_id, timespec* tp) {
        i64 ticks = 0;
        i64 freq = 0;
        QueryPerformanceCounter(cast(void*, &ticks));
        QueryPerformanceFrequency(cast(void*, &freq));
        if freq == 0 { tp.tv_sec = 0; tp.tv_nsec = 0; return 0; }
        tp.tv_sec = ticks / freq;
        tp.tv_nsec = (ticks % freq) * 1000000000 / freq;
        return 0;
    }
} else when os(linux) {
    extern "libc.so.6" i32 clock_gettime(i32 clk_id, void* tp);
} else when os(macos) || os(ios) {
    extern "libSystem.B.dylib" i32 clock_gettime(i32 clk_id, void* tp);
}

// <stdio.h> file I/O. SEEK_* standard ANSI values.
const i32 SEEK_SET = 0;
const i32 SEEK_CUR = 1;
const i32 SEEK_END = 2;
when os(windows) {
    extern "msvcrt.dll" {
        i64 time(i64* t);
    }
}
when os(linux) {
    extern "libc.so.6" {
        i64 time(i64* t);
    }
}
when os(macos) || os(ios) {
    extern "libSystem.B.dylib" {
        i64 time(i64* t);
    }
}


// --- wasm target ---
// libc subset for wasm.
when os(wasm) {
    // abort delegates to the JS host (which logs + stops).
    extern "env" void __wasm_abort();
    void abort() { __wasm_abort(); }

    // Math comes from the math module (it defines the wasm versions).
    import math;

    // --- memory ---
    i32 memcmp(void* a, void* b, u64 n) {
        u8* pa = cast(u8*, a); u8* pb = cast(u8*, b);
        for u64 i = 0; i < n; i = i + 1 {
            if *(pa + i) != *(pb + i) {
                return cast(i32, *(pa + i)) - cast(i32, *(pb + i));
            }
        }
        return 0;
    }
    void* memmove(void* dst, void* src, u64 n) {
        u8* d = cast(u8*, dst); u8* s = cast(u8*, src);
        if cast(i64, d) < cast(i64, s) {
            for u64 i = 0; i < n; i = i + 1 { *(d + i) = *(s + i); }
        } else {
            for u64 i = n; i > 0; i = i - 1 { *(d + (i - 1)) = *(s + (i - 1)); }
        }
        return dst;
    }
    void* memchr(void* s, i32 c, u64 n) {
        u8* p = cast(u8*, s); u8 ch = cast(u8, c);
        for u64 i = 0; i < n; i = i + 1 {
            if *(p + i) == ch { return cast(void*, p + i); }
        }
        return cast(void*, 0);
    }

    // --- strings ---
    u64 strlen(u8* s) { u64 n = 0; while *(s + n) != 0 { n = n + 1; } return n; }
    i32 strncmp(u8* a, u8* b, u64 n) {
        for u64 i = 0; i < n; i = i + 1 {
            u8 ca = *(a + i); u8 cb = *(b + i);
            if ca != cb { return cast(i32, ca) - cast(i32, cb); }
            if ca == 0 { return 0; }
        }
        return 0;
    }

    // --- time ---
    // Host monotonic clock in nanoseconds.
    extern "env" i64 clock();
    i32 clock_gettime(i32 clk_id, void* tp) {
        i64 ns = clock();
        i64* p = cast(i64*, tp);
        *p = ns / 1000000000;
        *(p + 1) = ns % 1000000000;
        return 0;
    }
    // No blocking sleep in the browser; nanosleep is a no-op.
    i32 nanosleep(void* req, void* rem) { ignore req; ignore rem; return 0; }
    i64 time(i64* t) {
        i64 s = clock() / 1000000000;
        if t != null { *t = s; }
        return s;
    }
    i32 atoi(u8* s) {
        i32 sign = 1; i32 v = 0;
        while *s == 32 || (*s >= 9 && *s <= 13) { s = s + 1; }
        if *s == 45 { sign = -1; s = s + 1; } else if *s == 43 { s = s + 1; }
        while *s >= 48 && *s <= 57 { v = v * 10 + cast(i32, *s - 48); s = s + 1; }
        return v * sign;
    }
}
