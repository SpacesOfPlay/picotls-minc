// HTTPS GET. The default example — fetches https://www.google.com/.
// Override the target with TLS_HOST / TLS_PORT / TLS_SNI env vars.
// For authenticated GET see examples 08, 09, 10.

@utf8_console

import pico_https;

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

    printf("GET https://%s:%d/  (SNI=%s)\n", host, cast(i32, port), sni);

    // pico_https_get_alloc grows the response buffer on demand and
    // hands it back as a caller-owned malloc'd buffer.
    u8* response = null;
    i32 n = pico_https_get_alloc(host, port, sni, cast(u8*, "/"),
                        &response,
                        null, null, null);
    if n < 0 {
        printf("pico_https_get_alloc failed: code=%d\n", n);
        return 1;
    }

    printf("--- %d bytes received ---\n", n);
    i32 to_print = n < 8192 ? n : 8192;
    for i32 i = 0; i < to_print; i++ { printf("%c", cast(i32, response[i])); }
    if n > 8192 { printf("\n[... +%d more bytes truncated]\n", n - 8192); }
    printf("\n--- end ---\n");
    free(cast(void*, response));
    return 0;
}
