// Structural syntax check for PowerBASIC/QuickBASIC sources.
//
// The real PB 3.5 compiler is DOS-only and proprietary, so CI cannot compile.
// This is the minimum-viable verification instead (STANDARD.md §4): every
// block construct must be correctly opened, nested and closed:
//   SUB/END SUB, FUNCTION/END FUNCTION, TYPE/END TYPE, SELECT CASE/END SELECT,
//   DO/LOOP, FOR/NEXT (incl. "NEXT i, j"), WHILE/WEND, block-IF/END IF,
//   ELSE/ELSEIF/CASE only inside their parent block.
// Strings ("" doubling) and comments (' and REM) are tokenised away first, so
// keywords inside literals never confuse the checker.
//
// Usage: node check-basic.mjs [dir]      (default: repo root, *.SUB/*.BAS/*.INC/*.tst)
// Exit:  0 = all clean, 1 = structural errors found.

import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.argv[2] || '.';
const EXT = /\.(sub|bas|inc|tst)$/i;

// --- strip strings + comments, keep line count intact ------------------------
function cleanLine(line) {
    let out = '';
    let i = 0, inStr = false;
    while (i < line.length) {
        const c = line[i];
        if (inStr) {
            if (c === '"') {
                if (line[i + 1] === '"') { i += 2; continue; }  // "" = escaped quote
                inStr = false;
            }
            i++;
            continue;
        }
        if (c === '"') { inStr = true; i++; continue; }
        if (c === "'") break;                                   // comment to EOL
        out += c;
        i++;
    }
    return out;
}

// Split a cleaned line into statements at ":".
const statements = line => line.split(':').map(s => s.trim()).filter(Boolean);

// Fold "_" line continuations (PB/QB45) into logical lines, keeping the line
// number of each logical line's FIRST physical line for error reporting.
function logicalLines(text) {
    const raw = text.split(/\r?\n/);
    const out = [];
    for (let i = 0; i < raw.length; i++) {
        const startLn = i + 1;
        let line = cleanLine(raw[i]);
        while (/(?:^|\s)_\s*$/.test(line) && i + 1 < raw.length)
            line = line.replace(/_\s*$/, ' ') + cleanLine(raw[++i]);
        out.push({ line, ln: startLn });
    }
    return out;
}

export function checkSource(text, file) {
    const errors = [];
    const stack = [];                       // { kind, line }
    const push = (kind, ln) => stack.push({ kind, line: ln });
    const pop = (kind, ln, what) => {
        const top = stack[stack.length - 1];
        if (!top || top.kind !== kind) {
            errors.push(`${file}:${ln}: ${what} without matching ${kind}` +
                (top ? ` (innermost open block is ${top.kind} from line ${top.line})` : ''));
            return;
        }
        stack.pop();
    };

    for (const { line, ln } of logicalLines(text)) {
        // jump label alone on a line (also shadows keywords in inline asm, e.g. "Loop:")
        if (/^\s*[A-Za-z_][A-Za-z0-9_]*:\s*$/.test(line)) continue;
        for (let st of statements(line)) {
            st = st.toUpperCase().replace(/\s+/g, ' ');
            if (/^(REM\b|[$!]|DECLARE\b|EXIT\b)/.test(st)) continue; // comments, metastatements, inline asm, declares

            // inside a TYPE block only END TYPE matters — members may shadow
            // keywords ("Type AS WORD"), and TYPE blocks cannot nest.
            if (stack[stack.length - 1]?.kind === 'TYPE' && !/^END TYPE\b/.test(st)) continue;

            if (/^END SUB\b/.test(st))      { pop('SUB', ln, 'END SUB'); continue; }
            if (/^END FUNCTION\b/.test(st)) { pop('FUNCTION', ln, 'END FUNCTION'); continue; }
            if (/^END TYPE\b/.test(st))     { pop('TYPE', ln, 'END TYPE'); continue; }
            if (/^END SELECT\b/.test(st))   { pop('SELECT', ln, 'END SELECT'); continue; }
            if (/^END IF\b/.test(st))       { pop('IF', ln, 'END IF'); continue; }
            if (/^END\b/.test(st))          continue;                 // plain END (program end)

            if (/^SUB\b/.test(st))          { push('SUB', ln); continue; }
            // "FUNCTION = expr" assigns the return value (PB); only
            // "FUNCTION <name>" opens a block.
            if (/^FUNCTION [A-Z_]/.test(st)) { push('FUNCTION', ln); continue; }
            if (/^FUNCTION\b/.test(st))      continue;
            if (/^TYPE [A-Z_]/.test(st))    { push('TYPE', ln); continue; }
            if (/^SELECT CASE\b/.test(st))  { push('SELECT', ln); continue; }
            if (/^DO\b/.test(st))           { push('DO', ln); continue; }
            if (/^LOOP\b/.test(st))         { pop('DO', ln, 'LOOP'); continue; }
            if (/^FOR\b/.test(st))          { push('FOR', ln); continue; }
            if (/^NEXT\b/.test(st)) {                                  // NEXT i, j closes several
                const count = (st.match(/,/g) || []).length + 1;
                for (let k = 0; k < count; k++) pop('FOR', ln, 'NEXT');
                continue;
            }
            if (/^WHILE\b/.test(st))        { push('WHILE', ln); continue; }
            if (/^WEND\b/.test(st))         { pop('WHILE', ln, 'WEND'); continue; }

            if (/^IF\b/.test(st)) {
                const m = /\bTHEN\b(.*)$/.exec(st);
                if (m && m[1].trim() === '') push('IF', ln);          // block IF: nothing after THEN
                continue;                                              // single-line IF / IF..GOTO
            }
            if (/^ELSEIF\b/.test(st) || /^ELSE\b/.test(st)) {
                const top = stack[stack.length - 1];
                if (!top || top.kind !== 'IF')
                    errors.push(`${file}:${ln}: ${st.split(' ')[0]} outside a block IF`);
                continue;
            }
            if (/^CASE\b/.test(st)) {
                const top = stack[stack.length - 1];
                if (!top || top.kind !== 'SELECT')
                    errors.push(`${file}:${ln}: CASE outside SELECT CASE`);
                continue;
            }
        }
    }
    for (const open of stack)
        errors.push(`${file}:${open.line}: unclosed ${open.kind} at end of file`);
    return errors;
}

function* walk(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        if (e.name === '.git' || e.name === 'node_modules') continue;
        const p = path.join(dir, e.name);
        if (e.isDirectory()) yield* walk(p);
        else if (EXT.test(e.name)) yield p;
    }
}

const files = [...walk(ROOT)].sort();
if (files.length === 0) {
    console.error('error: no BASIC sources (*.SUB/*.BAS/*.INC/*.tst) found — nothing was checked.');
    process.exit(1);                          // a green no-op CI is forbidden
}
let all = [];
for (const f of files)
    all = all.concat(checkSource(fs.readFileSync(f, 'utf8'), f));
for (const e of all) console.error(e);
console.log(`${files.length} file(s) checked, ${all.length} structural error(s).`);
process.exit(all.length ? 1 : 0);
