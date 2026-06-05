// Imports added on export so this module resolves standalone (LSP).
import picotls;

// pico_https — HTTPS client + minimal server over picotls.

when os(windows) {
    extern "msvcrt.dll" { u8* getenv(u8* name); }
}
when os(linux) {
    extern "libc.so.6" { u8* getenv(u8* name); }
}
when os(macos) || os(ios) {
    extern "libSystem.B.dylib" { u8* getenv(u8* name); }
}

// Parse a dotted-quad IPv4 literal. Returns 0 on failure.
private {
u32 parse_ipv4(u8* s) {
    u32[4] parts;
    i32 pi = 0;
    u32 cur = 0;
    bool have = false;
    for u64 i = 0; true; i++ {
        u8 c = s[i];
        if c >= cast(u8, '0') && c <= cast(u8, '9') {
            cur = cur * cast(u32, 10) + cast(u32, c - cast(u8, '0'));
            have = true;
        } else if c == cast(u8, '.') || c == cast(u8, 0) {
            if !have { return cast(u32, 0); }
            if pi >= 4 { return cast(u32, 0); }
            if cur > cast(u32, 255) { return cast(u32, 0); }
            parts[pi] = cur;
            pi = pi + 1;
            cur = cast(u32, 0);
            have = false;
            if c == cast(u8, 0) { break; }
        } else {
            return cast(u32, 0);
        }
    }
    if pi != 4 { return cast(u32, 0); }
    return parts[0] | (parts[1] << 8) | (parts[2] << 16) | (parts[3] << 24);
}
}

// --- DNS (IPv4 only) ---

const i32 NET_AI_PASSIVE = 1;

when os(windows) {
    extern "ws2_32.dll" {
        i32 getaddrinfo(u8* node, u8* service, void* hints, void** res);
        void freeaddrinfo(void* res);
    }
    struct _NetAddrInfoW {
        i32 ai_flags;
        i32 ai_family;
        i32 ai_socktype;
        i32 ai_protocol;
        u64 ai_addrlen;
        u8* ai_canonname;
        void* ai_addr;
        void* ai_next;
    }
}
when os(linux) {
    extern "libc.so.6" {
        i32 getaddrinfo(u8* node, u8* service, void* hints, void** res);
        void freeaddrinfo(void* res);
    }
    struct _NetAddrInfoL {
        i32 ai_flags;
        i32 ai_family;
        i32 ai_socktype;
        i32 ai_protocol;
        u32 ai_addrlen;
        u32 _pad;
        void* ai_addr;
        u8* ai_canonname;
        void* ai_next;
    }
}
when os(macos) || os(ios) {
    extern "libSystem.B.dylib" {
        i32 getaddrinfo(u8* node, u8* service, void* hints, void** res);
        void freeaddrinfo(void* res);
    }
    struct _NetAddrInfoM {
        i32 ai_flags;
        i32 ai_family;
        i32 ai_socktype;
        i32 ai_protocol;
        u32 ai_addrlen;
        u32 _pad;
        u8* ai_canonname;
        void* ai_addr;
        void* ai_next;
    }
}

// Resolve `host` to an IPv4 address. Accepts literals and hostnames.
// Returns 0 on failure.
private {
u32 pico_resolve_ipv4(u8* host) {
    when os(windows) {
        _NetAddrInfoW hints = _NetAddrInfoW{};
        hints.ai_family = cast(i32, NET_AF_INET);
        hints.ai_socktype = NET_SOCK_STREAM;
        void* res = null;
        if getaddrinfo(host, null, &hints, &res) != 0 { return cast(u32, 0); }
        u32 ip = 0;
        _NetAddrInfoW* cur = cast(_NetAddrInfoW*, res);
        while cur != null {
            if cur.ai_family == cast(i32, NET_AF_INET) && cur.ai_addr != null {
                u8* ab = cast(u8*, cur.ai_addr);
                ip = cast(u32, ab[4])
                   | (cast(u32, ab[5]) << 8)
                   | (cast(u32, ab[6]) << 16)
                   | (cast(u32, ab[7]) << 24);
                break;
            }
            cur = cast(_NetAddrInfoW*, cur.ai_next);
        }
        freeaddrinfo(res);
        return ip;
    }
    when os(linux) {
        _NetAddrInfoL hints = _NetAddrInfoL{};
        hints.ai_family = cast(i32, NET_AF_INET);
        hints.ai_socktype = NET_SOCK_STREAM;
        void* res = null;
        if getaddrinfo(host, null, &hints, &res) != 0 { return cast(u32, 0); }
        u32 ip = 0;
        _NetAddrInfoL* cur = cast(_NetAddrInfoL*, res);
        while cur != null {
            if cur.ai_family == cast(i32, NET_AF_INET) && cur.ai_addr != null {
                u8* ab = cast(u8*, cur.ai_addr);
                ip = cast(u32, ab[4])
                   | (cast(u32, ab[5]) << 8)
                   | (cast(u32, ab[6]) << 16)
                   | (cast(u32, ab[7]) << 24);
                break;
            }
            cur = cast(_NetAddrInfoL*, cur.ai_next);
        }
        freeaddrinfo(res);
        return ip;
    }
    when os(macos) || os(ios) {
        _NetAddrInfoM hints = _NetAddrInfoM{};
        hints.ai_family = cast(i32, NET_AF_INET);
        hints.ai_socktype = NET_SOCK_STREAM;
        void* res = null;
        if getaddrinfo(host, null, &hints, &res) != 0 { return cast(u32, 0); }
        u32 ip = 0;
        _NetAddrInfoM* cur = cast(_NetAddrInfoM*, res);
        while cur != null {
            if cur.ai_family == cast(i32, NET_AF_INET) && cur.ai_addr != null {
                u8* ab = cast(u8*, cur.ai_addr);
                ip = cast(u32, ab[4])
                   | (cast(u32, ab[5]) << 8)
                   | (cast(u32, ab[6]) << 16)
                   | (cast(u32, ab[7]) << 24);
                break;
            }
            cur = cast(_NetAddrInfoM*, cur.ai_next);
        }
        freeaddrinfo(res);
        return ip;
    }
}
}

