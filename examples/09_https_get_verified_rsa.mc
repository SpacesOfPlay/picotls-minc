// HTTPS GET with RSA-PSS cert verify by SPKI pin. Use this when
// the server presents an RSA leaf cert. For ECDSA-P256 use 08.
//
// Defaults to duckduckgo.com/robots.txt with a pin captured at
// publish time. Override with TLS_HOST / TLS_PORT / TLS_SNI /
// TLS_PATH / TLS_PIN_SPKI_SHA256. See example 08 for how to
// compute a fresh pin. If the run fails with code -5 (handshake),
// the pin has drifted — re-pin.

@utf8_console

import pico_https;

extern "msvcrt.dll" {
    i32 atoi(u8* s);
}
private {
i32 hex_nibble(u8 c) {
    if c >= '0' && c <= '9' { return cast(i32, c) - cast(i32, '0'); }
    if c >= 'a' && c <= 'f' { return cast(i32, c) - cast(i32, 'a') + 10; }
    if c >= 'A' && c <= 'F' { return cast(i32, c) - cast(i32, 'A') + 10; }
    return 0 - 1;
}
}

i32 main() {
    u8* host = getenv(cast(u8*, "TLS_HOST"));
    u8* port_s = getenv(cast(u8*, "TLS_PORT"));
    u8* sni = getenv(cast(u8*, "TLS_SNI"));
    u8* path = getenv(cast(u8*, "TLS_PATH"));
    u8* pin_s = getenv(cast(u8*, "TLS_PIN_SPKI_SHA256"));
    if host == null { host = cast(u8*, "duckduckgo.com"); }
    if sni == null  { sni  = cast(u8*, "duckduckgo.com"); }
    if path == null { path = cast(u8*, "/robots.txt"); }
    if pin_s == null {
        pin_s = cast(u8*, "df53bbfab573879b33b3ece511fb2b5940f52db3202bde3af4d472c85cb15a9d");
    }
    u16 port = cast(u16, 443);
    if port_s != null {
        i32 p = atoi(port_s);
        if p > 0 && p < 65536 { port = cast(u16, p); }
    }
    if strlen(pin_s) != 64 {
        printf("TLS_PIN_SPKI_SHA256 must be exactly 64 hex chars\n");
        return 1;
    }

    u8[32] pin_bytes;
    for i32 i = 0; i < 32; i++ {
        i32 hi = hex_nibble(pin_s[i * 2]);
        i32 lo = hex_nibble(pin_s[i * 2 + 1]);
        if hi < 0 || lo < 0 {
            printf("TLS_PIN_SPKI_SHA256 has a non-hex character\n");
            return 1;
        }
        pin_bytes[i] = cast(u8, (hi << 4) | lo);
    }

    pinned_verify_cert_t vc = pinned_verify_cert_t{};
    vc.super.cb = rsa_pss_pinned_verify_cert_cb;
    vc.super.algos = &rsa_pss_pl_verify_algos[0];
    for u64 i = 0; i < 32; i++ { vc.pinned_spki_sha256[i] = pin_bytes[i]; }

    printf("GET https://%s:%d%s  (SNI=%s, SPKI-pinned RSA-PSS)\n",
           host, cast(i32, port), path, sni);

    u8[65536] response;
    i32 n = pico_https_get(host, port, sni, path,
                        &response[0], 65536,
                        null, null, &vc.super);
    if n < 0 {
        printf("pico_https_get failed: code=%d\n", n);
        if n == -5 {
            printf("  -5 = handshake. If using the default host, the\n");
            printf("  baked-in SPKI pin may be stale — re-pin (see example 08).\n");
        }
        return 1;
    }

    printf("--- verified; %d bytes received ---\n", n);
    i32 to_print = n < 8192 ? n : 8192;
    for i32 i = 0; i < to_print; i++ { printf("%c", cast(i32, response[i])); }
    if n > 8192 { printf("\n[... +%d more bytes truncated]\n", n - 8192); }
    printf("\n--- end ---\n");
    return 0;
}
