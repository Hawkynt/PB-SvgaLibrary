#!/usr/bin/env python3
# =============================================================================
# build-pbl.py - derive linkable PowerBASIC units from the source-include .SUB
# modules and emit everything needed to assemble SVGA.PBL.
# =============================================================================
# The whole library exceeds PB/DOS's 64k-per-compilation-unit code limit, so it
# cannot be compiled as one $INCLUDE program. Instead each .SUB becomes a
# separately-compiled $COMPILE UNIT; PBLIB assembles the .PBU files into
# SVGA.PBL; a consumer $INCLUDEs SVGA.BI and $LINKs SVGA.PBL. The ~29 units pack
# into a few <=64k $CODE SEG groups so the linked program stays within both the
# 64k-per-segment and the segment-count limits.
#
# Usage: build-pbl.py <src-dir-with-.SUB> <out-dir>
#   emits into <out-dir>: <unit>.BAS (units), SVGATYPE.BI/SVGADECL.BI/SVGA.BI/
#   SVGAINT.BI (interface), SELFTEST.BAS, PBLIB.IN (librarian script), UNITS.txt
# =============================================================================
import os, re, glob, sys, shutil

SRC = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'build_pbl'
shutil.rmtree(OUT, ignore_errors=True); os.makedirs(OUT)
def rd(p):
    # normalize to CRLF so the line-based parsing below never silently skips
    # procs in a file that picked up LF-only lines (wr() re-emits CRLF anyway)
    return open(p, 'rb').read().decode('latin1').replace('\r\n', '\n').replace('\n', '\r\n')
def wr(p, s): open(os.path.join(OUT, p), 'wb').write(s.replace('\r\n', '\n').replace('\n', '\r\n').encode('latin1'))

modules = sorted(os.path.basename(p) for p in glob.glob(SRC + '/*.SUB'))
RAW = {m: rd(SRC + '/' + m) for m in modules}

def extract(text):
    lines = text.split('\r\n'); consts, types, globs, body = [], [], [], []
    i = 0
    while i < len(lines):
        l = lines[i]; s = l.strip()
        if s.startswith('TYPE '):
            blk = [l]; i += 1
            while i < len(lines) and not lines[i].strip().startswith('END TYPE'): blk.append(lines[i]); i += 1
            if i < len(lines): blk.append(lines[i])
            types.append('\r\n'.join(blk)); i += 1; continue
        if s.startswith('%') and '=' in s: consts.append(l); i += 1; continue
        if s.startswith('DIM ') and ' AS SHARED ' in l: globs.append(l)
        body.append(l); i += 1
    return consts, types, globs, '\r\n'.join(body)

tlines = RAW['TYPES.SUB'].split('\r\n')
sub_i = next(i for i, l in enumerate(tlines) if l.startswith('SUB '))
types_proc = '\r\n'.join(tlines[sub_i:])
const_lines, type_blocks, glob_lines, _ = extract('\r\n'.join(tlines[:sub_i]))
seen = set(c.strip() for c in const_lines); mod_body = {}
for m in modules:
    if m == 'TYPES.SUB': mod_body[m] = types_proc; continue
    c2, t2, g2, b2 = extract(RAW[m]); type_blocks += t2
    for c in c2:
        if c.strip() not in seen: const_lines.append(c); seen.add(c.strip())
    mod_body[m] = b2

# only standalone (non-UDT) SHARED arrays don't cross units: move single-module
# ones local, drop the unused ones; every other global is a UDT/scalar/string.
DROP = {'GIFGlobalPalettes', 'TIFFColorMaps', 'TGAColorMaps', 'ICOLIBIconGroupIDs', 'ICOLIBIconGroupNames'}
MOVE = {'AnimationStates', 'AnimationTimerIDs', 'AnimationAutoCleanup'}
iface_globals = []; ani_arrays = []
for l in glob_lines:
    m = re.match(r'\s*DIM\s+([A-Za-z_0-9]+)(\([^)]*\))?\s+AS\s+SHARED\s+(.*?)\s*(\'.*)?$', l)
    name, arr, typ = m.group(1), m.group(2), m.group(3)
    if name in DROP: continue
    if name in MOVE: ani_arrays.append('DIM %s%s AS SHARED %s' % (name, arr, typ)); continue
    if arr: continue
    iface_globals.append((name, 'DIM %s AS %s' % (name, typ)))

defs = {}
for m in modules:
    for line in RAW[m].split('\r\n'):
        mm = re.match(r'^(SUB|FUNCTION)\s+([A-Za-z_0-9]+)\s*(\([^\r\n]*\))?(\s+AS\s+[A-Za-z_0-9]+)?\s*$', line)
        if mm: defs[mm.group(2)] = (mm.group(1), bool(mm.group(3)), mm.group(3) or '', (mm.group(4) or '').strip(), m)
# no-param procs can't be DECLAREd (Error 426) and can't be called cross-unit
# undeclared (Error 462) -> give each a link dummy param, EXCEPT CODEPTR'd ones
# (interrupt handlers): CODEPTR wants the bare name and an ISR takes no args.
codeptr = set()
for m in modules:
    for mt in re.finditer(r'CODEPTR(?:32)?\(\s*([A-Za-z_0-9]+)', RAW[m]): codeptr.add(mt.group(1))
DUMMY = set(n for n, (k, hp, p, r, dm) in defs.items() if not hp and n not in codeptr)
DUMMYARG = '(BYVAL pbLink AS INTEGER)'