// One handshake step. Reads from the socket only when the input
// buffer is empty. Returns 0 on ok, nonzero on error.
i32 pico_https_drive_one(ptls_t* tls, Socket conn,
                       u8* recv_acc, i32* recv_len,
                       ptls_buffer_t* sendbuf, bool initial) {
    if !initial && *recv_len == 0 {
        u8[8192] tmp;
        i32 n = net_recv(conn, &tmp[0], 8192);
        if n <= 0 { return 1; }
        if *recv_len + n > 16384 { return 2; }
        for i32 i = 0; i < n; i++ { recv_acc[*recv_len + i] = tmp[i]; }
        *recv_len = *recv_len + n;
    }
    u64 consumed = cast(u64, *recv_len);
    void* input = *recv_len > 0 ? cast(void*, recv_acc) : null;
    i32 r = ptls_handshake(tls, sendbuf, input, &consumed, null);
    if r != 0 && r != 514 { return 100 + r; }
    i32 leftover = *recv_len - cast(i32, consumed);
    for i32 i = 0; i < leftover; i++ { recv_acc[i] = recv_acc[cast(i32, consumed) + i]; }
    *recv_len = leftover;
    if sendbuf.off > 0 {
        if !net_send_all(conn, sendbuf.base, cast(i32, sendbuf.off)) { return 3; }
        sendbuf.off = 0;
    }
    return 0;
}

// Return codes for pico_https_get / pico_https_request.
const i32 PICO_HTTPS_OK              = 0;
const i32 PICO_HTTPS_ERR_NET_INIT    = -1;
const i32 PICO_HTTPS_ERR_BAD_IP      = -2;
const i32 PICO_HTTPS_ERR_CONNECT     = -3;
const i32 PICO_HTTPS_ERR_PTLS_NEW    = -4;
const i32 PICO_HTTPS_ERR_HANDSHAKE   = -5;
const i32 PICO_HTTPS_ERR_SEND_REQ    = -6;
const i32 PICO_HTTPS_ERR_RECV_FAILED = -7;
const i32 PICO_HTTPS_ERR_RESP_OVERFLOW = -8;

// --- SPKI-pinned verifier (ECDSA-P256 + RSA-PSS) ---
//
// One callback that handles either cert type. Pick the leaf SPKI
// hash up front and use it for any server with the matching cert.
//
//   pinned_verify_cert_t vc = pinned_verify_cert_t{};
//   vc.super.cb    = pico_pinned_verify_cert_cb;
//   vc.super.algos = &pico_pinned_verify_algos[0];
//   // copy the 32-byte SPKI pin into vc.pinned_spki_sha256
//   pico_https_get(host, port, sni, path, ..., &vc.super);
u16[5] pico_pinned_verify_algos = { 0x0403, 0x0804, 0x0805, 0x0806, 0xffff };

i32 pico_pinned_verify_cert_cb(ptls_verify_certificate_t* self, ptls_t* tls,
                             u8* server_name, verify_sign_fn* out_verify_sign,
                             void** out_verify_data,
                             ptls_iovec_t* certs, u64 num_certs) {
    if num_certs == cast(u64, 0) { return 0 - 1; }
    i32 kt = mc_cert_leaf_key_type(certs[0].base, certs[0].len);
    if kt == 1 {
        return ecdsa_p256_pinned_verify_cert_cb(self, tls, server_name,
                                                out_verify_sign, out_verify_data,
                                                certs, num_certs);
    }
    if kt == 2 {
        return rsa_pss_pinned_verify_cert_cb(self, tls, server_name,
                                             out_verify_sign, out_verify_data,
                                             certs, num_certs);
    }
    eprint("verify: leaf key is neither P-256 nor RSA — unsupported\n");
    return 0 - 1;
}

// Streaming response callback. Called per decrypted record. Return
// true to keep going, false to stop. Pass null for buffered mode.
type pico_https_chunk_cb_fn = fn(u8*, i32, void*): bool;

