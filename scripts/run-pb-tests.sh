#!/usr/bin/env bash
# =============================================================================
# run-pb-tests.sh - compile and run the PowerBASIC 3.5 unit tests under DOSBox.
# =============================================================================
# Each test in tests/ is a self-contained PB program (it $INCLUDEs the modules
# it needs and writes its results to UNITTEST.LOG). This harness compiles and
# runs every tests/*.bas with the real PowerBASIC 3.5 compiler under DOSBox,
# then fails if any test logged FAILED / a critical error.
#
# Needs the PowerBASIC toolchain: tools/pb-toolchain.tar.gz, or
# tools/pb-toolchain.tar.enc + the PB_TOOLCHAIN_KEY env var. If neither is
# present the harness SKIPS (exit 0) so it never blocks where the proprietary
# DOS compiler can't be provided.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p pb
if [ -f tools/pb-toolchain.tar.gz ]; then
  tar xzf tools/pb-toolchain.tar.gz -C pb
elif [ -f tools/pb-toolchain.tar.enc ] && [ -n "${PB_TOOLCHAIN_KEY:-}" ]; then
  openssl enc -d -aes-256-cbc -pbkdf2 -in tools/pb-toolchain.tar.enc -pass env:PB_TOOLCHAIN_KEY | tar xz -C pb
else
  echo "::notice::PowerBASIC toolchain unavailable - skipping PB unit tests."
  exit 0
fi

if ! ls tests/*.bas >/dev/null 2>&1; then echo "::notice::no tests/*.bas - skipping PB unit tests."; exit 0; fi

command -v dosbox >/dev/null || { sudo apt-get update && sudo apt-get install -y dosbox; }

rm -rf build && mkdir -p build
cp ./*.SUB build/ 2>/dev/null || true
cp pb/* build/
# Copy each test to a short 8.3 name (T1.BAS, T2.BAS, ...) - DOSBox mangles long
# names like test_mode16.bas, so PBC can't find them by their long name. Keep a
# map so the log still shows the real test name.
i=0; : > build/TESTMAP.txt
for t in tests/*.bas; do
  [ -e "$t" ] || continue
  i=$((i+1)); cp "$t" "build/T$i.BAS"; echo "T$i.BAS  $(basename "$t")" >> build/TESTMAP.txt
done
echo "=== test map ==="; cat build/TESTMAP.txt

# One DOSBox session: compile each test to .EXE, then run it (writes UNITTEST.LOG).
{
  echo "[cpu]"; echo "core=dynamic"; echo "cycles=max"   # fast compiles; no [sdl] output=surface (it makes the dummy-video headless DOSBox bail before running anything)
  echo "[autoexec]"
  echo "mount c \"$(pwd)/build\""
  echo "c:"
  n=0
  for t in tests/*.bas; do
    [ -e "$t" ] || continue
    n=$((n+1))
    echo "echo === compiling $(basename "$t") (T$n.BAS) === >> PBCOUT.TXT"
    echo "PBC.EXE -FNPX -G386 -ODV -OZF+ -CE -ES -EB -LB -LG T$n.BAS >> PBCOUT.TXT"
    echo "T$n.EXE"
  done
  echo "EXIT"
} > build/dosbox.conf

SDL_VIDEODRIVER=dummy timeout 400 dosbox -conf build/dosbox.conf -exit >/dev/null 2>&1 || true

echo "=== PBC output ==="; find build -iname pbcout.txt -exec cat {} + 2>/dev/null || true
log=$(find build -iname 'unittest.log' | head -1 || true)
if [ -z "$log" ]; then
  echo "::error::no UNITTEST.LOG produced - tests did not run (see PBC output)."
  exit 1
fi
echo "=== UNITTEST.LOG ==="; cat "$log"
if grep -qiE "FAIL|CRITICAL ERROR|corruption" "$log"; then
  echo "::error::PowerBASIC unit tests reported failures."
  exit 1
fi
echo "All PowerBASIC unit tests passed."
