#!/usr/bin/env bash
# =============================================================================
# run-pb-tests.sh - compile and run the PowerBASIC 3.5 test battery under DOSBox.
# =============================================================================
# The battery lives in tests/ as one self-contained PB program per source module
# (tests/<MODULE>.BAS). Each program $INCLUDEs tests/TESTLIB.BI (a tiny xUnit
# framework) and the module(s) under test, defines one SUB per test case in the
# Arrange-Act-Assert shape, and appends parseable results to UNITTEST.LOG:
#   [SUITE]  <name>
#     [PASS] <case> :: <assertion>
#     [FAIL] <case> :: <assertion> (expected=.. actual=..)
#   [RESULT] <name> assertions=N failed=M
# This harness compiles and runs every suite IN ITS OWN DOSBox session with the
# real PowerBASIC 3.5 compiler, TIMES each one (so regression slowdowns show up),
# renders an NUnit/xUnit-style summary, and fails on any [FAIL] or any suite that
# started but never produced a [RESULT] (i.e. crashed / hung).
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
tests=( tests/*.BAS tests/*.bas )
if [ ${#tests[@]} -eq 0 ]; then echo "::notice::no tests/*.BAS - skipping PB unit tests."; exit 0; fi

command -v dosbox >/dev/null || { sudo apt-get update && sudo apt-get install -y dosbox; }

rm -rf build && mkdir -p build
cp ./*.SUB build/ 2>/dev/null || true
cp ./*.INC build/ 2>/dev/null || true
cp tests/*.BI build/ 2>/dev/null || true
# Engine-only view of SVGA.SUB (which is the umbrella that $INCLUDEs the whole
# library) so tests/SVGA.BAS can exercise the Svga_* dispatch engine in isolation
# without pulling in every module (that would blow PB's 64k-per-compile limit).
python3 -c "d=open('SVGA.SUB','rb').read(); open('build/SVGAENG.SUB','wb').write(b''.join(l for l in d.splitlines(keepends=True) if not l.lstrip().startswith(b'\$INCLUDE')))"
cp pb/* build/
rm -f build/UNITTEST.LOG
: > build/TIMING.txt

# Each suite gets its own DOSBox session: compile T<n>.BAS, run T<n>.EXE (appends
# UNITTEST.LOG). Copied to a short 8.3 name because DOSBox can't see long names.
# cycles=max for fast compiles; no [sdl] output=surface (it makes the dummy-video
# headless DOSBox bail before running anything).
i=0
battery_start=$(date +%s.%N)
for t in "${tests[@]}"; do
  i=$((i+1)); name=$(basename "$t"); cp "$t" "build/T$i.BAS"
  # Auto-generate the entry-point driver from the suite's SUB Test_* names unless
  # it wires its own (presence of Test_BeginSuite). Test_Setup/Test_Teardown, if
  # defined, run first/last. PB needs CRLF, so emit \r\n.
  if ! grep -qi 'Test_BeginSuite' "build/T$i.BAS"; then
    suite="${name%.*}"
    {
      printf "\r\n' === auto-generated test driver ===\r\n"
      grep -qiE '^[[:space:]]*SUB[[:space:]]+Test_Setup[[:space:]]*$' "build/T$i.BAS" && printf 'CALL Test_Setup\r\n'
      printf 'CALL Test_BeginSuite("%s")\r\n' "$suite"
      grep -oiE '^[[:space:]]*SUB[[:space:]]+Test_[A-Za-z0-9_]+' "build/T$i.BAS" \
        | sed -E 's/^[[:space:]]*[Ss][Uu][Bb][[:space:]]+//' \
        | grep -viE '^Test_(Setup|Teardown)$' \
        | while read -r fn; do printf 'CALL %s\r\n' "$fn"; done
      printf 'CALL Test_EndSuite("%s")\r\n' "$suite"
      grep -qiE '^[[:space:]]*SUB[[:space:]]+Test_Teardown[[:space:]]*$' "build/T$i.BAS" && printf 'CALL Test_Teardown\r\n'
      printf 'END\r\n'
    } >> "build/T$i.BAS"
  fi
  {
    echo "[cpu]"; echo "core=dynamic"; echo "cycles=max"
    echo "[autoexec]"
    echo "mount c \"$(pwd)/build\""
    echo "c:"
    echo "echo === compiling $name (T$i.BAS) === >> PBCOUT.TXT"
    echo "PBC.EXE -FNPX -G386 -ODV -OZF+ -CE -ES -EB -LB -LG T$i.BAS >> PBCOUT.TXT"
    echo "T$i.EXE"
    echo "EXIT"
  } > build/dosbox.conf
  t_start=$(date +%s.%N)
  SDL_VIDEODRIVER=dummy timeout 180 dosbox -conf build/dosbox.conf -exit >/dev/null 2>&1 || true
  t_end=$(date +%s.%N)
  ms=$(awk "BEGIN{printf \"%.0f\", ($t_end - $t_start)*1000}")
  printf "%-7s %-18s %8s ms\n" "T$i.BAS" "$name" "$ms" >> build/TIMING.txt
done
battery_end=$(date +%s.%N)
battery_ms=$(awk "BEGIN{printf \"%.0f\", ($battery_end - $battery_start)*1000}")

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
  /^  \[PASS\]/  { total++; next }
  /^  \[FAIL\]/  { total++; tfail++; printf "  FAIL %s\n", substr($0,10); next }
  /^  \[SKIP\]/  { tskip++; printf "  SKIP %s\n", substr($0,10); next }
  END {
    printf "\n---------------------------------------------------------------\n"
    printf "Total: %d   Passed: %d   Failed: %d   Skipped: %d\n", total, total-tfail, tfail, tskip
  }
' "$log"
echo
echo "--- timing (watch for regression slowdowns) -------------------"
sort -k3 -n -r build/TIMING.txt
printf "%-7s %-18s %8s ms\n" "" "TOTAL" "$battery_ms"
echo "==============================================================="
echo
echo "=== raw UNITTEST.LOG ==="; cat "$log"

# A suite that started but never finished (no [RESULT]) crashed or hung.
started=$(grep -c '^\[SUITE\]'  "$log" || true)
finished=$(grep -c '^\[RESULT\]' "$log" || true)
if [ "$started" != "$finished" ]; then
  echo "::error::a suite did not finish (started=$started, finished=$finished) - a test crashed or hung."
  exit 1
fi
if grep -qiE "^\s*\[FAIL\]|CRITICAL ERROR|corruption" "$log"; then
  echo "::error::PowerBASIC test battery reported failures."
  exit 1
fi
echo "All PowerBASIC tests passed ($started suites, ${battery_ms} ms total)."