// One HTTPS request. Returns bytes received, or PICO_HTTPS_ERR_*.
//
// method        — "GET", "POST", "PUT", ...
// host          — IPv4 literal or hostname.
// sni           — server_name extension value.
// path          — starts with `/`.
// out / out_cap — response buffer when on_chunk is null.
// user_agent_or_null    — defaults to "picotls-minc/0.1".
// extra_headers_or_null — verbatim header lines (caller-owned CRLFs).
// body / body_len       — request body. Pass null + 0 for none.
// use_raw_public_keys   — true when talking to a raw-pubkey server.
// on_chunk_or_null      — streaming callback (null = buffered).
// verify_or_null        — picotls verify struct (null skips verify).
i32 pico_https_request(u8* method, u8* host, u16 port, u8* sni, u8* path,
                     u8* out, i32 out_cap,
                     u8* user_agent_or_null,
                     u8* extra_headers_or_null,
                     u8* body_or_null, i32 body_len,
                     bool use_raw_public_keys,
                     pico_https_chunk_cb_fn on_chunk_or_null,
                     void* chunk_userdata,
                     ptls_verify_certificate_t* verify_or_null) {
    if !net_init() { return PICO_HTTPS_ERR_NET_INIT; }

    u32 ip = pico_resolve_ipv4(host);
    if ip == cast(u32, 0) { return PICO_HTTPS_ERR_BAD_IP; }

    ptls_key_exchange_algorithm_t kx_x25519 = ptls_key_exchange_algorithm_t{
        .id = cast(u16, 29),
        .create = x25519_pl_create,
        .exchange = x25519_pl_exchange,
        .data = cast(i64, 0),
        .name = "x25519",
    };
    ptls_aead_algorithm_t aead_aes128gcm = ptls_aead_algorithm_t{
        .name = "AES128-GCM",
        .confidentiality_limit = cast(u64, 16777216),
        .integrity_limit = cast(u64, 68719476736),
        .ctr_cipher = null,
        .ecb_cipher = null,
        .key_size = cast(u64, 16),
        .iv_size = cast(u64, 12),
        .tag_size = cast(u64, 16),
        .tls12 = { .fixed_iv_size = cast(u64, 4), .record_iv_size = cast(u64, 8) },
        .non_temporal = cast(u32, 0),
        .align_bits = cast(u8, 0),
        .context_size = sizeof(aesgcm_picotls_ctx_t),
        .setup_crypto = aesgcm_pl_setup_crypto_128,
    };
    ptls_aead_algorithm_t aead_aes256gcm = ptls_aead_algorithm_t{
        .name = "AES256-GCM",
        .confidentiality_limit = cast(u64, 16777216),
        .integrity_limit = cast(u64, 68719476736),
        .ctr_cipher = null,
        .ecb_cipher = null,
        .key_size = cast(u64, 32),
        .iv_size = cast(u64, 12),
        .tag_size = cast(u64, 16),
        .tls12 = { .fixed_iv_size = cast(u64, 4), .record_iv_size = cast(u64, 8) },
        .non_temporal = cast(u32, 0),
        .align_bits = cast(u8, 0),
        .context_size = sizeof(aesgcm_picotls_ctx_t),
        .setup_crypto = aesgcm_pl_setup_crypto_256,
    };
    ptls_aead_algorithm_t aead_chapoly = ptls_aead_algorithm_t{
        .name = "CHACHA20-POLY1305",
        .confidentiality_limit = cast(u64, 0 - 1),
        .integrity_limit = cast(u64, 68719476736),
        .ctr_cipher = null,
        .ecb_cipher = null,
        .key_size = cast(u64, 32),
        .iv_size = cast(u64, 12),
        .tag_size = cast(u64, 16),
        .tls12 = { .fixed_iv_size = cast(u64, 12), .record_iv_size = cast(u64, 0) },
        .non_temporal = cast(u32, 0),
        .align_bits = cast(u8, 0),
        .context_size = sizeof(chapoly_picotls_ctx_t),
        .setup_crypto = chapoly_pl_setup_crypto,
    };
    ptls_cipher_suite_t cs_aes128_sha256 = ptls_cipher_suite_t{
        .id = cast(u16, 4865),
        .aead = &aead_aes128gcm,
        .hash = cast(ptls_hash_algorithm_t*, &ptls_minicrypto_sha256),
        .name = "TLS_AES_128_GCM_SHA256",
    };
    ptls_cipher_suite_t cs_aes256_sha384 = ptls_cipher_suite_t{
        .id = cast(u16, 4866),
        .aead = &aead_aes256gcm,
        .hash = cast(ptls_hash_algorithm_t*, &ptls_minicrypto_sha384),
        .name = "TLS_AES_256_GCM_SHA384",
    };
    ptls_cipher_suite_t cs_chapoly_sha256 = ptls_cipher_suite_t{
        .id = cast(u16, 4867),
        .aead = &aead_chapoly,
        .hash = cast(ptls_hash_algorithm_t*, &ptls_minicrypto_sha256),
        .name = "TLS_CHACHA20_POLY1305_SHA256",
    };
    ptls_key_exchange_algorithm_t*[2] keyex_list;
    keyex_list[0] = &kx_x25519;
    keyex_list[1] = null;
    ptls_cipher_suite_t*[4] cs_list;
    cs_list[0] = &cs_aes128_sha256;
    cs_list[1] = &cs_aes256_sha384;
    cs_list[2] = &cs_chapoly_sha256;
    cs_list[3] = null;

    ptls_context_t ctx = ptls_context_t{};
    ctx.random_bytes = mc_csprng_bytes;
    ctx.get_time = &mc_picotls_get_time;
    ctx.key_exchanges = &keyex_list[0];
    ctx.cipher_suites = &cs_list[0];
    if use_raw_public_keys { ctx.use_raw_public_keys = cast(u32, 1); }

    if verify_or_null != null {
        ctx.verify_certificate = verify_or_null;
    }

    Socket sock = net_connect(ip, port);
    if !sock.valid { return PICO_HTTPS_ERR_CONNECT; }

    ptls_t* tls = ptls_new(&ctx, 0);
    if tls == null { net_close(sock); return PICO_HTTPS_ERR_PTLS_NEW; }
    ptls_set_server_name(tls, sni, strlen(sni));

    ptls_buffer_t sb;
    u8[4096] sb_small;
    ptls_buffer_init(&sb, &sb_small[0], 4096);
    u8[16384] recv_acc;
    i32 recv_len = 0;

    i32 e0 = pico_https_drive_one(tls, sock, &recv_acc[0], &recv_len, &sb, true);
    if e0 != 0 { ptls_free(tls); net_close(sock); return PICO_HTTPS_ERR_HANDSHAKE; }
    while ptls_handshake_is_complete(tls) == 0 {
        i32 e = pico_https_drive_one(tls, sock, &recv_acc[0], &recv_len, &sb, false);
        if e != 0 { ptls_free(tls); net_close(sock); return PICO_HTTPS_ERR_HANDSHAKE; }
    }

    // Build request line + headers.
    u8[2048] req_buf;
    u64 req_len = 0;
    for u64 i = 0; method[i] != cast(u8, 0); i++ { req_buf[req_len++] = method[i]; }
    req_buf[req_len++] = cast(u8, 32);
    for u64 i = 0; path[i] != cast(u8, 0); i++ { req_buf[req_len++] = path[i]; }
    u8* p2 = cast(u8*, " HTTP/1.0\r\nHost: ");
    for u64 i = 0; p2[i] != cast(u8, 0); i++ { req_buf[req_len++] = p2[i]; }
    for u64 i = 0; sni[i] != cast(u8, 0); i++ { req_buf[req_len++] = sni[i]; }
    u8* p3 = cast(u8*, "\r\nUser-Agent: ");
    for u64 i = 0; p3[i] != cast(u8, 0); i++ { req_buf[req_len++] = p3[i]; }
    u8* ua = user_agent_or_null != null ? user_agent_or_null : cast(u8*, "picotls-minc/0.1");
    for u64 i = 0; ua[i] != cast(u8, 0); i++ { req_buf[req_len++] = ua[i]; }
    u8* p4 = cast(u8*, "\r\nConnection: close\r\n");
    for u64 i = 0; p4[i] != cast(u8, 0); i++ { req_buf[req_len++] = p4[i]; }
    if body_or_null != null && body_len > 0 {
        u8[64] cl_buf;
        i32 cl_n = sprintf(&cl_buf[0], cast(u8*, "Content-Length: %d\r\n"), body_len);
        for i32 i = 0; i < cl_n; i++ { req_buf[req_len++] = cl_buf[i]; }
    }
    if extra_headers_or_null != null {
        u8* xh = extra_headers_or_null;
        for u64 i = 0; xh[i] != cast(u8, 0); i++ { req_buf[req_len++] = xh[i]; }
    }
    req_buf[req_len++] = cast(u8, 13);
    req_buf[req_len++] = cast(u8, 10);

    i32 sr = ptls_send(tls, &sb, &req_buf[0], req_len);
    if sr != 0 {
        ptls_buffer_dispose(&sb); ptls_free(tls); net_close(sock);
        return PICO_HTTPS_ERR_SEND_REQ;
    }
    if !net_send_all(sock, sb.base, cast(i32, sb.off)) {
        ptls_buffer_dispose(&sb); ptls_free(tls); net_close(sock);
        return PICO_HTTPS_ERR_SEND_REQ;
    }
    sb.off = 0;

    if body_or_null != null && body_len > 0 {
        i32 br = ptls_send(tls, &sb, body_or_null, cast(u64, body_len));
        if br != 0 {
            ptls_buffer_dispose(&sb); ptls_free(tls); net_close(sock);
            return PICO_HTTPS_ERR_SEND_REQ;
        }
        if !net_send_all(sock, sb.base, cast(i32, sb.off)) {
            ptls_buffer_dispose(&sb); ptls_free(tls); net_close(sock);
            return PICO_HTTPS_ERR_SEND_REQ;
        }
        sb.off = 0;
    }

    // Receive loop.
    ptls_buffer_t db;
    u8[16384] db_small;
    ptls_buffer_init(&db, &db_small[0], 16384);
    i32 total = 0;
    recv_len = 0;
    bool done = false;
    bool overflowed = false;
    while !done {
        if recv_len == 0 {
            u8[8192] tmp;
            i32 n = net_recv(sock, &tmp[0], 8192);
            if n <= 0 { done = true; break; }
            for i32 i = 0; i < n; i++ { recv_acc[i] = tmp[i]; }
            recv_len = n;
        }
        u64 consumed = cast(u64, recv_len);
        db.off = 0;
        i32 r = ptls_receive(tls, &db, &recv_acc[0], &consumed);
        if r != 0 && r != 514 { done = true; }
        i32 leftover = recv_len - cast(i32, consumed);
        for i32 i = 0; i < leftover; i++ { recv_acc[i] = recv_acc[cast(i32, consumed) + i]; }
        recv_len = leftover;
        if db.off > 0 {
            if on_chunk_or_null != null {
                bool keep_going = on_chunk_or_null(db.base, cast(i32, db.off), chunk_userdata);
                total = total + cast(i32, db.off);
                if !keep_going { done = true; }
            } else {
                i32 room = out_cap - total;
                if room <= 0 { overflowed = true; }
                else {
                    i32 to_copy = cast(i32, db.off) < room ? cast(i32, db.off) : room;
                    for i32 i = 0; i < to_copy; i++ { out[total + i] = db.base[i]; }
                    total = total + to_copy;
                    if cast(i32, db.off) > room { overflowed = true; }
                }
            }
        }
    }

    ptls_buffer_dispose(&db);
    ptls_buffer_dispose(&sb);
    ptls_free(tls);
    net_close(sock);

    if overflowed { return PICO_HTTPS_ERR_RESP_OVERFLOW; }
    return total;
}

