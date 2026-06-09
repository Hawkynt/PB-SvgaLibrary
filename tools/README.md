# PowerBASIC toolchain for CI

The advisory `compile` job in `.github/workflows/ci.yml` builds the real `.EXE`
under DOSBox using the PowerBASIC 3.5 compiler (`PBC.EXE`). PB 3.5 is
freely-available abandonware — the install media is on
[winworldpc](https://winworldpc.com/product/powerbasic/3x) — but it needs a
login, so CI can't fetch it directly. Instead, pack it once and drop it here.

## One-time setup

1. Download the PowerBASIC 3.5 setup from winworldpc and install it (it is a
   DOS installer — run it under DOSBox), or just collect `PBC.EXE` plus the
   runtime files it needs.
2. Pack the compiler directory into a gzipped tar whose top level contains
   `PBC.EXE` (and runtime):

   ```bash
   tar cz -C /path/to/powerbasic . > pb-toolchain.tar.gz
   ```

3. Commit it as **`tools/pb-toolchain.tar.gz`** (plain — fine for abandonware),
   **or**, to keep it private, AES-encrypt it and add a secret:

   ```bash
   tar cz -C /path/to/powerbasic . \
     | openssl enc -aes-256-cbc -pbkdf2 -salt -out tools/pb-toolchain.tar.enc -pass pass:'<KEY>'
   # then add repo secret  PB_TOOLCHAIN_KEY = <KEY>
   ```

Once either file is present, the `compile` job activates automatically: it
unpacks the toolchain, mounts the sources in DOSBox, runs `make.bat` →
`PBC.EXE`, and uploads the built `.EXE`. Until then it self-skips, and the
structural syntax check remains the required gate.
