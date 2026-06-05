// HTTPS keep-alive: one TLS handshake, many requests on the same
// connection. Defaults to postman-echo.com (small JSON responses);
// the 16 KB internal buffer in pico_https_conn_request bounds each
// response.

@utf8_console

import pico_https;

i32 main() {
    u8* host = getenv(cast(u8*, "TLS_HOST"));
    u8* sni = getenv(cast(u8*, "TLS_SNI"));
    if host == null { host = cast(u8*, "postman-echo.com"); }
    if sni == null  { sni  = cast(u8*, "postman-echo.com"); }
    u16 port = cast(u16, 443);

    printf("opening one TLS connection to %s:%d\n", host, cast(i32, port));

    pico_https_conn_t conn;
    i32 open_ret = pico_https_conn_open(&conn, host, port, sni, false, null);
    if open_ret != 0 {
        printf("conn_open failed: code=%d\n", open_ret);
        return 1;
    }

    u8*[3] paths;
    paths[0] = cast(u8*, "/get?n=1");
    paths[1] = cast(u8*, "/get?n=2");
    paths[2] = cast(u8*, "/get?n=3");

    for i32 i = 0; i < 3; i++ {
        u8[65536] response;
        printf("\n[req %d] GET %s\n", i + 1, paths[i]);
        i32 n = pico_https_conn_request(&conn,
                                       cast(u8*, "GET"), paths[i],
                                       null, null,
                                       null, 0,
                                       sni,
                                       &response[0], 65536,
                                       null, null);
        if n < 0 {
            printf("[req %d] failed: code=%d\n", i + 1, n);
            pico_https_conn_close(&conn);
            return 1;
        }
        i32 eol = 0;
        while eol < n && response[eol] != cast(u8, 13) { eol = eol + 1; }
        printf("[req %d] %d bytes — ", i + 1, n);
        for i32 j = 0; j < eol; j++ { printf("%c", cast(i32, response[j])); }
        printf("\n");
    }

    pico_https_conn_close(&conn);
    printf("\n[done] 3 requests over 1 TLS handshake\n");
    return 0;
}