// GET helper. Same return codes as pico_https_request.
i32 pico_https_get(u8* host, u16 port, u8* sni, u8* path,
                 u8* out, i32 out_cap,
                 u8* user_agent_or_null,
                 u8* extra_headers_or_null,
                 ptls_verify_certificate_t* verify_or_null) {
    return pico_https_request(cast(u8*, "GET"), host, port, sni, path,
                            out, out_cap,
                            user_agent_or_null, extra_headers_or_null,
                            null, 0,
                            false,
                            null, null,
                            verify_or_null);
}

// Growable buffer backing pico_https_get_alloc.
struct pico_growbuf_t {
    u8* buf;
    i32 len;
    i32 cap;
    bool oom;
}

private {
bool pico_growbuf_chunk(u8* data, i32 n, void* ud) {
    pico_growbuf_t* g = cast(pico_growbuf_t*, ud);
    if g.len + n > g.cap {
        i32 newcap = g.cap == 0 ? 16384 : g.cap;
        while newcap < g.len + n { newcap = newcap * 2; }
        u8* nb = cast(u8*, realloc(cast(void*, g.buf), cast(u64, newcap)));
        if nb == null { g.oom = true; return false; }
        g.buf = nb;
        g.cap = newcap;
    }
    for i32 i = 0; i < n; i++ { g.buf[g.len + i] = data[i]; }
    g.len = g.len + n;
    return true;
}
}

// GET into a buffer that grows on demand. On success, *out_ptr is a
// malloc'd buffer the caller MUST free(). On failure, *out_ptr is null.
i32 pico_https_get_alloc(u8* host, u16 port, u8* sni, u8* path,
                       u8** out_ptr,
                       u8* user_agent_or_null,
                       u8* extra_headers_or_null,
                       ptls_verify_certificate_t* verify_or_null) {
    pico_growbuf_t g = pico_growbuf_t{};
    i32 r = pico_https_request(cast(u8*, "GET"), host, port, sni, path,
                             null, 0,
                             user_agent_or_null, extra_headers_or_null,
                             null, 0,
                             false,
                             pico_growbuf_chunk, cast(void*, &g),
                             verify_or_null);
    if r < 0 || g.oom {
        if g.buf != null { free(cast(void*, g.buf)); }
        *out_ptr = null;
        return r < 0 ? r : PICO_HTTPS_ERR_RESP_OVERFLOW;
    }
    *out_ptr = g.buf;
    return g.len;
}

