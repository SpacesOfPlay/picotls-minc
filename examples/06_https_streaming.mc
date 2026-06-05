// HTTPS GET with a streaming callback. Each record is delivered
// as it arrives; no caller buffer needed.

@utf8_console

import pico_https;

extern "msvcrt.dll" {
    i32 atoi(u8* s);
}

struct StreamCtx {
    i32 record_count;
    i32 total_bytes;
}

// Return false to stop early.
bool on_chunk(u8* bytes, i32 len, void* userdata) {
    StreamCtx* ctx = cast(StreamCtx*, userdata);
    ctx.record_count = ctx.record_count + 1;
    ctx.total_bytes = ctx.total_bytes + len;
    printf("[record %d] %d bytes\n", ctx.record_count, len);
    i32 sample = len < 64 ? len : 64;
    printf("  first %d bytes: ", sample);
    for i32 i = 0; i < sample; i++ {
        u8 b = bytes[i];
        if b >= cast(u8, 32) && b < cast(u8, 127) { printf("%c", cast(i32, b)); }
        else if b == cast(u8, 10) { printf("\\n"); }
        else if b == cast(u8, 13) { printf("\\r"); }
        else { printf("."); }
    }
    printf("\n");
    return true;
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

    printf("GET https://%s:%d/ (streaming, no caller buffer)\n",
           host, cast(i32, port));

    StreamCtx ctx = StreamCtx{ .record_count = 0, .total_bytes = 0 };

    i32 n = pico_https_request(cast(u8*, "GET"), host, port, sni, cast(u8*, "/"),
                             null, 0,
                             null, null,
                             null, 0,
                             false,
                             on_chunk, &ctx,
                             null);

    if n < 0 {
        printf("pico_https_request failed: code=%d\n", n);
        return 1;
    }
    printf("\n[done] %d records, %d total bytes (helper returned %d)\n",
           ctx.record_count, ctx.total_bytes, n);
    return 0;
}
