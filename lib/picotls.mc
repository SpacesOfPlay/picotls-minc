// picotls — TLS 1.3 core API. For HTTPS use `import pico_https;`.

// Same minimum as build.mc.
@minc_min_version "0.9.19"

// Older minc ignores the tag above; this forces an error instead.
when !defined(MINC_VERSION) || MINC_VERSION < 9019 {
    minc_0_9_19_or_newer_required please_update_minc;
}

import ext_libc;
import cfile_shim;
import picotls_shim;
import net;
import thread;
import picotls_lib;
import picotls_bridges;
import picotls_bridges_p256;
import picotls_bridges_rsa;