// --- Keep-alive connection (HTTP/1.1) ---
//
// One handshake, many requests against the same host.
//
//   pico_https_conn_t conn;
//   if pico_https_conn_open(&conn, "example.com", 443, "example.com",
//                         false, null) != 0 { ... }
//   defer pico_https_conn_close(&conn);
//   pico_https_conn_request(&conn, "GET", "/a", ..., out1, cap1, ...);
//   pico_https_conn_request(&conn, "GET", "/b", ..., out2, cap2, ...);

struct pico_https_conn_t {
    Socket sock;
    ptls_t* tls;
    ptls_buffer_t sb;
    u8[4096] sb_small;
    u8[16384] recv_acc;
    i32 recv_len;
    // Algorithm storage. ctx holds pointers into these fields.
    ptls_key_exchange_algorithm_t kx_x25519;
    ptls_aead_algorithm_t aead_aes128gcm;
    ptls_cipher_suite_t cs_aes128_sha256;
    ptls_key_exchange_algorithm_t*[2] keyex_list;
    ptls_cipher_suite_t*[2] cs_list;
    ptls_context_t ctx;
    bool valid;
}

i32 pico_https_conn_open(pico_https_conn_t* conn,
                       u8* host, u16 port, u8* sni,
                       bool use_raw_public_keys,
                       ptls_verify_certificate_t* verify_or_null) {
    conn.valid = false;
    if !net_init() { return PICO_HTTPS_ERR_NET_INIT; }
    u32 ip = pico_resolve_ipv4(host);
    if ip == cast(u32, 0) { return PICO_HTTPS_ERR_BAD_IP; }

    conn.kx_x25519 = ptls_key_exchange_algorithm_t{
        .id = cast(u16, 29), .create = x25519_pl_create,
        .exchange = x25519_pl_exchange, .data = cast(i64, 0),
        .name = "x25519",
    };
    conn.aead_aes128gcm = ptls_aead_algorithm_t{
        .name = "AES128-GCM",
        .confidentiality_limit = cast(u64, 16777216),
        .integrity_limit = cast(u64, 68719476736),
        .ctr_cipher = null, .ecb_cipher = null,
        .key_size = cast(u64, 16), .iv_size = cast(u64, 12), .tag_size = cast(u64, 16),
        .tls12 = { .fixed_iv_size = cast(u64, 4), .record_iv_size = cast(u64, 8) },
        .non_temporal = cast(u32, 0), .align_bits = cast(u8, 0),
        .context_size = sizeof(aesgcm_picotls_ctx_t),
        .setup_crypto = aesgcm_pl_setup_crypto_128,
    };
    conn.cs_aes128_sha256 = ptls_cipher_suite_t{
        .id = cast(u16, 4865), .aead = &conn.aead_aes128gcm,
        .hash = cast(ptls_hash_algorithm_t*, &ptls_minicrypto_sha256),
        .name = "TLS_AES_128_GCM_SHA256",
    };
    conn.keyex_list[0] = &conn.kx_x25519;
    conn.keyex_list[1] = null;
    conn.cs_list[0] = &conn.cs_aes128_sha256;
    conn.cs_list[1] = null;

    conn.ctx = ptls_context_t{};
    conn.ctx.random_bytes = mc_csprng_bytes;
    conn.ctx.get_time = &mc_picotls_get_time;
    conn.ctx.key_exchanges = &conn.keyex_list[0];
    conn.ctx.cipher_suites = &conn.cs_list[0];
    if use_raw_public_keys { conn.ctx.use_raw_public_keys = cast(u32, 1); }
    if verify_or_null != null { conn.ctx.verify_certificate = verify_or_null; }

    conn.sock = net_connect(ip, port);
    if !conn.sock.valid { return PICO_HTTPS_ERR_CONNECT; }

    conn.tls = ptls_new(&conn.ctx, 0);
    if conn.tls == null { net_close(conn.sock); return PICO_HTTPS_ERR_PTLS_NEW; }
    ptls_set_server_name(conn.tls, sni, strlen(sni));

    ptls_buffer_init(&conn.sb, &conn.sb_small[0], 4096);
    conn.recv_len = 0;

    i32 e0 = pico_https_drive_one(conn.tls, conn.sock, &conn.recv_acc[0],
                                &conn.recv_len, &conn.sb, true);
    if e0 != 0 {
        ptls_free(conn.tls); net_close(conn.sock);
        return PICO_HTTPS_ERR_HANDSHAKE;
    }
    while ptls_handshake_is_complete(conn.tls) == 0 {
        i32 e = pico_https_drive_one(conn.tls, conn.sock, &conn.recv_acc[0],
                                   &conn.recv_len, &conn.sb, false);
        if e != 0 {
            ptls_buffer_dispose(&conn.sb);
            ptls_free(conn.tls); net_close(conn.sock);
            return PICO_HTTPS_ERR_HANDSHAKE;
        }
    }
    conn.valid = true;
    return 0;
}

void pico_https_conn_close(pico_https_conn_t* conn) {
    if !conn.valid { return; }
    ptls_buffer_dispose(&conn.sb);
    ptls_free(conn.tls);
    net_close(conn.sock);
    conn.valid = false;
}

private {
i32 parse_decimal_at(u8* buf, i32 buf_len, i32* off) {
    i32 v = -1;
    i32 i = *off;
    while i < buf_len && buf[i] >= cast(u8, 48) && buf[i] <= cast(u8, 57) {
        if v < 0 { v = 0; }
        v = v * 10 + cast(i32, buf[i] - cast(u8, 48));
        i = i + 1;
    }
    *off = i;
    return v;
}
}

private {
i32 pico_parse_hex(u8* buf, i32 pos, i32 eol) {
    i32 v = 0 - 1;
    i32 q = pos;
    while q < eol {
        u8 c = buf[q];
        i32 d = 0 - 1;
        if c >= cast(u8, 48) && c <= cast(u8, 57) { d = cast(i32, c) - 48; }
        else if c >= cast(u8, 97) && c <= cast(u8, 102) { d = cast(i32, c) - 87; }
        else if c >= cast(u8, 65) && c <= cast(u8, 70) { d = cast(i32, c) - 55; }
        else { break; }
        if v < 0 { v = 0; }
        v = v * 16 + d;
        q = q + 1;
    }
    return v;
}
}

