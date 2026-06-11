# Agent guide — PB-SvgaLibrary

Working agreement for **all** coding agents (Claude Code, Codex, Copilot, …)
and human contributors working in this repository. These rules are not
optional. The full house spec lives in the `Hawkynt/project-template` repo
(`STANDARD.md`); this file is the per-repo distillation.

## What this is

A **PowerBASIC 3.5 (DOS)** SVGA graphics library — `.SUB` modules included via
`$INCLUDE "SVGA.SUB"`. The real compiler only runs under DOS/DOSBox, so CI
performs a structural syntax check instead of a compile.

## Commits

- **Group changes semantically/logically** — one concern per commit;
  refactorings separate from behavior changes.
- **Every subject line starts with a prefix**:
  - `+` added feature/behavior
  - `-` removed feature/behavior
  - `*` changed behavior / public API
  - `#` bug fixed
  - `!` critical todo / open issue worth recording
- Never start a subject with "fix"/"bugfix"/"changed"/"modified" — the prefix
  already says it.
- **No AI traces anywhere**: no `Co-Authored-By` AI lines, no "Generated with"
  footers, no agent mentions in messages, comments, or authorship.

## The loop (always, in this order)

1. **Before committing**: run the structural check locally —
   `node .github/workflows/scripts/check-basic.mjs .` (exactly what CI runs) —
   and, for behavioral changes, exercise the code under DOSBox with PB 3.5
   where possible. Update the README (API reference section) when the public
   surface changes.
2. **Commit** (rules above) and **push**.
3. **Wait for CI** and fix until green. A pushed change isn't done while the
   workflow it triggered is red.

## Generated code

The per-width VESA fast-path families (`VOPT320.SUB` ... `VOPT1600.SUB`), the
dispatch wiring (`VESAOPT.SUB`) and their aggregate (`VESAOPT.INC`) are
**generated** from `VESAOPT.TEMPLATE.BAS` by `scripts/gen-vesaopt.py` and are
NOT committed (gitignored): every pipeline stage - the CI check, the test
runner and the .PBL build - regenerates them first. Change the template (or
the mode list in the tool) and rerun `python3 scripts/gen-vesaopt.py` locally
before testing.

The library version lives in `TYPES.SUB` (`%SVGA_VERSION_MAJOR/MINOR/PATCH`),
is exposed at runtime via `Svga_Version$`, and drives the nightly/release
naming - bump it there and nowhere else.

## Demos

`demos/<NAME>/` each hold one `.BAS` (8.3 name) plus assets; they consume the
built library (`$INCLUDE "SVGA.BI"` + `$LINK "SVGA.PBL"`) and MUST use the
abstract API only: `Svga_SetRes` (never raw INT 10h/context/dispatch),
`Svga_SetPalette` (never raw OUT &H3C8), `Svga_Close` to leave graphics. Every
demo honours a `SMOKE` argument (deterministic input-free run that writes
`SMOKE.OK`); the build workflow compiles and smoke-runs all of them.

## Syntax & style

- PowerBASIC 3.5 dialect: `BYVAL` parameters, `WORD`/`BYTE`/`DWORD` types,
  inline assembly via `!`-prefixed lines, `%CONST` equates,
  `FUNCTION = value` return assignment, `_` line continuation.
- Four-space indentation inside blocks (matches the existing sources);
  K&R-spirit: guard clauses and early `EXIT SUB`/`EXIT FUNCTION` over deep
  nesting.
- Every `SUB`/`FUNCTION` carries the boxed header comment (purpose,
  parameters, returns) used throughout the sources.
- Performance is the point of this library: never make a routine slower or
  more memory-hungry while refactoring; hot paths stay in inline assembly and
  say *why* in a comment.
- Names: `Module_Action` for public routines (`Graphics_Bar`,
  `Memory_ClearVideoMemory`); locals in camelCase.

## README & repo conventions

- Keep the standard frame: title (plain, no emoji) → badges → one-line `>`
  blockquote; standard sections use the fixed emoji mapping (`## ✨ Features`,
  `## 🚀 Usage`, `## 🛠️ Building`, `## ❤️ Support`, `## 📜 License`);
  repo-specific sections keep their consistent topical emojis.
- License is LGPL-3.0-or-later; the `## ❤️ Support` section and
  `.github/FUNDING.yml` stay intact.
