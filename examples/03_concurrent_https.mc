// N concurrent HTTPS GETs against one endpoint, each on its own
// thread. Configure via TLS_HOST, TLS_PORT, TLS_SNI.

@utf8_console

import pico_https;

struct HttpsThreadArg {
    u8* host;
    u16 port;
    u8* sni;
    i32 result;
}

private {
void https_thread_entry(void* raw) {
    HttpsThreadArg* a = cast(HttpsThreadArg*, raw);
    u8* buf = null;
    a.result = pico_https_get_alloc(a.host, a.port, a.sni, cast(u8*, "/"),
                                  &buf, null, null, null);
    if buf != null { free(cast(void*, buf)); }
}
}

i32 main() {
    u8* host = getenv(cast(u8*, "TLS_HOST"));
    u8* port_s = getenv(cast(u8*, "TLS_PORT"));
    u8* sni = getenv(cast(u8*, "TLS_SNI"));
    if host == null { host = cast(u8*, "www.google.com"); }
    if sni == null  { sni  = cast(u8*, "www.google.com"); }
    u16 port = cast(u16, 443);
    if port_s != null {
        i32 p = atoi(port_s);
        if p > 0 && p < 65536 { port = cast(u16, p); }
    }

    const i32 NTHREADS = 4;
    printf("Spawning %d concurrent HTTPS GETs to %s:%d (SNI=%s)\n",
           NTHREADS, host, cast(i32, port), sni);

    HttpsThreadArg[4] args;
    Thread[4] ts;
    for i32 ti = 0; ti < NTHREADS; ti++ {
        args[ti].host = host;
        args[ti].port = port;
        args[ti].sni = sni;
        args[ti].result = -999;
        thread_create(&ts[ti], https_thread_entry, &args[ti]);
    }
    for i32 ti = 0; ti < NTHREADS; ti++ { thread_join(&ts[ti]); }

    bool all_ok = true;
    for i32 ti = 0; ti < NTHREADS; ti++ {
        printf("  thread %d: %d bytes\n", ti, args[ti].result);
        if args[ti].result <= 0 { all_ok = false; }
    }
    if !all_ok {
        printf("FAIL — at least one thread errored\n");
        return 1;
    }
    printf("OK — all %d threads completed.\n", NTHREADS);
    return 0;
}
