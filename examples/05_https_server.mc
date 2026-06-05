// HTTPS server demo. Background server thread + client in main,
// connected on loopback. Raw Ed25519 server cert (curl / browsers
// won't accept it; the matching client must speak it).

@utf8_console

import pico_https;
import thread;

// Demo seed. In production, load from your secrets manager —
// losing it means rotating the server pubkey.
u8[32] DEMO_SEED = {
    0xa1, 0xb2, 0xc3, 0xd4, 0xe5, 0xf6, 0x07, 0x18,
    0x29, 0x3a, 0x4b, 0x5c, 0x6d, 0x7e, 0x8f, 0x90,
    0xa1, 0xb2, 0xc3, 0xd4, 0xe5, 0xf6, 0x07, 0x18,
    0x29, 0x3a, 0x4b, 0x5c, 0x6d, 0x7e, 0x8f, 0x90,
};

// Receives the request bytes, writes the response, returns its length.
i32 demo_handler(u8* request, i32 request_len,
                 u8* response, i32 response_cap) {
    printf("[server] received %d-byte request:\n", request_len);
    i32 head = request_len < 80 ? request_len : 80;
    for i32 i = 0; i < head; i++ { printf("%c", cast(i32, request[i])); }
    if request_len > head { printf("...\n"); }

    u8* body = cast(u8*, "Hello from picotls-minc server!\n");
    i32 body_len = cast(i32, strlen(body));
    return sprintf(response,
        cast(u8*, "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"),
        body_len, body);
}

struct ServerArg {
    u16 port_out;
    i32 result;
    bool ready;
}

private {
void server_thread_entry(void* raw) {
    ServerArg* a = cast(ServerArg*, raw);
    a.ready = true;
    a.result = pico_https_serve_once(cast(u16, 0), &a.port_out,
                                   &DEMO_SEED[0], demo_handler);
}
}

i32 main() {
    ServerArg sa = ServerArg{ .port_out = 0, .result = 0, .ready = false };

    Thread server_t;
    thread_create(&server_t, server_thread_entry, &sa);

    while !sa.ready || sa.port_out == cast(u16, 0) { thread_sleep(10); }

    printf("[client] connecting to https://127.0.0.1:%d/\n", cast(i32, sa.port_out));

    // Trust the raw Ed25519 server cert.
    ptls_verify_certificate_t vc = ptls_verify_certificate_t{};
    vc.cb = ed25519_pl_verify_cert_cb;
    vc.algos = &ed25519_pl_verify_algos[0];

    u8[4096] response;
    i32 n = pico_https_request(cast(u8*, "GET"),
                             cast(u8*, "127.0.0.1"), sa.port_out,
                             cast(u8*, "127.0.0.1"), cast(u8*, "/"),
                             &response[0], 4096,
                             null, null,
                             null, 0,
                             true,
                             null, null,
                             &vc);

    thread_join(&server_t);

    if n < 0 {
        printf("[client] pico_https_request failed: code=%d\n", n);
        return 1;
    }
    if sa.result != 0 {
        printf("[server] pico_https_serve_once failed: code=%d\n", sa.result);
        return 1;
    }

    printf("[client] received %d bytes:\n", n);
    for i32 i = 0; i < n; i++ { printf("%c", cast(i32, response[i])); }
    printf("\n[done] client and server both completed cleanly.\n");
    return 0;
}
