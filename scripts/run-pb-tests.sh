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
cp tests/*.bas build/ 2>/dev/null || true
cp pb/* build/

# One DOSBox session: compile each test to .EXE, then run it (writes UNITTEST.LOG).
{
  echo "[sdl]"; echo "output=surface"
  echo "[autoexec]"
  echo "mount c \"$(pwd)/build\""
  echo "c:"
  for t in build/*.bas; do
    [ -e "$t" ] || continue
    n=$(basename "$t"); base=$(echo "${n%.*}" | tr 'a-z' 'A-Z')
    echo "echo === compiling $n === >> PBCOUT.TXT"
    echo "PBC.EXE -FNPX -G386 -ODV -OZF+ -CE -ES -EB -LB -LG $n >> PBCOUT.TXT"
    echo "$base.EXE"
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
