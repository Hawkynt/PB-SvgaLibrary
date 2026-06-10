#!/usr/bin/env bash
# =============================================================================
# run-pb-tests.sh - compile and run the PowerBASIC 3.5 test battery under DOSBox.
# =============================================================================
# The battery lives in tests/ as one self-contained PB program per source module
# (<MODULE>.TST) plus a few standalone *.bas probes. Each program $INCLUDEs
# tests/TESTLIB.BI (a tiny xUnit framework) and the module(s) under test, defines
# one SUB per test case in the Arrange-Act-Assert shape, and appends parseable
# results to UNITTEST.LOG:
#   [SUITE]  <name>
#     [PASS] <case> :: <assertion>
#     [FAIL] <case> :: <assertion> (expected=.. actual=..)
#   [RESULT] <name> assertions=N failed=M
# This harness compiles and runs every test with the real PowerBASIC 3.5 compiler
# under DOSBox, renders an NUnit/xUnit-style summary, and fails on any [FAIL].
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

shopt -s nullglob
tests=( tests/*.TST tests/*.tst tests/*.bas )
if [ ${#tests[@]} -eq 0 ]; then echo "::notice::no tests/ programs - skipping."; exit 0; fi

command -v dosbox >/dev/null || { sudo apt-get update && sudo apt-get install -y dosbox; }

rm -rf build && mkdir -p build
cp ./*.SUB build/ 2>/dev/null || true
cp tests/*.BI build/ 2>/dev/null || true
cp pb/* build/
# Copy each test to a short 8.3 name (T1.BAS, T2.BAS, ...) - DOSBox mangles long
# names like test_mode16.bas / VGA.TST, so PBC can't find them by long name. Keep
# a map so the rendered summary still shows the real test name.
i=0; : > build/TESTMAP.txt
for t in "${tests[@]}"; do
  i=$((i+1)); cp "$t" "build/T$i.BAS"; echo "T$i.BAS  $(basename "$t")" >> build/TESTMAP.txt
done
echo "=== test map ==="; cat build/TESTMAP.txt

# One DOSBox session: compile each test to .EXE, then run it (appends UNITTEST.LOG).
{
  echo "[cpu]"; echo "core=dynamic"; echo "cycles=max"   # fast compiles; no [sdl] output=surface (it makes the dummy-video headless DOSBox bail before running anything)
  echo "[autoexec]"
  echo "mount c \"$(pwd)/build\""
  echo "c:"
  n=0
  for t in "${tests[@]}"; do
    n=$((n+1))
    echo "echo === compiling $(basename "$t") (T$n.BAS) === >> PBCOUT.TXT"
    echo "PBC.EXE -FNPX -G386 -ODV -OZF+ -CE -ES -EB -LB -LG T$n.BAS >> PBCOUT.TXT"
    echo "T$n.EXE"
  done
  echo "EXIT"
} > build/dosbox.conf

SDL_VIDEODRIVER=dummy timeout 600 dosbox -conf build/dosbox.conf -exit >/dev/null 2>&1 || true

echo "=== PBC output ==="; find build -iname pbcout.txt -exec cat {} + 2>/dev/null || true
log=$(find build -iname 'unittest.log' | head -1 || true)
if [ -z "$log" ]; then
  echo "::error::no UNITTEST.LOG produced - tests did not run (see PBC output)."
  exit 1
fi

echo
echo "=================== PowerBASIC test battery ==================="
# Render an NUnit/xUnit-style summary from the [SUITE]/[PASS]/[FAIL]/[RESULT] log.
awk '
  /^\[SUITE\]/   { suite=substr($0,9); printf "\n%s\n", suite; next }
  /^  \[PASS\]/  { pass++; total++; next }
  /^  \[FAIL\]/  { fail++; total++; tfail++; printf "  FAIL %s\n", substr($0,10); next }
  /^\[RESULT\]/  { next }
  END {
    printf "\n---------------------------------------------------------------\n"
    printf "Total: %d   Passed: %d   Failed: %d\n", total, total-tfail, tfail
  }
  { pass=pass; fail=fail }
' "$log"
echo "==============================================================="
echo
echo "=== raw UNITTEST.LOG ==="; cat "$log"

if grep -qiE "^\s*\[FAIL\]|CRITICAL ERROR|corruption" "$log"; then
  echo "::error::PowerBASIC test battery reported failures."
  exit 1
fi
echo "All PowerBASIC tests passed."