declares = []
for n, (k, hp, p, r, dm) in sorted(defs.items()):
    if not hp and n not in DUMMY: continue
    pp = p if hp else DUMMYARG
    declares.append('DECLARE SUB %s%s' % (n, pp) if k == 'SUB' else 'DECLARE FUNCTION %s%s %s' % (n, pp, r))

wr('SVGATYPE.BI', '\r\n'.join(const_lines) + '\r\n\r\n' + '\r\n\r\n'.join(type_blocks) + '\r\n')
wr('SVGADECL.BI', '\r\n'.join(declares) + '\r\n')
wr('SVGA.BI', '$INCLUDE "SVGATYPE.BI"\r\n' + '\r\n'.join('%s : PUBLIC %s' % (d, n) for n, d in iface_globals) + '\r\n$INCLUDE "SVGADECL.BI"\r\n')
wr('SVGAINT.BI', '$INCLUDE "SVGATYPE.BI"\r\n' + '\r\n'.join('%s : EXTERNAL %s' % (d, n) for n, d in iface_globals) + '\r\n$INCLUDE "SVGADECL.BI"\r\n')

def apply_dummy(body):
    body = body.replace('\r\n', '\n')
    for name in DUMMY:
        k = defs[name][0]
        if k == 'SUB':
            body = re.sub(r'^(SUB\s+' + re.escape(name) + r')[ \t]*$', r'\1' + DUMMYARG, body, flags=re.M)
        else:
            body = re.sub(r'^(FUNCTION\s+' + re.escape(name) + r')(\s+AS\s+[A-Za-z_0-9]+)[ \t]*$', r'\1' + DUMMYARG + r'\2', body, flags=re.M)
        body = re.sub(r'\b' + re.escape(name) + r'\b(?!\s*[(=])', name + '(0)', body)
    return body

def mark_public(text):
    out = []
    for line in text.replace('\r\n', '\n').split('\n'):
        if re.match(r'^SUB\s+[A-Za-z_0-9]+', line) and ' PUBLIC' not in line:
            line = re.sub(r'^(SUB\s+[A-Za-z_0-9]+(\([^\n]*\))?)[ \t]*$', r'\1 PUBLIC', line)
        elif re.match(r'^FUNCTION\s+[A-Za-z_0-9]+', line) and ' PUBLIC' not in line:
            line = re.sub(r'^(FUNCTION\s+.*?)(\s+AS\s+[A-Za-z_0-9]+)[ \t]*$', r'\1 PUBLIC\2', line)
        out.append(line)
    return '\n'.join(out)

# bin-pack units into <=64k $CODE SEG groups (total code ~141k -> 3 segments of
# ~47k each, greedy-packed from the measured per-unit code sizes of 2026-06-10).
# Re-pack if a future change pushes a segment over 64k (the build will Error 408).
GROUPS = [['VESAOPT', 'DRAW_GIF', 'DRAW_TIF', 'CURSOR', 'DRAW_PCX', 'MODE16', 'MEMORY', 'MODEY', 'TYPES'],
          ['MODEX', 'VESA', 'DRAW_CUR', 'SCROLL', 'VGA', 'SVGA', 'TIMER', 'FILEUTIL', 'VIRTUAL', 'MODEZ', 'PORTGLUE'],
          ['DRAW_ANI', 'SPRITE', 'DRAW_TGA', 'DRAW_ICO', 'DRAW_ICL', 'DRAW_BMP', 'FONTS', 'GRAPHICS', 'MODETEXT']]
SEGGROUP = {u: 'SEG%d' % i for i, g in enumerate(GROUPS) for u in g}

units = []
for m in modules:
    base = m[:-4]
    if m == 'SVGA.SUB':
        body = '\r\n'.join(l for l in mod_body[m].split('\r\n') if not l.strip().startswith('$INCLUDE "'))
    elif m == 'DRAW_ANI.SUB':
        body = '\r\n'.join(ani_arrays) + '\r\n' + mod_body[m]
    else:
        body = mod_body[m]
    body = apply_dummy(body)
    hdr = '$COMPILE UNIT\n$CODE SEG "%s"\n$INCLUDE "SVGAINT.BI"\n' % SEGGROUP.get(base, 'SEG0')
    wr(base + '.BAS', hdr + mark_public(body) + '\n'); units.append(base)

# link-and-run smoke test: round-trip a mode-13h pixel through the linked .PBL
wr('SELFTEST.BAS', '''$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"
DIM xv AS WORD, yv AS WORD, cv AS BYTE, got AS BYTE
CALL Svga_Init(0)
!MOV AX, &H0013
!INT &H10
VESASystemContext.CurrentMode = %SVGA_MODE13
CALL Svga_InitDispatchTable(0)
xv = 160 : yv = 100 : cv = 42 : got = 0
CALL Vga_PutPixel(xv, yv, cv)
CALL Vga_GetPixel(xv, yv, got)
!MOV AX, &H0003
!INT &H10
OPEN "O.TXT" FOR OUTPUT AS #1
IF got = 42 THEN PRINT #1, "PIXEL_ROUNDTRIP_OK" ELSE PRINT #1, "PIXEL_FAIL got="; got
CLOSE #1
END
''')
# PBLIB librarian script (single-key O/A.../Q commands on stdin)
wr('PBLIB.IN', 'OSVGA.PBL\r\n' + ''.join('A%s.PBU\r\n' % u for u in units) + 'Q')
open(os.path.join(OUT, 'UNITS.txt'), 'w').write('\n'.join(units))
print('emitted %d units into %s (interface: SVGA.BI / SVGAINT.BI)' % (len(units), OUT))
