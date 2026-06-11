# PB-SvgaLibrary

[![License](https://img.shields.io/github/license/Hawkynt/PB-SvgaLibrary)](https://github.com/Hawkynt/PB-SvgaLibrary/blob/main/LICENSE)
[![Language](https://img.shields.io/badge/language-PowerBASIC%2FDOS-8957D5)](https://github.com/Hawkynt/PB-SvgaLibrary)

[![CI](https://github.com/Hawkynt/PB-SvgaLibrary/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Hawkynt/PB-SvgaLibrary/actions/workflows/ci.yml)
![Last Commit](https://img.shields.io/github/last-commit/Hawkynt/PB-SvgaLibrary?branch=main)
![Activity](https://img.shields.io/github/commit-activity/m/Hawkynt/PB-SvgaLibrary)

[![Stars](https://img.shields.io/github/stars/Hawkynt/PB-SvgaLibrary?color=FFD700)](https://github.com/Hawkynt/PB-SvgaLibrary/stargazers)
[![Forks](https://img.shields.io/github/forks/Hawkynt/PB-SvgaLibrary?color=008080)](https://github.com/Hawkynt/PB-SvgaLibrary/network/members)
[![Issues](https://img.shields.io/github/issues/Hawkynt/PB-SvgaLibrary)](https://github.com/Hawkynt/PB-SvgaLibrary/issues)
![Code Size](https://img.shields.io/github/languages/code-size/Hawkynt/PB-SvgaLibrary?color=4CAF50)
![Repo Size](https://img.shields.io/github/repo-size/Hawkynt/PB-SvgaLibrary?color=FF9800)

[![Release](https://img.shields.io/github/v/release/Hawkynt/PB-SvgaLibrary)](https://github.com/Hawkynt/PB-SvgaLibrary/releases/latest)
[![Nightly](https://img.shields.io/github/v/release/Hawkynt/PB-SvgaLibrary?include_prereleases&sort=date&filter=nightly*&label=nightly&color=FF9800)](https://github.com/Hawkynt/PB-SvgaLibrary/releases)
[![Downloads](https://img.shields.io/github/downloads/Hawkynt/PB-SvgaLibrary/total)](https://github.com/Hawkynt/PB-SvgaLibrary/releases)

> High-performance Power BASIC 3.5 library for VESA graphics with micro-optimized assembly routines

This library provides a comprehensive set of functions and subroutines for working with SVGA graphics in Power BASIC 3.5. It features heavily optimized assembly code for pixel operations, drawing primitives, and image manipulation across VGA, Mode-X, and VESA modes.

## ✨ Features

- **🎯 Micro-Optimized Assembly:** Hand-tuned x86 assembly for maximum performance
- **📐 Graphics Primitives:** Hardware-accelerated lines, circles, rectangles, 3D bars, filled/outlined/textured triangles, textured rectangles and circles, and a bounded-memory scanline flood fill
- **🖼️ Multi-Format Image Support:** 
  - BMP (Windows Bitmap) - 4/8-bit color depths
  - PCX (ZSoft Paintbrush) - RLE compressed
  - ICO (Windows Icon) - Multiple icon support with index selection
  - CUR (Windows Cursor) - Static cursor files with hotspot support
  - ANI (Animated Cursor) - Multi-frame animations with resource management
  - TIF (TIFF) - PackBits and LZW compression support
  - TGA (Truevision) - RLE and uncompressed, multiple bit depths
  - GIF (Graphics Interchange) - LZW compression, transparency support
  - ICOLIB (Icon Libraries) - Extract icons from Windows DLL files
- **🔤 Font System:** Custom 8x8 monochrome and multi-color bitmap fonts with text rendering
- **🎨 Palette Management:** Full 256-color palette control
- **📺 Multi-Mode Support:**
  - VGA Mode 13h (320x200x256)
  - Mode-X (320x240 unchained planar 256-color)
  - Mode-Y (320x200 unchained planar, 4 video pages for page flipping)
  - Mode-Z (320x400 unchained planar, 2 video pages)
  - 800x600 in 16 colours (VGA tweaked mode 6Ah, bit-planed — write-mode-2 + bit-mask)
  - VESA (up to 1600x1200) — with width-specialized fast paths for 320/640/800/1024/1280/1600, GENERATED from a single template (`VESAOPT.TEMPLATE.BAS` + `scripts/gen-vesaopt.py`): the scanline offset is computed by shift/add instead of a multiply, fills use `REP STOSW` word bursts with single-byte trails, FillRect batches whole row groups per 64 KB bank, and FillCircle sweeps a precomputed integer span table so the bank only ever advances

  All graphics primitives are dispatched through a per-mode function-pointer table (`SVGADispatch`), so each mode plugs in its own optimized handlers at set-up time and the hot drawing paths never branch on the mode.
- **🪟 Virtual Coordinate System:** Viewport and scaling support
- **💾 Memory Management:** EMS support for large graphics buffers with ultra-fast clearing
- **⏰ High-Precision Timer System:** 10ms resolution interrupt-driven timers for smooth animations
- **🏃 Advanced Cursor Management:** Automatic background backup/restore with transparency
- **🎮 Sprite System:** Up to 32 sprites with real transparent pixel blits (colour 0 = transparent, direct-VRAM fast path in mode 13h), collision detection and priority rendering
- **📜 Scrolling Engine:** Hardware-accelerated scrolling with parallax layers and effects

## ⚡ Micro-Optimization Techniques

This library employs several advanced assembly optimization techniques for maximum performance on 8086/80286/80386 processors:

#### 1. **Parallel Instruction Execution**
```assembly
MOV BX, Y          ; Start: Y → BX
MOV AX, &HA000     ; Parallel: preload A000h in AX
```
Instructions are ordered to allow parallel execution where possible, reducing total cycle count.

#### 2. **Register Pressure Management**
```assembly
MOV DX, BX         ; Copy Y to DX for parallel shift path
MOV CX, X          ; In parallel: X → CX
```
Multiple registers are used to create parallel computation paths, avoiding pipeline stalls.

#### 3. **Optimized Address Calculation, avoiding multiplications and divisions**
```assembly
SHL BX, 8          ; BX = Y * 256
SHL DX, 6          ; DX = Y * 64 (parallel path)
ADD BX, DX         ; BX = Y * 320 (256 + 64)
```
The Y * 320 calculation is split into two shift operations that can partially overlap, faster than a single MUL instruction.

#### 4. **Instruction Interleaving**
```assembly
SHL BX, 8          ; Shift operation
MOV ES, AX         ; Segment setup (interleaved)
SHL DX, 6          ; Another shift
MOV AL, Color      ; Load color (interleaved)
```
Memory and ALU operations are interleaved to hide latency and maximize throughput.

### 🚀 Line Drawing Optimizations

* setting segment registers early to avoid penalties
* keeping track of when to switch VESA windows to minimize bank-switching
* exhausting plane operations to avoid repeated plane-switching

#### **Horizontal Lines**
- Uses `REP STOSW` for ultra-fast memory filling (2 pixels per write)
- Handles word alignment for maximum efficiency
- Color patterns pre-calculated as word values

#### **Vertical Lines**
- Pre-calculates starting offset once
- Uses constant stride for scanline advancement
- Tight assembly loop with minimal overhead

### 💨 Screen Clear Optimization

The `ClearVideoMemory` function provides ultra-fast A000h segment clearing:
```assembly
STOSW              ; Write 2 pixels at once (8086 compatible)
STOSW              ; Unrolled loop for maximum speed
STOSW              ; 16 STOSW operations per iteration
STOSW              ; Eliminates loop overhead
```
- **Unrolled Loop:** 16 STOSW operations per loop iteration
- **Maximum Speed:** Eliminates loop overhead for fastest possible clear
- **8086 Compatible:** Uses 16-bit operations for maximum compatibility
- **Direct VGA Access:** Targets A000h segment for hardware speed

## 🚀 Usage

### Recommended: link the precompiled library (`SVGA.PBL`)

The full library is larger than PowerBASIC/DOS's 64 KB-per-compilation-unit code limit, so the whole thing cannot be `$INCLUDE`d into one program. The build therefore ships a linkable **`SVGA.PBL`** (every module compiled as a separate `$COMPILE UNIT`, packed into ≤64 KB code segments) together with the **`SVGA.BI`** interface. The release zip contains exactly what a consumer needs: `SVGA.PBL`, the `SVGA.BI` interface (plus the `SVGATYPE.BI`/`SVGADECL.BI` files it pulls in), this README and the LICENSE. Grab it from the [latest release](../../releases/latest) and:

```basic
$INCLUDE "SVGA.BI"      ' types, globals and DECLAREs
$LINK "SVGA.PBL"        ' the compiled library (linked across several code segments)

CALL Svga_Init(0)
' Your code goes here
```

(`SVGA.PBL` is reproduced by `scripts/build-pbl.py`, which the CI build runs and then verifies by linking a pixel round-trip self-test.)

### Alternative: source-include individual modules

For a small program you can `$INCLUDE` only the `.SUB` modules you actually need (e.g. `TYPES.SUB`, `VGA.SUB`, `MODEX.SUB`). Including *everything* via `SVGA.SUB` will exceed the 64 KB unit limit — that is what `SVGA.PBL` is for.

## 📖 Complete API Reference

### 🎮 Mode Management

| Function | Description |
|---|---|
| `Svga_Init` | Initialize the SVGA library and dispatch table (call first) |
| `Svga_Version$()` | Return library version string ("major.minor.patch") |
| `Svga_Cleanup` | Clean up library resources (animations, sprites, cursor, timer) |
| `Vesa_SetResolution(xres, yres, colors)` | Set VESA resolution; auto-selects mode, falls back to Mode 13h |
| `Vesa_SetVgaMode(modeNumber)` | Set a specific VESA/VGA mode by number |
| `Vesa_Close` | Return to text mode |
| `Vesa_GetMode(xres, yres, colors)` | Return VESA mode number for the given resolution/colour depth |
| `Vesa_Info` | Display VESA BIOS version, video memory and available modes |
| `Vga_InitMode13h` | Initialize standard VGA Mode 13h (320x200x256) |
| `Vga_CloseVga` | Restore text mode from VGA Mode 13h |
| `ModeX_SetMode(modeXType)` | Initialize Mode-X (type selects 320x240/360x240/etc.) |
| `ModeY_SetMode` | Initialize Mode-Y (320x200 unchained, 4 video pages) |
| `ModeZ_SetMode` | Initialize Mode-Z (320x400 unchained, 2 video pages) |
| `Mode16_SetMode` | Initialize 800x600x16 bit-planed VGA tweaked mode (6Ah) |
| `ModeText_SetMode(textRows)` | Switch to text mode with the given row count |

### 🖊️ VGA Drawing Primitives

| Function | Description |
|---|---|
| `Vga_PutPixel(x, y, color)` | Ultra-optimized Mode 13h pixel write |
| `Vga_GetPixel(x, y)` | Ultra-optimized Mode 13h pixel read |
| `Vga_HLine(x1, x2, y, color)` | Hardware-optimized horizontal line |
| `Vga_VLine(x, y1, y2, color)` | Hardware-optimized vertical line |
| `Vga_LineDraw(x1, y1, x2, y2, color)` | Bresenham line algorithm |
| `Vga_FillRect(x1, y1, x2, y2, color)` | Filled rectangle |
| `Vga_DrawRect(x1, y1, x2, y2, color)` | Rectangle outline |
| `Vga_DrawCircle(cx, cy, r, color)` | Circle outline (midpoint algorithm) |
| `Vga_FillCircle(cx, cy, r, color)` | Filled circle |
| `Vga_ClearScreen(color)` | Ultra-fast screen clear |
| `Vga_CopyBlock(sx, sy, dx, dy, w, h)` | Block copy with overlap handling |
| `Vga_PatternFill(x1, y1, x2, y2, pattern)` | Pattern-based fill |

### 🎨 VESA Drawing Functions

| Function | Description |
|---|---|
| `VESA_PutPixel(x, y, color)` | VESA banked pixel write |
| `VESA_GetPixel(x, y, result)` | VESA banked pixel read |
| `VESA_HLine(x1, x2, y, color)` | VESA horizontal line with bank switching |
| `VESA_VLine(x, y1, y2, color)` | VESA vertical line with bank switching |
| `VESA_LineDraw(x1, y1, x2, y2, color)` | VESA Bresenham line with bank switching |
| `VESA_FillRect(x1, y1, x2, y2, color)` | VESA filled rectangle with bank batching |
| `VESA_DrawRect(x1, y1, x2, y2, color)` | VESA rectangle outline |
| `VESA_ClearScreen(color)` | VESA banked screen clear |
| `VESA_CopyBlock(sx, sy, dx, dy, w, h)` | VESA block copy across banks |
| `Vesa_CopyScanline(sx, sy, dx, dy, w)` | Copy a single scanline within VESA memory |

Per-width fast paths (`Vesa320_*` … `Vesa1600_*`) are generated from `VESAOPT.TEMPLATE.BAS` and plugged into the dispatch table automatically — they are not called directly.

### 🔲 Mode-X Functions

| Function | Description |
|---|---|
| `ModeX_InitTables` | Initialize Mode-X lookup tables |
| `ModeX_PutPixel(x, y, color)` | Mode-X planar pixel write |
| `ModeX_GetPixel(x, y)` | Mode-X planar pixel read |
| `ModeX_HLine(x1, x2, y, color)` | Mode-X optimized horizontal line |
| `ModeX_VLine(x, y1, y2, color)` | Mode-X optimized vertical line |
| `ModeX_LineDraw(x1, y1, x2, y2, color)` | Mode-X line drawing |
| `ModeX_FillRect(x1, y1, x2, y2, color)` | Mode-X filled rectangle |
| `ModeX_DrawRect(x1, y1, x2, y2, color)` | Mode-X rectangle outline |
| `ModeX_DrawCircle(cx, cy, r, color)` | Mode-X circle outline |
| `ModeX_FillCircle(cx, cy, r, color)` | Mode-X filled circle |
| `ModeX_ClearScreen(color)` | Mode-X screen clear |
| `ModeX_CopyBlock(sx, sy, dx, dy, w, h)` | Mode-X block copy |
| `ModeX_FastFill(x1, y1, x2, y2, color)` | Ultra-fast Mode-X fill |
| `ModeX_SetActivePage(page)` | Set active draw page |
| `ModeX_SetVisiblePage(page)` | Set visible display page |
| `ModeX_CopyPage(src, dest)` | Copy between pages |

### 🖼️ Image File Formats

| Function | Description |
|---|---|
| **BMP Support** | |
| `DrawBmp_Show(file$, x, y)` | Load and display a BMP file at (x, y) |
| `DrawBmp_GetSize(file$, width, height)` | Return BMP image dimensions (out params) |
| `DrawBmp_GetPalette(file$, pal(), depth)` | Extract BMP palette into array |
| **PCX Support** | |
| `DrawPcx_Show(file$, x, y)` | Load and display a PCX file at (x, y) |
| `DrawPcx_GetSize(file$, width, height)` | Return PCX image dimensions (out params) |
| `DrawPcx_GetPalette(file$, pal(), depth)` | Extract PCX palette into array |
| **ICO Support** | |
| `DrawIco_Show(file$, x, y, iconIndex)` | Display a single icon from an ICO file |
| `DrawIco_GetCount(file$)` | Return number of icons in an ICO file |
| `DrawIco_GetSize(file$, width, height)` | Return dimensions of the first icon |
| `DrawIco_GetInfo(file$, iconIndex, width, height, depth)` | Return size/depth for a specific icon |
| `DrawIco_GetPalette(file$, pal(), depth)` | Extract icon palette |
| `DrawIco_Extract(file$, iconIndex, buffer$, width, height)` | Extract raw icon bitmap to string buffer |
| **CUR Support** | |
| `DrawCur_Show(file$, x, y, cursorIndex)` | Display a cursor image from a CUR file |
| `DrawCur_GetCount(file$)` | Return number of cursors in a CUR file |
| `DrawCur_GetHotspot(file$, cursorIndex, hotX, hotY)` | Return cursor hotspot coordinates |
| `DrawCur_GetSize(file$, width, height)` | Return cursor image dimensions |
| `DrawCur_GetInfo(file$, cursorIndex, width, height, depth, hotX, hotY)` | Return full cursor metadata |
| `DrawCur_LoadBitmap(file$, cursorIndex, bitmap$, mask$, width, height, hotX, hotY)` | Load cursor bitmap and mask data |
| `DrawCur_Create(file$, bitmap$, mask$, width, height, hotX, hotY)` | Write a new CUR file from bitmap/mask data |
| `DrawCur_GetPalette(file$, pal(), depth)` | Extract cursor palette |
| **ANI (Animated Cursor) Support** | |
| `DrawAni_LoadAnimation(file$)` | Load an ANI file; returns animation handle |
| `DrawAni_ShowFrame(handle, x, y, frameIndex)` | Display a specific frame at (x, y) |
| `DrawAni_PlayAnimation(handle, x, y, loopCount)` | Play animation synchronously for loopCount loops |
| `DrawAni_StartAnimation(handle, x, y, loopCount, useTimer)` | Start async animation (timer-driven or manual) |
| `DrawAni_UpdateAnimation(handle, x, y)` | Advance and redraw animation (call each frame) |
| `DrawAni_AdvanceFrame(handle)` | Advance animation by one frame |
| `DrawAni_PauseAnimation(handle)` | Pause a running animation |
| `DrawAni_ResumeAnimation(handle)` | Resume a paused animation |
| `DrawAni_StopAnimation(handle)` | Stop animation playback |
| `DrawAni_FreezeAnimation(handle)` | Freeze on current frame (keep resources) |
| `DrawAni_ResetAnimation(handle)` | Reset animation to first frame |
| `DrawAni_IsPlaying(handle)` | Return non-zero if animation is currently playing |
| `DrawAni_GetAnimationState(handle)` | Return current animation state code |
| `DrawAni_GetFrameCount(handle)` | Return total number of frames |
| `DrawAni_GetFrameDelay(handle, frameIndex)` | Return delay for a specific frame (ticks) |
| `DrawAni_GetAnimationInfo(handle, width, height, frames, hotX, hotY)` | Return animation metadata |
| `DrawAni_SetAnimationSpeed(handle, speedMultiplier)` | Adjust playback speed |
| `DrawAni_SetAutoCleanup(handle, autoCleanup)` | Enable/disable automatic resource release on finish |
| `DrawAni_FreeAnimation(handle)` | Free all resources for an animation handle |
| `DrawAni_Show(file$, x, y)` | Load, play first frame, and free (simple one-shot display) |
| `DrawAni_GetSize(file$, width, height)` | Return animation frame dimensions |
| `DrawAni_GetPalette(file$, pal(), depth)` | Extract animation palette |
| **Extended Formats** | |
| `DrawTif_Show(file$, x, y)` | Display a TIFF image (PackBits or LZW) |
| `DrawTif_GetSize(file$, width, height)` | Return TIFF image dimensions |
| `DrawTif_GetInfo(file$, width, height, bps, compression)` | Return detailed TIFF metadata |
| `DrawTif_Extract(file$, buffer$, width, height)` | Extract raw TIFF pixel data to string buffer |
| `DrawTif_GetPalette(file$, pal(), depth)` | Extract TIFF palette |
| `DrawTga_Show(file$, x, y)` | Display a TGA image (RLE or uncompressed) |
| `DrawTga_GetSize(file$, width, height)` | Return TGA image dimensions |
| `DrawTga_GetInfo(file$, width, height, bpp, imageType)` | Return detailed TGA metadata |
| `DrawTga_GetPalette(file$, pal(), depth)` | Extract TGA palette |
| `DrawTga_Create(file$, buffer$, width, height, bpp)` | Write image data to a new TGA file |
| `DrawTga_Extract(file$, buffer$, width, height)` | Extract raw TGA pixel data to string buffer |
| `DrawGif_Show(file$, x, y)` | Display a GIF image (LZW, transparency) |
| `DrawGif_GetSize(file$, width, height)` | Return GIF image dimensions |
| `DrawGif_GetPalette(file$, pal(), depth)` | Extract GIF palette |
| **Icon Libraries (DLL/EXE)** | |
| `DrawIcl_LoadIcoLib(file$)` | Open a Windows DLL/EXE icon library; returns library handle |
| `DrawIcl_GetLibIconGroupCount(libHandle)` | Return number of icon groups in the library |
| `DrawIcl_GetLibIconGroupName$(libHandle, groupIndex)` | Return name of an icon group |
| `DrawIcl_ShowLibIcon(libHandle, groupIndex, iconIndex, x, y)` | Display an icon from the library |
| `DrawIcl_ExtractIcon(libHandle, groupIndex, iconIndex, data$, width, height)` | Extract icon bitmap to string buffer |
| `DrawIcl_DrawExtractedIcon(data$, width, height, x, y)` | Draw a previously extracted icon buffer |
| `DrawIcl_SaveLibIcon(libHandle, groupIndex, outFile$)` | Save a library icon to an ICO file |
| `DrawIcl_GetLibInfo(libHandle, file$, isPE, groupCount)` | Return library file metadata |
| `DrawIcl_CloseIcoLib(libHandle)` | Close an icon library and free its resources |
| `DrawIcl_ListSystemIcons(path$, fileList())` | List icon-bearing files in a directory |
| `DrawIcl_ExtractAllIcons(libHandle, outPath$)` | Export every icon group to individual ICO files |
| `DrawIcl_Show(file$, x, y)` | Load library, display first icon, close (simple one-shot) |
| `DrawIcl_GetSize(file$, width, height)` | Return dimensions of the first icon in a library |
| `DrawIcl_GetPalette(file$, pal(), depth)` | Extract palette of the first icon in a library |

### 🔤 Font System

| Function | Description |
|---|---|
| `Fonts_InitFont(fontFile$, displayMode)` | Load an 8x8 font file; displayMode controls console echo |
| `Fonts_VgaPrint(x, y, foreColor, backColor, text$, flags)` | Render text directly to video memory |
| `Fonts_BmpPrint(x, y, foreColor, backColor, text$, flags)` | Render text via pixel-level bitmap blits |
| `Fonts_GetFontInfo()` | Print current font metrics to console |

### 🎯 High-Level Graphics

| Function | Description |
|---|---|
| `Graphics_Bar(x1, y1, x2, y2, borderColor, fillColor)` | Filled rectangle with a separate border colour |
| `Graphics_Bar3d(x1, y1, x2, y2, depth, borderColor, fillColor)` | 3D-style bar with depth face |
| `Graphics_Box(x1, y1, x2, y2, color)` | Solid filled box |
| `Graphics_CircleDraw(cx, cy, rx, ry, startAngle, endAngle, color, fillMode)` | Circle, ellipse or arc with optional fill |
| `Graphics_Frame(x1, y1, x2, y2, color)` | Rectangle outline (frame only) |
| `Graphics_DrawTriangle(x1, y1, x2, y2, x3, y3, color)` | Triangle outline |
| `Graphics_FillTriangle(x1, y1, x2, y2, x3, y3, color)` | Filled triangle (fixed-point edge walker, one span per scanline) |
| `Graphics_TexTriangle(x1,y1,u1,v1, x2,y2,u2,v2, x3,y3,u3,v3, tex$, tw, th, transparent)` | Affine texture-mapped triangle |
| `Graphics_TexRect(x1, y1, x2, y2, tex$, texW, texH, transparentIdx)` | Textured (tiled) filled rectangle |
| `Graphics_TexCircle(cx, cy, r, tex$, texW, texH, transparentIdx)` | Textured filled circle |
| `Graphics_FloodFill(x, y, fillColor)` | Scanline flood fill (bounded span stack, never recurses) |

### 🪟 Virtual Coordinate System

| Function | Description |
|---|---|
| `Virtual_SetScale(xscale, yscale)` | Set coordinate scaling |
| `Virtual_GetScale(type, unused)` | Get current scale factor |
| `Virtual_SetWindow(maxx, maxy)` | Set virtual window size |
| `Virtual_SetViewport(x1, y1, x2, y2)` | Set viewport rectangle |
| `Virtual_DisableViewport` | Disable viewport clipping |
| `Virtual_ToPhysical(vx, vy, px, py)` | Convert virtual to physical |
| `Virtual_ToVirtual(px, py, vx, vy)` | Convert physical to virtual |
| `Virtual_IsVisible(vx, vy)` | Check if point is visible |
| `Virtual_GetDimensions(w, h)` | Get virtual dimensions |
| `Virtual_GetViewport(x1, y1, x2, y2)` | Get viewport bounds |
| `Virtual_SetOffset(xoff, yoff)` | Set coordinate offset |
| `Virtual_GetOffset(xoff, yoff)` | Get coordinate offset |
| `Virtual_Reset` | Reset virtual system |

### 💾 Memory Management

| Function | Description |
|---|---|
| `Memory_TakeEms(sizeKb, handle)` | Allocate EMS memory; returns handle via out param |
| `Memory_CloseEms(handle)` | Release an EMS allocation |
| `Memory_EmsByte(page, offset, value, handle)` | Read/write a byte in EMS (value=-1 reads) |
| `Memory_PutEmsByte(segment, offset, byteValue, handle)` | Write a single byte to EMS |
| `Memory_GetEmsByte(segment, offset, handle)` | Read a single byte from EMS |
| `Memory_PutEmsString(segment, offset, data$, handle)` | Write a string buffer to EMS |
| `Memory_GetEmsString$(segment, offset, length, handle)` | Read a string buffer from EMS |
| `Memory_SetVesaWindow(windowNumber)` | Switch the active VESA 64 KB bank |
| `Memory_MemCopy(srcSeg, srcOff, srcSize, dstSeg, dstOff, dstSize, byteCount)` | Low-level segmented memory block copy |
| `Memory_MemSwap(seg1, off1, size1, seg2, off2, size2, byteCount)` | Swap two segmented memory blocks |
| `Memory_ClearVideoMemory(color)` | Ultra-fast A000h segment clear (unrolled STOSW) |

### ⏰ High-Precision Timer System

| Function | Description |
|---|---|
| `Timer_Init` | Initialize the interrupt-driven timer system |
| `Timer_Cleanup` | Restore default timer interrupt and free resources |
| `Timer_GetTimerTick()` | Return current tick count (10 ms resolution) |
| `Timer_WaitTicks(tickCount)` | Block until tickCount ticks have elapsed |
| `Timer_Delay10Ms(count)` | Precise delay of count * 10 ms |
| `Timer_SetAnimTimer(frameDelay)` | Set the shared animation-timer interval (ticks) |
| `Timer_AnimTimerReady()` | Return non-zero if the animation-timer interval has elapsed |
| `Timer_GetElapsedTime()` | Return ticks elapsed since last `Timer_Reset` |
| `Timer_Reset` | Reset elapsed-time counter to zero |
| `Timer_Create(timerName, delayTicks)` | Create a named countdown timer |
| `Timer_IsTimerReady(timerName)` | Return non-zero if named timer has expired |
| `Timer_Destroy(timerName)` | Destroy a named timer |
| `Timer_OnTimer(intervalMs, handlerRoutine)` | Install a periodic interrupt callback (ms interval) |
| `Timer_OffTimer` | Remove the installed interrupt callback |
| `Timer_HrTimer(frequencyHz, handlerRoutine)` | Install a high-resolution PIT callback at given Hz |
| `Timer_Restore` | Restore standard 18.2 Hz timer frequency |
| `Timer_IsTimerInstalled()` | Return non-zero if a custom timer interrupt is active |
| `Timer_GetTimerFrequency()` | Return the current PIT frequency in Hz |
| `Timer_SetPriority(priority)` | Adjust interrupt mask for better real-time performance |

### 🏃 Advanced Cursor Management

| Function | Description |
|---|---|
| `Cursor_Init` | Initialize cursor management system |
| `Cursor_Set(fileName$, imageIndex)` | Load a cursor/icon file and set it as the active cursor |
| `Cursor_Move(newX, newY)` | Move cursor: restores old background, saves new, redraws |
| `Cursor_Show` | Make cursor visible |
| `Cursor_Hide` | Hide cursor |
| `Cursor_IsVisible()` | Return non-zero if cursor is currently visible |
| `Cursor_GetPos(currentX, currentY)` | Return current cursor position via out params |
| `Cursor_SetPos(newX, newY)` | Teleport cursor without background save/restore |
| `Cursor_Cleanup` | Restore background and release cursor resources |

### 🎮 Sprite Management System

| Function | Description |
|---|---|
| `Sprite_Init` | Initialize the sprite system (clears all slots) |
| `Sprite_Create(x, y, width, height, imageData$)` | Create a static sprite; returns handle (255 = no free slot) |
| `Sprite_CreateAnimated(x, y, animHandle)` | Create a sprite driven by an ANI animation handle |
| `Sprite_SetPosition(handle, x, y)` | Teleport sprite to absolute position |
| `Sprite_SetVelocity(handle, vx, vy)` | Set per-frame velocity |
| `Sprite_SetBounds(handle, left, top, right, bottom, movementMode)` | Set movement boundaries and bounce/wrap mode |
| `Sprite_SetFlags(handle, flags)` | Set sprite behaviour flags |
| `Sprite_SetPriority(handle, priority)` | Set drawing priority (lower = drawn first) |
| `Sprite_Move(handle)` | Apply velocity to one sprite |
| `Sprite_Draw(handle)` | Draw a single sprite with transparency |
| `Sprite_DrawAll` | Draw all active sprites sorted by priority |
| `Sprite_Collision(a, b)` | Check collision between two sprites (uses best method) |
| `Sprite_CollisionRect(a, b)` | Rectangle (AABB) collision test |
| `Sprite_CollisionCircle(a, b)` | Circle-distance collision test |
| `Sprite_CheckAllCollisions` | Check all registered collision pairs and fire callbacks |
| `Sprite_SetCollision(a, b, enable, callbackFunction)` | Register/unregister a collision pair with callback |
| `Sprite_UpdateAll` | Move all active sprites (apply velocities, check bounds) |
| `Sprite_GetInfo(handle, x, y, width, height, flags)` | Return sprite state via out params |
| `Sprite_Free(handle)` | Free one sprite slot |
| `Sprite_Cleanup` | Free all sprites and reset the sprite system |

### 📜 Scrolling Engine

| Function | Description |
|---|---|
| `Scroll_Init` | Initialize the scrolling system |
| `Scroll_Cleanup` | Free all scroll resources |
| `Scroll_SetVirtualScreen(width, height)` | Set virtual world dimensions |
| `Scroll_SetPosition(x, y)` | Set absolute scroll position |
| `Scroll_Screen(deltaX, deltaY)` | Scroll by a pixel delta |
| `Scroll_Direction(direction, speed)` | Scroll in a cardinal direction at given speed |
| `Scroll_HardwareHorizontal(lines, direction, fillColor)` | Hardware-shift rows horizontally and fill the exposed edge |
| `Scroll_HardwareVertical(lines, direction, fillColor)` | Hardware-shift columns vertically and fill the exposed edge |
| `Scroll_CreateParallaxLayer(layerId, width, height, scrollRateX, scrollRateY, priority)` | Register a parallax layer with fractional scroll rates |
| `Scroll_UpdateParallax` | Update all parallax layer positions |
| `Scroll_DrawParallax` | Draw all parallax layers by priority |
| `Scroll_DrawParallaxLayer(layerId)` | Draw a single parallax layer |
| `Scroll_FreeParallaxLayer(layerId)` | Remove and free a parallax layer |
| `Scroll_GetPosition(x, y)` | Return current scroll position via out params |
| `Scroll_SetMode(mode)` | Set scroll boundary/wrap behaviour |
| `Scroll_SmoothTo(targetX, targetY, speed)` | Step toward target; returns non-zero when arrived |
| `Scroll_ScreenShake(intensity, duration)` | Start a screen-shake effect |
| `Scroll_UpdateScreenShake` | Advance screen-shake one frame (call per frame) |

### 🎛️ Dispatch / Utility Functions

These call the per-mode handler selected by the current dispatch table, so the same call works under VGA, Mode-X, or VESA:

| Function | Description |
|---|---|
| `Svga_PutPixel(x, y, color)` | Generic pixel plot (dispatched to active mode) |
| `Svga_GetPixel(x, y)` | Generic pixel read (dispatched) |
| `Svga_LineDraw(x1, y1, x2, y2, color)` | Generic Bresenham line (dispatched) |
| `Svga_ClearScreen(color)` | Generic screen clear (dispatched) |
| `Svga_HLine(x1, x2, y, color)` | Generic horizontal line (dispatched) |
| `Svga_VLine(x, y1, y2, color)` | Generic vertical line (dispatched) |
| `Svga_FillRect(x1, y1, x2, y2, color)` | Generic filled rectangle (dispatched) |
| `Svga_DrawRect(x1, y1, x2, y2, color)` | Generic rectangle outline (dispatched) |
| `Svga_DrawCircle(cx, cy, r, color)` | Generic circle outline (dispatched) |
| `Svga_FillCircle(cx, cy, r, color)` | Generic filled circle (dispatched) |
| `Svga_WaitVRetrace` | Spin until vertical retrace starts |
| `Svga_WaitHRetrace` | Spin until horizontal retrace starts |
| `Svga_SetScale(xScale, yScale)` | Set global coordinate scaling |
| `Svga_GetScale(scaleType, unused)` | Return current scale factor |
| `Svga_SetWindow(maxX, maxY)` | Set logical window bounds |
| `Svga_SetView(x1, y1, x2, y2)` | Set clip viewport |

#### File I/O Utilities

| Function | Description |
|---|---|
| `FileUtil_OpenBinary(fileName$)` | Open a file for binary read; returns handle |
| `FileUtil_CloseBinary(fileHandle)` | Close a binary file |
| `FileUtil_ReadWord(fileHandle, value)` | Read a 16-bit word; returns success flag |
| `FileUtil_ReadDWord(fileHandle, value)` | Read a 32-bit dword; returns success flag |
| `FileUtil_ReadBytes(fileHandle, numBytes, dataBuf$)` | Read numBytes into a string buffer |
| `FileUtil_Seek(fileHandle, position)` | Seek to absolute byte position |
| `FileUtil_GetSize(fileHandle)` | Return total file size in bytes |
| `FileUtil_CanRead(fileHandle, numBytes)` | Return non-zero if numBytes remain before EOF |
| `FileUtil_Skip(fileHandle, numBytes)` | Skip forward numBytes |
| `FileUtil_ValidateSignature(fileHandle, expected$)` | Read and compare a file signature string |
| `FileUtil_LoadPalette(paletteData$, startIndex, numColors, scaleDown)` | Load RGB palette data into VGA DAC registers |
| `FileUtil_LoadPaletteBGRA(paletteData$, startIndex, numColors)` | Load BGRA palette data (Windows DIP format) into DAC |

## ✍️ Example

Here's a simple example of how to initialize a graphics mode, draw a box, and wait for a key press:

```basic
$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

' Initialize library and set 640x480x256 VESA mode
CALL Svga_Init
CALL Vesa_SetResolution(640, 480, 256)

' Draw a red filled rectangle
CALL Svga_FillRect(100, 100, 200, 200, 4)

' Wait for a key press
WHILE INKEY$ = "" : WEND

' Return to text mode
CALL Vesa_Close
CALL Svga_Cleanup
```

## 📄 Supported File Formats

### 🖼️ Image Formats

#### BMP (Windows Bitmap) Files
- **Supported Color Depths:** 4-bit (16 colors), 8-bit (256 colors)
- **Compression:** Uncompressed and RLE
- **Palette:** Automatically loaded and set for 8-bit images
- **Orientation:** Bottom-up (standard BMP format), can be rotated in 90° steps and mirrored during load
- **Usage:** `CALL DrawBmp_Show("image.bmp", x, y)`

#### PCX (ZSoft Paintbrush) Files  
- **Supported Color Depths:** 8-bit (256 colors)
- **Compression:** RLE (Run-Length Encoding) supported
- **Palette:** 256-color palette loaded from end of file (last 768 bytes)
- **Orientation:** can be rotated in 90° steps and mirrored during load
- **Usage:** `CALL DrawPcx_Show("image.pcx", x, y)`

#### ICO (Windows Icon) Files
- **Supported Color Depths:** 4-bit (16 colors), 8-bit (256 colors)
- **Multiple Icons:** Displays first icon in file, can select by index
- **Sizes:** Standard icon sizes (16x16, 32x32, etc.)
- **Transparency:** Basic transparency support, no alpha
- **Orientation:** can be rotated in 90° steps and mirrored during load
- **Usage:** `CALL DrawIco_Show("icon.ico", x, y, 0)` (last arg = icon index)

#### ANI (Animated Cursor) Files
- **Animation Support:** Multi-frame animated cursors
- **Frame Extraction:** Individual frames can be extracted
- **Orientation:** can be rotated in 90° steps and mirrored during load
- **Usage:** `h = DrawAni_LoadAnimation("anim.ani")` / `CALL DrawAni_ShowFrame(h, x, y, 0)`

### 🔤 Font Format

#### Custom 8x8 Monochrome Fonts
The library uses a custom text-based font format for 8x8 pixel fonts:

**File Structure:**
- **256 lines** (one for each ASCII character 0-255)
- Each line contains **8 space-separated decimal values** (0-255)
- Each value represents one horizontal line of the 8x8 character bitmap
- Bit 7 (MSB) = leftmost pixel, Bit 0 (LSB) = rightmost pixel

**Example Character (Letter 'A'):**
```
0 24 60 102 102 126 102 0
```
This represents:
```
00000000  (0)   - Top row (empty)
00011000  (24)  - Row 1:   ##
00111100  (60)  - Row 2:  ####  
01100110  (102) - Row 3: ##  ##
01100110  (102) - Row 4: ##  ##
01111110  (126) - Row 5: ######
01100110  (102) - Row 6: ##  ##
00000000  (0)   - Bottom row (empty)
```

**Creating Custom Fonts:**
1. Create a text file with 256 lines
2. Each line must have exactly 8 space-separated decimal values (0-255)
3. Characters 0-31 are control characters, 32-126 are printable ASCII
4. Characters 128-255 can be used for extended/international characters

**Usage:**
```basic
CALL Fonts_InitFont("myfont.txt", 0)              ' Load font (0 = silent)
CALL Fonts_VgaPrint(x, y, foreColor, 0, "Hello World", 0)
```

#### Custom Bitmap Fonts

- fonts get loaded from folder and blitted by used character, must be fixed width

### 💾 Sprite and Block Formats

#### Sprite Data Format
- **Memory Format:** String-based sprite storage
- **Transparency:** Supports transparent color values
- **Compression:** Simple RLE compression for sprites
- **Usage:** Memory-based sprite manipulation functions

### ⚙️ Configuration and Compatibility

#### Mode-13h Support
- **Resolutions:** 320x200
- **Color Depth:** 8-bit (256 colors) linear
- **Memory:** Linear 64KB

#### Mode-X Support
- **Resolutions:** 320x240, 360x240, 320x400, 360x400, 320x480, 360x480, 256x256, 400x300
- **Color Depth:** 8-bit (256 colors) 
- **Optimization:** Optimized for animation and efficient pixel/block operations
- **Memory:** 4-planar, plane switched, interleaved pixels

#### VESA Mode Support
- **Standard Modes:** 640x480, 800x600, 1024x768, 1280x1024
- **Color Depths:** 8-bit (256 colors), 16-bit, 24-bit
- **Fallback:** Automatic fallback to VGA Mode 13h if VESA unavailable
- **Memory:** Bank-switched in 64KB blocks

#### Hardware Requirements
- **Minimum:** VGA-compatible graphics card (256KB for Mode-X)
- **Recommended:** VESA 2.0 compatible graphics card
- **Memory:** 640KB conventional + optional EMS for large images
- **DOS Version:** MS-DOS 3.3 or compatible

#### Power BASIC Integration
```basic
' Link the precompiled library
$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

' Initialize library and set graphics mode
CALL Svga_Init
CALL Vesa_SetResolution(800, 600, 256)

' Load and display resources
CALL Fonts_InitFont("font8x8.txt", 0)
CALL DrawBmp_Show("background.bmp", 0, 0)
CALL Fonts_VgaPrint(100, 100, 15, 0, "Hello SVGA!", 0)

' Cleanup
CALL Vesa_Close
CALL Svga_Cleanup
```

## ✅ Recently Implemented Features

### Complete Animation and Resource Management System

The library now includes a comprehensive animation system with full resource management:

```basic
' Load and manage animations
animHandle = DrawAni_LoadAnimation("animated.ani")
CALL DrawAni_StartAnimation(animHandle, 100, 80, 0, 1)  ' x, y, loops=0=infinite, useTimer=1

' Resource management
CALL DrawAni_PauseAnimation(animHandle)      ' Pause animation
CALL DrawAni_ResumeAnimation(animHandle)     ' Resume paused animation
CALL DrawAni_FreezeAnimation(animHandle)     ' Stop but keep resources
state = DrawAni_GetAnimationState(animHandle) ' Get current state

' Auto-cleanup and per-frame update
CALL DrawAni_SetAutoCleanup(animHandle, 1)
CALL DrawAni_UpdateAnimation(animHandle, 100, 80)  ' Call once per frame
```

### Advanced Sprite Management System

Complete sprite system with collision detection and priority rendering:

```basic
' Initialize sprite system
CALL Sprite_Init

' Create sprites
spriteHandle = Sprite_Create(x, y, width, height, imageData$)
animSprite   = Sprite_CreateAnimated(x, y, animHandle)

' Movement and physics
CALL Sprite_SetVelocity(spriteHandle, vx, vy)
CALL Sprite_SetBounds(spriteHandle, 0, 0, 319, 199, 1)  ' bounce mode
CALL Sprite_UpdateAll  ' Apply velocities, check bounds for all sprites

' Collision detection
IF Sprite_Collision(sprite1, sprite2) THEN
    ' Handle collision
END IF
CALL Sprite_SetCollision(sprite1, sprite2, 1, CODEPTR(CollisionCallback))

' Priority rendering
CALL Sprite_SetPriority(spriteHandle, 1)
CALL Sprite_DrawAll  ' Draw all sprites sorted by priority
```

### Hardware-Accelerated Scrolling Engine

Multi-layer parallax scrolling with hardware acceleration:

```basic
' Initialize and set up virtual world
CALL Scroll_Init
CALL Scroll_SetVirtualScreen(2048, 1536)           ' Large virtual world
CALL Scroll_SetPosition(playerX - 160, playerY - 100)  ' Center on player

' Hardware pixel-shift scrolling
CALL Scroll_HardwareHorizontal(200, 0, 0)  ' Shift 200 cols left, fill black
CALL Scroll_HardwareVertical(50, 1, 15)    ' Shift 50 rows down, fill color 15

' Parallax layers
CALL Scroll_CreateParallaxLayer(0, 1024, 768, 128, 128, 0)  ' Background ~50% speed
CALL Scroll_CreateParallaxLayer(1, 800, 600, 192, 192, 1)   ' Midground ~75% speed
CALL Scroll_UpdateParallax  ' Advance layer positions
CALL Scroll_DrawParallax    ' Render layers by priority

' Screen shake effect
CALL Scroll_ScreenShake(4, 30)      ' intensity=4, duration=30 frames
CALL Scroll_UpdateScreenShake       ' Call once per frame
```

### Enhanced Cursor Management

Automatic background backup/restore with transparency support:

```basic
' Initialize and load cursor from a CUR file
CALL Cursor_Init
CALL Cursor_Set("cursor.cur", 0)   ' fileName, imageIndex

' Automatic damage-free movement
CALL Cursor_Move(mouseX, mouseY)   ' Restores old background, saves new
CALL Cursor_Show
' ... later:
CALL Cursor_Hide

' Query cursor state
visible = Cursor_IsVisible()
CALL Cursor_GetPos(currentX, currentY)
```

### High-Precision Timer System

Interrupt-driven 10ms resolution timing:

```basic
' Initialize 10ms precision timing (done automatically by Svga_Init)
CALL Timer_Init
currentTick = Timer_GetTimerTick()  ' Get current 10ms tick

' Named timers
CALL Timer_Create(0, 50)            ' Timer 0: 50-tick (500 ms) interval
IF Timer_IsTimerReady(0) THEN       ' Non-blocking poll
    ' Timer elapsed, do something
END IF

' Interrupt-driven callbacks
result = Timer_OnTimer(100, CODEPTR(TimerCallback))  ' Fire every 100 ms
' TimerCallback SUB is called automatically
CALL Timer_OffTimer  ' Remove when done

' High-resolution delays
CALL Timer_Delay10Ms(10)  ' Precise 100 ms delay (10 * 10 ms)
```

### Multi-Format Image Support

Extended format support with compression and transparency:

```basic
' Additional image formats
CALL DrawTif_Show("image.tif", x, y)     ' TIFF with PackBits/LZW
CALL DrawTga_Show("image.tga", x, y)     ' TGA with RLE support
CALL DrawGif_Show("image.gif", x, y)     ' GIF with transparency

' Windows DLL/EXE icon extraction
libHandle  = DrawIcl_LoadIcoLib("shell32.dll")
groupCount = DrawIcl_GetLibIconGroupCount(libHandle)
CALL DrawIcl_ShowLibIcon(libHandle, 0, 0, x, y)  ' group 0, icon 0
CALL DrawIcl_CloseIcoLib(libHandle)
```

## 🚧 Future Enhancements

### Potential Additional Features

- **Sound Integration:** MOD/S3M music playback with sample mixing
- **Network Support:** IPX/TCP multiplayer game support  
- **Compression:** LZ77/Huffman compression for sprites and images
- **Hardware Support:** Enhanced VGA features (unchained Mode-X variants)
- **File Formats:** PNG support with proper alpha blending

## 🎮 Demo Games

`demos/` holds eleven self-contained showcase games, each a real `SVGA.PBL`
consumer (`$INCLUDE "SVGA.BI"` + `$LINK "SVGA.PBL"`) with its assets beside it.
Build one with `PBC.EXE -CE -G386 -FNPX <NAME>.BAS` next to the released
`SVGA.PBL`/`SVGA.BI` files and run the `.EXE` under DOS or DOSBox. Every demo
also accepts a `SMOKE` command-line argument that plays a short scripted
session and exits - CI uses it to keep all of them green.

| Demo | Genre | Highlights |
|---|---|---|
| `MINI` | hello world | the minimal consumer skeleton |
| `PLATFORM` | 2D platformer | tile level, gravity/jump physics, parallax hills, coins, patrol enemies |
| `SCROLLER` | side-scrolling shmup | 3-layer parallax starfield, enemy waves, explosions |
| `TOPSHOOT` | top-down arena shooter | wave spawner, chasing enemies, pickups, health bar |
| `CARDS` | memory card game | INT 33h mouse, library `.CUR` cursor + animated `.ANI` while waiting |
| `FPS3D` | raycasting ego-shooter | 160-ray DDA, fixed-point, distance-shaded walls, minimap |
| `TACTICS` | tactical RPG | BFS movement ranges, terrain costs, AI vs AI battles |
| `ACTRPG` | action RPG | 4-room world, sword combat, palette-animated water, key/chest quest |
| `TURNRPG` | turn-based JRPG | overworld + menu battles, damage numbers, boss fight |
| `CITYSIM` | city builder | road-graph traffic simulation with congestion feedback |
| `RACER` | pseudo-3D racing | segment-projected road, curves/hills, AI cars, 2-lap race |

All gameplay drawing goes through the library: `Svga_SetRes` for mode set-up,
`Svga_SetPalette` for colours, the `Svga_*`/`Graphics_*`/`Fonts_*` primitives
for everything on screen.

## 🛠️ Building

The library targets **PowerBASIC 3.5 for DOS**: `$INCLUDE "SVGA.SUB"` in your program and compile with `PB.EXE` (runs fine under [DOSBox](https://www.dosbox.com/)).

- The per-width VESA fast paths (`VOPT*.SUB`, `VESAOPT.SUB`, `VESAOPT.INC`) are **generated** from `VESAOPT.TEMPLATE.BAS` by `scripts/gen-vesaopt.py` and are not committed — every pipeline stage regenerates them; run the tool locally before compiling against the umbrella include.
- The library version is defined once in `TYPES.SUB` (`%SVGA_VERSION_*`), readable at runtime via `Svga_Version$`, and CI/CD derives nightly and release names from it.
- CI verifies every source structurally (balanced `SUB`/`FUNCTION`/`IF`/`FOR`/`DO`/`SELECT` blocks) via `node .github/workflows/scripts/check-basic.mjs .` and runs the full xUnit-style test battery (`tests/*.BAS`, one suite per module) with the real PB 3.5 compiler under DOSBox via `scripts/run-pb-tests.sh`.
- The nightly/release builds compile every module as a `$COMPILE UNIT`, assemble **`SVGA.PBL`** with PBLIB, link and run a pixel round-trip self-test, and publish the minimal consumer zip.

## ❤️ Support

If this project saves you time or money, consider supporting its development:

[![GitHub Sponsors](https://img.shields.io/badge/GitHub-Sponsor-EA4AAA?logo=githubsponsors)](https://github.com/sponsors/Hawkynt)
[![PayPal](https://img.shields.io/badge/PayPal-Donate-00457C?logo=paypal)](https://www.paypal.me/hawkynt)

## 📜 License

Licensed under LGPL-3.0-or-later — see [LICENSE](LICENSE).