// Locate the end of a chunked body. -1 = need more data, -2 = malformed.
private {
i32 pico_chunked_body_end(u8* buf, i32 start, i32 len) {
    i32 pos = start;
    while true {
        i32 eol = pos;
        while eol + 1 < len && !(buf[eol] == cast(u8, 13) && buf[eol + 1] == cast(u8, 10)) {
            eol = eol + 1;
        }
        if eol + 1 >= len { return 0 - 1; }
        i32 size = pico_parse_hex(buf, pos, eol);
        if size < 0 { return 0 - 2; }
        if size == 0 {
            i32 t = eol;
            while t + 3 < len {
                if buf[t] == cast(u8, 13) && buf[t + 1] == cast(u8, 10)
                   && buf[t + 2] == cast(u8, 13) && buf[t + 3] == cast(u8, 10) {
                    return t + 4;
                }
                t = t + 1;
            }
            return 0 - 1;
        }
        i32 next = eol + 2 + size + 2;
        if next > len { return 0 - 1; }
        pos = next;
    }
}
}

// Send one request on an open conn and read the response.
// Honors Content-Length or Transfer-Encoding: chunked. Returns
// total bytes delivered (status line + headers + body) or PICO_HTTPS_ERR_*.
i32 pico_https_conn_request(pico_https_conn_t* conn,
                          u8* method, u8* path,
                          u8* user_agent_or_null,
                          u8* extra_headers_or_null,
                          u8* body_or_null, i32 body_len,
                          u8* sni_for_host_header,
                          u8* out, i32 out_cap,
                          pico_https_chunk_cb_fn on_chunk_or_null,
                          void* chunk_userdata) {
    if !conn.valid { return PICO_HTTPS_ERR_PTLS_NEW; }

    u8[2048] req_buf;
    u64 req_len = 0;
    for u64 i = 0; method[i] != cast(u8, 0); i++ { req_buf[req_len++] = method[i]; }
    req_buf[req_len++] = cast(u8, 32);
    for u64 i = 0; path[i] != cast(u8, 0); i++ { req_buf[req_len++] = path[i]; }
    u8* p2 = cast(u8*, " HTTP/1.1\r\nHost: ");
    for u64 i = 0; p2[i] != cast(u8, 0); i++ { req_buf[req_len++] = p2[i]; }
    for u64 i = 0; sni_for_host_header[i] != cast(u8, 0); i++ { req_buf[req_len++] = sni_for_host_header[i]; }
    u8* p3 = cast(u8*, "\r\nUser-Agent: ");
    for u64 i = 0; p3[i] != cast(u8, 0); i++ { req_buf[req_len++] = p3[i]; }
    u8* ua = user_agent_or_null != null ? user_agent_or_null : cast(u8*, "picotls-minc/0.1");
    for u64 i = 0; ua[i] != cast(u8, 0); i++ { req_buf[req_len++] = ua[i]; }
    u8* p4 = cast(u8*, "\r\nConnection: keep-alive\r\n");
    for u64 i = 0; p4[i] != cast(u8, 0); i++ { req_buf[req_len++] = p4[i]; }
    if body_or_null != null && body_len > 0 {
        u8[64] cl_buf;
        i32 cl_n = sprintf(&cl_buf[0], cast(u8*, "Content-Length: %d\r\n"), body_len);
        for i32 i = 0; i < cl_n; i++ { req_buf[req_len++] = cl_buf[i]; }
    }
    if extra_headers_or_null != null {
        u8* xh = extra_headers_or_null;
        for u64 i = 0; xh[i] != cast(u8, 0); i++ { req_buf[req_len++] = xh[i]; }
    }
    req_buf[req_len++] = cast(u8, 13);
    req_buf[req_len++] = cast(u8, 10);

    conn.sb.off = 0;
    if ptls_send(conn.tls, &conn.sb, &req_buf[0], req_len) != 0 {
        return PICO_HTTPS_ERR_SEND_REQ;
    }
    if !net_send_all(conn.sock, conn.sb.base, cast(i32, conn.sb.off)) {
        return PICO_HTTPS_ERR_SEND_REQ;
    }
    conn.sb.off = 0;
    if body_or_null != null && body_len > 0 {
        if ptls_send(conn.tls, &conn.sb, body_or_null, cast(u64, body_len)) != 0 {
            return PICO_HTTPS_ERR_SEND_REQ;
        }
        if !net_send_all(conn.sock, conn.sb.base, cast(i32, conn.sb.off)) {
            return PICO_HTTPS_ERR_SEND_REQ;
        }
        conn.sb.off = 0;
    }

    ptls_buffer_t db;
    u8[16384] db_small;
    ptls_buffer_init(&db, &db_small[0], 16384);

    u8[16384] acc;
    i32 acc_len = 0;
    i32 headers_end = -1;
    i32 content_length = -1;
    bool chunked = false;
    bool overflowed_acc = false;

    while true {
        if conn.recv_len == 0 {
            u8[8192] tmp;
            i32 n = net_recv(conn.sock, &tmp[0], 8192);
            if n <= 0 { break; }
            for i32 i = 0; i < n; i++ { conn.recv_acc[i] = tmp[i]; }
            conn.recv_len = n;
        }
        u64 consumed = cast(u64, conn.recv_len);
        db.off = 0;
        i32 r = ptls_receive(conn.tls, &db, &conn.recv_acc[0], &consumed);
        if r != 0 && r != 514 { break; }
        i32 leftover = conn.recv_len - cast(i32, consumed);
        for i32 i = 0; i < leftover; i++ { conn.recv_acc[i] = conn.recv_acc[cast(i32, consumed) + i]; }
        conn.recv_len = leftover;

        if db.off > 0 {
            for u64 i = 0; i < db.off; i++ {
                if acc_len < 16384 { acc[acc_len++] = db.base[i]; }
                else { overflowed_acc = true; }
            }
            if headers_end < 0 {
                for i32 i = 3; i < acc_len; i++ {
                    if acc[i - 3] == cast(u8, 13) && acc[i - 2] == cast(u8, 10)
                       && acc[i - 1] == cast(u8, 13) && acc[i] == cast(u8, 10) {
                        headers_end = i + 1;
                        break;
                    }
                }
                if headers_end >= 0 {
                    u8* tag = cast(u8*, "Content-Length:");
                    i32 tag_len = 15;
                    i32 hi = 0;
                    while hi <= headers_end - tag_len {
                        bool match = true;
                        for i32 j = 0; j < tag_len; j++ {
                            u8 a = acc[hi + j];
                            u8 b = tag[j];
                            if a >= cast(u8, 65) && a <= cast(u8, 90) { a = cast(u8, cast(i32, a) + 32); }
                            if b >= cast(u8, 65) && b <= cast(u8, 90) { b = cast(u8, cast(i32, b) + 32); }
                            if a != b { match = false; break; }
                        }
                        if match {
                            i32 off = hi + tag_len;
                            while off < headers_end {
                                if acc[off] != cast(u8, 32) { break; }
                                off = off + 1;
                            }
                            content_length = parse_decimal_at(&acc[0], headers_end, &off);
                            break;
                        }
                        hi = hi + 1;
                    }
                    u8* te_tag = cast(u8*, "transfer-encoding:");
                    i32 te_len = 18;
                    i32 ti2 = 0;
                    while ti2 <= headers_end - te_len {
                        bool tmatch = true;
                        for i32 j = 0; j < te_len; j++ {
                            u8 a = acc[ti2 + j];
                            if a >= cast(u8, 65) && a <= cast(u8, 90) { a = cast(u8, cast(i32, a) + 32); }
                            if a != te_tag[j] { tmatch = false; break; }
                        }
                        if tmatch {
                            i32 ve = ti2 + te_len;
                            i32 vend = ve;
                            while vend + 1 < headers_end && !(acc[vend] == cast(u8, 13) && acc[vend + 1] == cast(u8, 10)) { vend = vend + 1; }
                            u8* ck = cast(u8*, "chunked");
                            i32 ck_len = 7;
                            i32 ci = ve;
                            while ci <= vend - ck_len {
                                bool cmatch = true;
                                for i32 j = 0; j < ck_len; j++ {
                                    u8 a = acc[ci + j];
                                    if a >= cast(u8, 65) && a <= cast(u8, 90) { a = cast(u8, cast(i32, a) + 32); }
                                    if a != ck[j] { cmatch = false; break; }
                                }
                                if cmatch { chunked = true; break; }
                                ci = ci + 1;
                            }
                            break;
                        }
                        ti2 = ti2 + 1;
                    }
                    if content_length < 0 { content_length = 0; }
                }
            }
        }
        if overflowed_acc { break; }
        if headers_end >= 0 {
            if chunked {
                if pico_chunked_body_end(&acc[0], headers_end, acc_len) >= 0 { break; }
            } else {
                i32 expected = headers_end + (content_length > 0 ? content_length : 0);
                if acc_len >= expected { break; }
            }
        }
    }

    // Decode chunked body in place.
    if chunked && headers_end >= 0 {
        i32 body_end = pico_chunked_body_end(&acc[0], headers_end, acc_len);
        i32 raw_end = body_end >= 0 ? body_end : acc_len;
        i32 rpos = headers_end;
        i32 wpos = headers_end;
        while rpos < raw_end {
            i32 eol = rpos;
            while eol + 1 < raw_end && !(acc[eol] == cast(u8, 13) && acc[eol + 1] == cast(u8, 10)) { eol = eol + 1; }
            if eol + 1 >= raw_end { break; }
            i32 size = pico_parse_hex(&acc[0], rpos, eol);
            if size <= 0 { break; }
            i32 ds = eol + 2;
            if ds + size > raw_end { size = raw_end - ds; }
            for i32 i = 0; i < size; i++ { acc[wpos + i] = acc[ds + i]; }
            wpos = wpos + size;
            rpos = ds + size + 2;
        }
        acc_len = wpos;
        content_length = wpos - headers_end;
    }

    i32 to_deliver = acc_len;
    if headers_end >= 0 && content_length >= 0 {
        i32 expected = headers_end + content_length;
        if to_deliver > expected { to_deliver = expected; }
    }
    bool overflowed = overflowed_acc;
    i32 total_delivered = 0;
    if on_chunk_or_null != null {
        bool _ok = on_chunk_or_null(&acc[0], to_deliver, chunk_userdata);
        total_delivered = to_deliver;
    } else {
        i32 to_copy = to_deliver < out_cap ? to_deliver : out_cap;
        for i32 i = 0; i < to_copy; i++ { out[i] = acc[i]; }
        total_delivered = to_copy;
        if to_deliver > out_cap { overflowed = true; }
    }

    ptls_buffer_dispose(&db);

    if overflowed { return PICO_HTTPS_ERR_RESP_OVERFLOW; }
    return total_delivered;
}

