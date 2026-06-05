# License — picotls-minc

picotls-minc is a derivative work of picotls (MIT), cifra
(public-domain), and monocypher (CC0-1.0 or BSD-2). Each upstream
component keeps its own license; the combined distribution inherits
the union of those terms. Full texts below.

> **The minc compiler is NOT covered by the licenses below.** This
> repo ships only minc-language source. Building it requires the
> `minc` compiler from
> <https://github.com/SpacesOfPlay/minc-dev/releases>, which is
> closed-source proprietary software. The optional helper
> `tools/get_minc.ps1` / `tools/get_minc.sh` downloads that binary
> on demand into `tools/minc/` (gitignored). The terms governing
> your use of `minc.exe` / `minc` are stated in the `LICENSE.md`
> shipped inside that minc release (`tools/minc/LICENSE.md` after
> running the fetcher). This repo takes no position and grants no
> rights to the minc compiler binary.

---

## picotls

Copyright (c) 2016 DeNA Co., Ltd., Kazuho Oku, Fastly, Inc.

```
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```

Upstream: https://github.com/h2o/picotls

## cifra

Joseph Birr-Pixton, public-domain (CC0 / unlicense). From the upstream
README:

> All of cifra is public domain. You can use it for any purpose, with
> or without attribution.

Upstream: https://github.com/ctz/cifra

## monocypher

Loup Vaillant. Dual-licensed CC0-1.0 OR BSD-2. The CC0 text:

```
The person who associated a work with this deed has dedicated the work
to the public domain by waiving all of his or her rights to the work
worldwide under copyright law, including all related and neighboring
rights, to the extent allowed by law.

You can copy, modify, distribute and perform the work, even for
commercial purposes, all without asking permission.
```

Upstream: https://monocypher.org/ — https://github.com/LoupVaillant/Monocypher

## minc-side bridges + pico_https_get

The minc-side glue (`picotls_bridges.mc`, `pico_https.mc`, and the
shim files) is (c) Mattias Ljungström, Spaces Of Play UG, MIT-licensed.

```
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```
