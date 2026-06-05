// HTTPS POST. No cert verification.
//
// Defaults to postman-echo.com/post, which echoes the request back
// as JSON. Override the target with TLS_HOST / TLS_PORT / TLS_SNI
// / TLS_PATH env vars; supply your own body via TLS_BODY.

@utf8_console

import pico_https;

extern "msvcrt.dll" {
    i32 atoi(u8* s);
}

i32 main() {
    u8* host = getenv(cast(u8*, "TLS_HOST"));
    u8* port_s = getenv(cast(u8*, "TLS_PORT"));
    u8* sni = getenv(cast(u8*, "TLS_SNI"));
    u8* path = getenv(cast(u8*, "TLS_PATH"));
    if host == null { host = cast(u8*, "postman-echo.com"); }
    if sni == null  { sni  = cast(u8*, "postman-echo.com"); }
    if path == null { path = cast(u8*, "/post"); }
    u16 port = cast(u16, 443);
    if port_s != null {
        i32 p = atoi(port_s);
        if p > 0 && p < 65536 { port = cast(u16, p); }
    }

    u8* body = getenv(cast(u8*, "TLS_BODY"));
    if body == null { body = cast(u8*, "{\"msg\":\"hello from picotls-minc\",\"n\":42}"); }
    i32 body_len = cast(i32, strlen(body));

    printf("POST https://%s:%d%s  (SNI=%s, %d body bytes)\n",
           host, cast(i32, port), path, sni, body_len);

    u8[65536] response;
    i32 n = pico_https_request(cast(u8*, "POST"), host, port, sni, path,
                             &response[0], 65536,
                             null,
                             cast(u8*, "Content-Type: application/json\r\n"),
                             body, body_len,
                             false,
                             null, null,
                             null);
    if n < 0 {
        printf("pico_https_request failed: code=%d\n", n);
        return 1;
    }

    printf("--- %d bytes received ---\n", n);
    i32 to_print = n < 8192 ? n : 8192;
    for i32 i = 0; i < to_print; i++ { printf("%c", cast(i32, response[i])); }
    if n > 8192 { printf("\n[... +%d more bytes truncated]\n", n - 8192); }
    printf("\n--- end ---\n");
    return 0;
}