// --- Single-connection HTTPS server ---
//
// Accepts one connection, handshakes with a raw-Ed25519 "cert"
// derived from `ed25519_seed`, runs the handler once, closes.
// Pass port = 0 to let the OS pick; *port_out_or_null receives it.
//
// Raw-Ed25519 server certs won't work with browsers or curl. The
// matching client sets use_raw_public_keys and uses the Ed25519
// verifier.

type pico_https_handler_fn = fn(u8*, i32, u8*, i32): i32;

i32 pico_https_serve_once(u16 port, u16* port_out_or_null,
                        u8* ed25519_seed,
                        pico_https_handler_fn handler) {
    if !net_init() { return PICO_HTTPS_ERR_NET_INIT; }

    Socket listener = net_listen_tcp(port);
    if !listener.valid { return PICO_HTTPS_ERR_CONNECT; }
    if port_out_or_null != null {
        *port_out_or_null = net_socket_port(listener);
    }

    Socket conn = net_accept(listener);
    net_close(listener);
    if !conn.valid { return PICO_HTTPS_ERR_CONNECT; }

    // 44-byte SPKI-wrapped Ed25519 server pubkey.
    u8[64] srv_sk;
    u8[32] srv_pk;
    crypto_eddsa_key_pair(&srv_sk[0], &srv_pk[0], ed25519_seed);
    u8[44] srv_cert_der;
    u8[12] spki_prefix = {
        0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65,
        0x70, 0x03, 0x21, 0x00,
    };
    for u64 i = 0; i < 12; i++ { srv_cert_der[i] = spki_prefix[i]; }
    for u64 i = 0; i < 32; i++ { srv_cert_der[12 + i] = srv_pk[i]; }
    ptls_iovec_t[1] srv_certs;
    srv_certs[0] = ptls_iovec_init(&srv_cert_der[0], 44);
    sign_cert_ctx_t srv_sign_ctx = sign_cert_ctx_t{
        .super = ptls_sign_certificate_t{ .cb = ed25519_pl_sign_certificate },
    };
    for u64 i = 0; i < 64; i++ { srv_sign_ctx.secret_key[i] = srv_sk[i]; }

    ptls_key_exchange_algorithm_t kx_x25519 = ptls_key_exchange_algorithm_t{
        .id = cast(u16, 29),
        .create = x25519_pl_create,
        .exchange = x25519_pl_exchange,
        .data = cast(i64, 0),
        .name = "x25519",
    };
    ptls_aead_algorithm_t aead_aes128gcm = ptls_aead_algorithm_t{
        .name = "AES128-GCM",
        .confidentiality_limit = cast(u64, 16777216),
        .integrity_limit = cast(u64, 68719476736),
        .ctr_cipher = null, .ecb_cipher = null,
        .key_size = cast(u64, 16), .iv_size = cast(u64, 12), .tag_size = cast(u64, 16),
        .tls12 = { .fixed_iv_size = cast(u64, 4), .record_iv_size = cast(u64, 8) },
        .non_temporal = cast(u32, 0), .align_bits = cast(u8, 0),
        .context_size = sizeof(aesgcm_picotls_ctx_t),
        .setup_crypto = aesgcm_pl_setup_crypto_128,
    };
    ptls_cipher_suite_t cs_aes128_sha256 = ptls_cipher_suite_t{
        .id = cast(u16, 4865),
        .aead = &aead_aes128gcm,
        .hash = cast(ptls_hash_algorithm_t*, &ptls_minicrypto_sha256),
        .name = "TLS_AES_128_GCM_SHA256",
    };
    ptls_key_exchange_algorithm_t*[2] keyex_list;
    keyex_list[0] = &kx_x25519;
    keyex_list[1] = null;
    ptls_cipher_suite_t*[2] cs_list;
    cs_list[0] = &cs_aes128_sha256;
    cs_list[1] = null;

    ptls_context_t ctx = ptls_context_t{};
    ctx.random_bytes = mc_csprng_bytes;
    ctx.get_time = &mc_picotls_get_time;
    ctx.key_exchanges = &keyex_list[0];
    ctx.cipher_suites = &cs_list[0];
    ctx.use_raw_public_keys = cast(u32, 1);
    ctx.certificates.list = &srv_certs[0];
    ctx.certificates.count = cast(u64, 1);
    ctx.sign_certificate = &srv_sign_ctx.super;

    ptls_t* tls = ptls_new(&ctx, 1);
    if tls == null { net_close(conn); return PICO_HTTPS_ERR_PTLS_NEW; }

    ptls_buffer_t sb;
    u8[4096] sb_small;
    ptls_buffer_init(&sb, &sb_small[0], 4096);
    u8[16384] recv_acc;
    i32 recv_len = 0;

    while ptls_handshake_is_complete(tls) == 0 {
        i32 e = pico_https_drive_one(tls, conn, &recv_acc[0], &recv_len, &sb, false);
        if e != 0 {
            ptls_buffer_dispose(&sb); ptls_free(tls); net_close(conn);
            return PICO_HTTPS_ERR_HANDSHAKE;
        }
    }

    // Read request bytes until end-of-headers (\r\n\r\n).
    ptls_buffer_t db;
    u8[8192] db_small;
    ptls_buffer_init(&db, &db_small[0], 8192);
    u8[8192] req_plain;
    i32 req_len = 0;
    bool got_headers = false;
    while !got_headers && req_len < 8192 {
        if recv_len == 0 {
            u8[4096] tmp;
            i32 n = net_recv(conn, &tmp[0], 4096);
            if n <= 0 { break; }
            for i32 i = 0; i < n; i++ { recv_acc[i] = tmp[i]; }
            recv_len = n;
        }
        u64 consumed = cast(u64, recv_len);
        db.off = 0;
        i32 r = ptls_receive(tls, &db, &recv_acc[0], &consumed);
        if r != 0 && r != 514 { break; }
        i32 leftover = recv_len - cast(i32, consumed);
        for i32 i = 0; i < leftover; i++ { recv_acc[i] = recv_acc[cast(i32, consumed) + i]; }
        recv_len = leftover;
        for u64 i = 0; i < db.off && req_len < 8192; i++ {
            req_plain[req_len++] = db.base[i];
        }
        for i32 i = 3; i < req_len; i++ {
            if req_plain[i - 3] == cast(u8, 13)
               && req_plain[i - 2] == cast(u8, 10)
               && req_plain[i - 1] == cast(u8, 13)
               && req_plain[i] == cast(u8, 10) {
                got_headers = true;
                break;
            }
        }
    }

    u8[32768] resp_buf;
    i32 resp_len = handler(&req_plain[0], req_len, &resp_buf[0], 32768);
    if resp_len <= 0 {
        ptls_buffer_dispose(&db); ptls_buffer_dispose(&sb);
        ptls_free(tls); net_close(conn);
        return PICO_HTTPS_ERR_SEND_REQ;
    }

    sb.off = 0;
    i32 sr = ptls_send(tls, &sb, &resp_buf[0], cast(u64, resp_len));
    if sr != 0 {
        ptls_buffer_dispose(&db); ptls_buffer_dispose(&sb);
        ptls_free(tls); net_close(conn);
        return PICO_HTTPS_ERR_SEND_REQ;
    }
    if !net_send_all(conn, sb.base, cast(i32, sb.off)) {
        ptls_buffer_dispose(&db); ptls_buffer_dispose(&sb);
        ptls_free(tls); net_close(conn);
        return PICO_HTTPS_ERR_SEND_REQ;
    }

    ptls_buffer_dispose(&db);
    ptls_buffer_dispose(&sb);
    ptls_free(tls);
    net_close(conn);
    return 0;
}
