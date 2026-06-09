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
- **📐 Graphics Primitives:** Hardware-accelerated lines, circles, rectangles, and 3D bars
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
  - VESA (up to 1600x1200) — with width-specialized fast paths for 320/640/800/1024/1280: the scanline offset is computed by shift/add instead of a multiply, and the span primitives (HLine/VLine/FillRect/DrawRect) fill whole runs, switching the VESA bank only at 64 KB boundaries (never per pixel)

  All graphics primitives are dispatched through a per-mode function-pointer table (`SVGADispatch`), so each mode plugs in its own optimized handlers at set-up time and the hot drawing paths never branch on the mode.
- **🪟 Virtual Coordinate System:** Viewport and scaling support
- **💾 Memory Management:** EMS support for large graphics buffers with ultra-fast clearing
- **⏰ High-Precision Timer System:** 10ms resolution interrupt-driven timers for smooth animations
- **🏃 Advanced Cursor Management:** Automatic background backup/restore with transparency
- **🎮 Sprite System:** Up to 32 sprites with collision detection and priority rendering
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

To use this library in your Power BASIC project, you need to include the `SVGA.SUB` file in your main program using the `$INCLUDE` metacommand. This includes everything else.

```basic
$INCLUDE "SVGA.SUB"

' Your code goes here
```

## 📖 Complete API Reference

### 🎮 Mode Management

| Function | Description |
|---|---|
| `Svga_Init` | Initialize the SVGA library (call first) |
| `Svga_SetRes(xres, yres, colors)` | Set graphics resolution (auto-selects best mode) |
| `Svga_SetVga(mode)` | Set specific VESA mode number |
| `ModeX_SetMode(mode)` | Initialize Mode-X graphics mode (320x240 unchained) |
| `ModeY_SetMode` | Initialize Mode-Y (320x200 unchained, 4 pages) |
| `ModeZ_SetMode` | Initialize Mode-Z (320x400 unchained, 2 pages) |
| `Mode16_SetMode` | Initialize 800x600x16 bit-planed VGA tweaked mode (6Ah) |
| `VGA_InitMode13h` | Initialize standard VGA Mode 13h |
| `Svga_Close` | Return to text mode |
| `Svga_Cleanup` | Clean up library resources |
| `Svga_Info` | Display VESA capabilities information |
| `Svga_GetVesaMode(xres, yres, colors)` | Get VESA mode number for resolution |

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
| `Vesa_PutPixel(x, y, color)` | VESA banked pixel write |
| `Vesa_GetPixel(x, y)` | VESA banked pixel read |
| `Vesa_HLine(x1, x2, y, color)` | VESA horizontal line with banking |
| `Vesa_VLine(x, y1, y2, color)` | VESA vertical line with banking |
| `Vesa_LineDraw(x1, y1, x2, y2, color)` | VESA line drawing |
| `Vesa_FillRect(x1, y1, x2, y2, color)` | VESA filled rectangle |
| `Vesa_DrawRect(x1, y1, x2, y2, color)` | VESA rectangle outline |
| `Vesa_ClearScreen(color)` | VESA screen clear with banking |
| `Vesa_CopyBlock(sx, sy, dx, dy, w, h)` | VESA block copy |
| `Vesa_CopyScanline(sx, sy, dx, dy, w)` | Single scanline copy |

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
| `DrawBmp_Show(file, x, y)` | Load and display BMP file |
| `DrawBmp_GetSize(file, width, height)` | Get BMP dimensions |
| `DrawBmp_GetPalette(file, pal[], depth)` | Extract BMP palette |
| **PCX Support** | |
| `DrawPcx_Show(file, x, y)` | Load and display PCX file |
| `DrawPcx_GetSize(file, width, height)` | Get PCX dimensions |
| `DrawPcx_GetPalette(file, pal[], depth)` | Extract PCX palette |
| **Icon/Cursor Support** | |
| `LOADICO(filename, index)` | Load ICO file, return handle |
| `DRAWICO(handle, x, y)` | Draw loaded ICO image |
| `FREEICO(handle)` | Free ICO resources |
| `LOADCUR(filename, index)` | Load CUR file, return handle |
| `DRAWCUR(handle, x, y)` | Draw loaded CUR image |
| `FREECUR(handle)` | Free CUR resources |
| **Animation Support** | |
| `LOADANI(filename)` | Load ANI file, return handle |
| `SHOWANIFRAME(handle, x, y, frame)` | Display specific ANI frame |
| `PLAYANI(handle, x, y, loops)` | Play ANI animation |
| `PAUSEANI(handle)` | Pause animation playback |
| `RESUMEANI(handle)` | Resume paused animation |
| `STOPANI(handle)` | Stop animation |
| `FREEZEANI(handle)` | Freeze animation (keep resources) |
| `STARTANI(handle, x, y, loops, timer)` | Start animation with timer |
| `GETANISTATE(handle)` | Get animation state |
| `GETANIFRAMECOUNT(handle)` | Get number of frames |
| `GETANIFRAMEDELAY(handle, frame)` | Get frame delay |
| `SETANIAUTOCLEANUP(handle, flag)` | Set auto-cleanup flag |
| `UPDATEANI(handle, x, y)` | Update animation (call in main loop) |
| `FREEANI(handle)` | Free animation resources |
| **Extended Formats** | |
| `DrawTif_Show(filename, x, y)` | Draw TIFF image (PackBits/LZW) |
| `DrawTif_GetSize(file, width, height)` | Get TIFF dimensions |
| `DrawTga_Show(filename, x, y)` | Draw TGA image (RLE/uncompressed) |
| `DrawTga_GetSize(file, width, height)` | Get TGA dimensions |
| `DrawGif_Show(filename, x, y)` | Draw GIF image (LZW/transparency) |
| `DrawGif_GetSize(file, width, height)` | Get GIF dimensions |
| **Icon Libraries** | |
| `OPENICOLIB(filename)` | Open Windows DLL icon library |
| `GETICOLIBCOUNT(handle)` | Get number of icon groups |
| `EXTRACTICON(handle, groupID, index)` | Extract icon from library |
| `CLOSEICOLIB(handle)` | Close icon library |

### 🔤 Font System

| Function | Description |
|---|---|
| `Font_Init(file, mode)` | Load 8x8 bitmap font |
| `Font_Print(x, y, fg, bg, text, flags)` | Print text with current font |
| `Font_PrintBmp(x, y, fg, bg, text, flags)` | Print text as bitmap |
| `Font_GetInfo()` | Get font metrics |

### 🎯 High-Level Graphics

| Function | Description |
|---|---|
| `BAR(x1, y1, x2, y2, border, fill)` | Rectangle with border and fill |
| `BAR3D(x1, y1, x2, y2, depth, border, fill)` | 3D-style bar |
| `BOX(x1, y1, x2, y2, color)` | Filled box |
| `CIRCLEDRAW(cx, cy, rx, ry, start, end, color, fill)` | Circle/ellipse/arc |
| `FRAME(x1, y1, x2, y2, color)` | Rectangle frame |
| `Svga_PutPixel(x, y, color)` | Generic pixel plot |

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
| `Memory_TakeEms(sizekb, handle)` | Allocate EMS memory |
| `Memory_CloseEms(handle)` | Free EMS memory |
| `Memory_EmsByte(page, offset, value, handle)` | Read/write EMS byte |
| `Memory_PutEmsByte(seg, off, byte, handle)` | Write byte to EMS |
| `Memory_GetEmsByte(seg, off, handle)` | Read byte from EMS |
| `Memory_PutEmsString(seg, off, data, handle)` | Write string to EMS |
| `Memory_GetEmsString(seg, off, len, handle)` | Read string from EMS |
| `Vesa_SetWindow(window)` | Set VESA bank window |
| `Memory_Copy(sseg, soff, ssize, dseg, doff, dsize, bytes)` | Memory block copy |
| `Memory_Swap(seg1, off1, size1, seg2, off2, size2, bytes)` | Memory block swap |
| `Memory_ClearVideo(color)` | Ultra-fast A000h segment clear |

### ⏰ High-Precision Timer System

| Function | Description |
|---|---|
| `Timer_Init` | Initialize 10ms precision timer system |
| `Timer_GetTick` | Get current timer tick (10ms resolution) |
| `Timer_WaitTicks(count)` | Wait for specified number of ticks |
| `Timer_Delay10Ms(count)` | High-resolution delay function |
| `Timer_SetAnim(delay)` | Set animation timer delay |
| `Timer_IsAnimReady` | Check if animation timer is ready |
| `Timer_GetElapsed` | Get elapsed time since init |
| `Timer_Reset` | Reset timer system |
| `Timer_Create(id, delay)` | Create named timer |
| `Timer_IsReady(id)` | Check if named timer is ready |
| `Timer_Destroy(id)` | Destroy named timer |
| `Timer_OnTimer(interval, callback)` | Install timer interrupt handler |
| `Timer_OffTimer` | Remove timer interrupt handler |
| `Timer_HrTimer(freq, callback)` | High-resolution PIT timer |
| `Timer_Restore` | Restore default timer frequency |
| `Timer_Cleanup` | Cleanup timer system |

### 🏃 Advanced Cursor Management

| Function | Description |
|---|---|
| `Cursor_Init` | Initialize cursor management system |
| `Cursor_Load(filename, index)` | Load cursor from ICO/CUR file |
| `Cursor_Set(handle)` | Set active cursor |
| `Cursor_Move(x, y)` | Move cursor with auto backup/restore |
| `Cursor_Show` | Make cursor visible |
| `Cursor_Hide` | Hide cursor |
| `Cursor_IsVisible` | Check cursor visibility |
| `Cursor_GetPos(x, y)` | Get current cursor position |
| `Cursor_Update` | Update cursor display |
| `Cursor_Free(handle)` | Free cursor resources |
| `Cursor_Cleanup` | Cleanup cursor system |

### 🎮 Sprite Management System

| Function | Description |
|---|---|
| `INITSPRITES` | Initialize sprite system |
| `CREATESPRITE(x, y, w, h, data)` | Create static sprite |
| `CREATEANIMSPRITE(x, y, anim)` | Create animated sprite |
| `SETSPRITEPOS(handle, x, y)` | Set sprite position |
| `SETSPRITEVELOCITY(handle, vx, vy)` | Set sprite velocity |
| `SETSPRITEBOUNDS(handle, l, t, r, b, mode)` | Set movement boundaries |
| `SETSPRITEFLAGS(handle, flags)` | Set sprite flags |
| `SETSPRITEPRIORITY(handle, priority)` | Set drawing priority |
| `MOVESPRITE(handle)` | Move sprite by velocity |
| `DRAWSPRITE(handle)` | Draw single sprite |
| `DRAWALLSPRITES` | Draw all sprites by priority |
| `SPRITECOLLISION(a, b)` | Check collision between sprites |
| `SPRITECOLLISIONRECT(a, b)` | Rectangle collision detection |
| `SPRITECOLLISIONCIRCLE(a, b)` | Circle collision detection |
| `CHECKALLCOLLISIONS` | Check all sprite collisions |
| `SETSPRITECOLLISION(a, b, enable, callback)` | Set collision relationship |
| `UPDATEALLSPRITES` | Update all sprite positions |
| `GETSPRITEINFO(handle, x, y, w, h, flags)` | Get sprite information |
| `FREESPRITE(handle)` | Free sprite resources |
| `CLEANUPSPRITES` | Cleanup sprite system |

### 📜 Scrolling Engine

| Function | Description |
|---|---|
| `INITSCROLL` | Initialize scrolling system |
| `SETVIRTUALSCREEN(width, height)` | Set virtual screen dimensions |
| `SETSCROLLPOS(x, y)` | Set absolute scroll position |
| `SCROLLSCREEN(dx, dy)` | Scroll by pixel amount |
| `SCROLLDIRECTION(dir, speed)` | Scroll in direction |
| `HSCROLLHARDWARE(lines, dir, fill)` | Hardware horizontal scroll |
| `VSCROLLHARDWARE(lines, dir, fill)` | Hardware vertical scroll |
| `CREATEPARALLAXLAYER(id, w, h, rx, ry, pri)` | Create parallax layer |
| `UPDATEPARALLAX` | Update parallax layer positions |
| `DRAWPARALLAX` | Draw all parallax layers |
| `DRAWPARALLAXLAYER(id)` | Draw single parallax layer |
| `GETSCROLLPOS(x, y)` | Get current scroll position |
| `SETSCROLLMODE(mode)` | Set scroll boundary behavior |
| `SMOOTHSCROLLTO(x, y, speed)` | Smooth scroll to target |
| `SCREENSHAKE(intensity, duration)` | Screen shake effect |
| `UPDATESCREENSHAKE` | Update shake effect (call per frame) |
| `FREEPARALLAXLAYER(id)` | Free parallax layer |
| `CLEANUPSCROLL` | Cleanup scrolling system |

### 🎛️ Utility Functions

| Function | Description |
|---|---|
| `Svga_PutPixel(x, y, color)` | Generic pixel plot (dispatched) |
| `Svga_GetPixel(x, y)` | Generic pixel read (dispatched) |
| `Svga_LineDraw(x1, y1, x2, y2, color)` | Generic line (dispatched) |
| `Svga_ClearScreen(color)` | Generic clear (dispatched) |
| `Svga_HLine(x1, x2, y, color)` | Generic horizontal line |
| `Svga_VLine(x, y1, y2, color)` | Generic vertical line |
| `Svga_FillRect(x1, y1, x2, y2, color)` | Generic filled rectangle |
| `Svga_DrawRect(x1, y1, x2, y2, color)` | Generic rectangle outline |
| `Svga_DrawCircle(cx, cy, r, color)` | Generic circle outline |
| `Svga_FillCircle(cx, cy, r, color)` | Generic filled circle |
| `Svga_WaitVRetrace` | Wait for vertical retrace |
| `Svga_WaitHRetrace` | Wait for horizontal retrace |
| `Svga_SetScale(xscale, yscale)` | Set global scaling |
| `Svga_GetScale(type, unused)` | Get global scale |
| `Svga_SetWindow(maxx, maxy)` | Set VGA window |
| `Svga_SetViewport(x1, y1, x2, y2)` | Set VGA viewport |

## ✍️ Example

Here's a simple example of how to initialize a graphics mode, draw a box, and wait for a key press:

```basic
$INCLUDE "SVGA.SUB"

' Initialize a 640x480 graphics mode with 256 colors
CALL Svga_SetRes(640, 480, 256)

' Draw a red box
CALL Svga_FillRect(100, 100, 200, 200, 4)

' Wait for a key press
WHILE INKEY$ = "" : WEND

' Return to text mode
CALL Svga_Close
```

## 📄 Supported File Formats

### 🖼️ Image Formats

#### BMP (Windows Bitmap) Files
- **Supported Color Depths:** 4-bit (16 colors), 8-bit (256 colors)
- **Compression:** Uncompressed and RLE
- **Palette:** Automatically loaded and set for 8-bit images
- **Orientation:** Bottom-up (standard BMP format), can be rotated in 90° steps and mirrored during load
- **Usage:** `CALL SHOWBMP("image.bmp", x, y)`

#### PCX (ZSoft Paintbrush) Files  
- **Supported Color Depths:** 8-bit (256 colors)
- **Compression:** RLE (Run-Length Encoding) supported
- **Palette:** 256-color palette loaded from end of file (last 768 bytes)
- **Orientation:** can be rotated in 90° steps and mirrored during load
- **Usage:** `CALL SHOWPCX("image.pcx", x, y)`

#### ICO (Windows Icon) Files
- **Supported Color Depths:** 4-bit (16 colors), 8-bit (256 colors)
- **Multiple Icons:** Displays first icon in file, can select by index
- **Sizes:** Standard icon sizes (16x16, 32x32, etc.)
- **Transparency:** Basic transparency support, no alpha
- **Orientation:** can be rotated in 90° steps and mirrored during load
- **Usage:** `CALL SHOWICON("icon.ico", x, y)`

#### ANI (Animated Cursor) Files
- **Animation Support:** Multi-frame animated cursors
- **Frame Extraction:** Individual frames can be extracted
- **Orientation:** can be rotated in 90° steps and mirrored during load
- **Usage:** Animation functions for frame-by-frame display

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
CALL INITFONT("myfont.txt", 0)  ' Load font silently
CALL VGAPRINT(x, y, color, bgcolor, "Hello World", flags)
```

#### Custom Bitmap Fonts

- fonts get loaded from folder and blitted by used character, must be fixed width

### 💾 Sprite and Block Formats

#### SVB (SVGA Block) Files
- **Purpose:** Save/load rectangular screen areas
- **Format:** Custom binary format storing pixel data
- **Usage:** 
  - Save: `CALL SAVESVB("block.svb", x1, y1, x2, y2)`
  - Load: `CALL LOADSVB("block.svb", x, y)`

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
' Include the modular library
$INCLUDE "SVGA.SUB"

' Initialize library
CALL Svga_Init

' Set graphics mode
CALL Svga_SetRes(800, 600, 256)

' Load and display resources
CALL Font_Init("font8x8.txt", 0)
CALL DrawBmp_Show("background.bmp", 0, 0)
CALL Font_Print(100, 100, 15, 0, "Hello SVGA!", 0)

' Cleanup
CALL Svga_Cleanup
```

## ✅ Recently Implemented Features

### Complete Animation and Resource Management System

The library now includes a comprehensive animation system with full resource management:

```basic
' Load and manage animations
animHandle = DrawAni_Load("animated.ani")
CALL DrawAni_Start(animHandle, x, y, loopCount, useTimer)

' Resource management
CALL DrawAni_Pause(animHandle)      ' Pause animation
CALL DrawAni_Resume(animHandle)     ' Resume paused animation
CALL DrawAni_Freeze(animHandle)     ' Stop but keep resources
state = DrawAni_GetState(animHandle) ' Get current state

' Auto-cleanup and timer integration
CALL DrawAni_SetAutoCleanup(animHandle, 1)
CALL DrawAni_Update(animHandle, x, y)  ' Call in main loop
```

### Advanced Sprite Management System

Complete sprite system with collision detection and priority rendering:

```basic
' Create sprites
spriteHandle = CREATESPRITE(x, y, width, height, imageData)
animSprite = CREATEANIMSPRITE(x, y, animHandle)

' Movement and physics
CALL SETSPRITEVELOCITY(spriteHandle, vx, vy)
CALL SETSPRITEBOUNDS(spriteHandle, left, top, right, bottom, bounceMode)
CALL UPDATEALLSPRITES  ' Updates all sprite positions

' Collision detection
IF SPRITECOLLISION(sprite1, sprite2) THEN
    ' Handle collision
END IF
CALL SETSPRITECOLLISION(sprite1, sprite2, 1, CODEPTR(CollisionCallback))

' Priority rendering
CALL SETSPRITEPRIORITY(spriteHandle, priority)
CALL DRAWALLSPRITES  ' Draws all sprites sorted by priority
```

### Hardware-Accelerated Scrolling Engine

Multi-layer parallax scrolling with hardware acceleration:

```basic
' Virtual screen setup
CALL SETVIRTUALSCREEN(2048, 1536)  ' Large virtual world
CALL SETSCROLLPOS(playerX - 160, playerY - 100)  ' Center on player

' Hardware scrolling (Mode 13h)
CALL HSCROLLHARDWARE(200, 0, 0)  ' Scroll left, fill with black
CALL VSCROLLHARDWARE(50, 1, 15)  ' Scroll down, fill with white

' Parallax layers
CALL CREATEPARALLAXLAYER(0, 1024, 768, 128, 128, 0)  ' Background (50% speed)
CALL CREATEPARALLAXLAYER(1, 800, 600, 192, 192, 1)   ' Midground (75% speed)
CALL UPDATEPARALLAX  ' Update all layer positions
CALL DRAWPARALLAX    ' Draw all layers by priority

' Screen effects
CALL SCREENSHAKE(intensity, duration)
CALL UPDATESCREENSHAKE  ' Call once per frame
```

### Enhanced Cursor Management

Automatic background backup/restore with transparency support:

```basic
' Initialize and load cursor
CALL Cursor_Init
cursorHandle = Cursor_Load("cursor.cur", 0)
CALL Cursor_Set(cursorHandle)

' Automatic damage-free movement
CALL Cursor_Move(mouseX, mouseY)  ' Saves background, restores old area
CALL Cursor_Show / CALL Cursor_Hide

' Query cursor state
visible = Cursor_IsVisible
CALL Cursor_GetPos(currentX, currentY)
```

### High-Precision Timer System

Interrupt-driven 10ms resolution timing:

```basic
' Initialize 10ms precision timing
CALL Timer_Init
currentTick = Timer_GetTick  ' Get current 10ms tick

' Named timers
CALL Timer_Create(0, 50)     ' Timer 0: 500ms interval
IF Timer_IsReady(0) THEN     ' Non-blocking check
    ' Timer elapsed, do something
END IF

' Interrupt-driven callbacks
result = Timer_OnTimer(100, CODEPTR(TimerCallback))  ' 100ms interrupts
' Your TimerCallback SUB gets called automatically
CALL Timer_OffTimer  ' Disable when done

' High-resolution delays
CALL Timer_Delay10Ms(10)  ' Precise 100ms delay
```

### Multi-Format Image Support

Extended format support with compression and transparency:

```basic
' Additional image formats
CALL DrawTif_Show("image.tif", x, y)     ' TIFF with PackBits/LZW
CALL DrawTga_Show("image.tga", x, y)     ' TGA with RLE support  
CALL DrawGif_Show("image.gif", x, y)     ' GIF with transparency

' Windows DLL icon extraction
libHandle = DrawIcl_LoadLib("shell32.dll")
iconCount = DrawIcl_GetIconCount(libHandle)
CALL DrawIcl_ShowLibIcon(libHandle, 0, 0, x, y)  ' Show first icon
CALL DrawIcl_CloseLib(libHandle)
```

## 🚧 Future Enhancements

### Potential Additional Features

- **Sound Integration:** MOD/S3M music playback with sample mixing
- **Network Support:** IPX/TCP multiplayer game support  
- **Compression:** LZ77/Huffman compression for sprites and images
- **3D Graphics:** Basic 3D wireframe and filled polygon support
- **Hardware Support:** Enhanced VGA features (unchained Mode-X variants)
- **File Formats:** PNG support with proper alpha blending

## 🛠️ Building

The library targets **PowerBASIC 3.5 for DOS**: `$INCLUDE "SVGA.SUB"` in your program and compile with `PB.EXE` (runs fine under [DOSBox](https://www.dosbox.com/)). There is nothing to pre-build in this repo itself — CI verifies every source structurally (balanced `SUB`/`FUNCTION`/`IF`/`FOR`/`DO`/`SELECT` blocks):

```bash
node .github/workflows/scripts/check-basic.mjs .
```

## ❤️ Support

If this project saves you time or money, consider supporting its development:

[![GitHub Sponsors](https://img.shields.io/badge/GitHub-Sponsor-EA4AAA?logo=githubsponsors)](https://github.com/sponsors/Hawkynt)
[![PayPal](https://img.shields.io/badge/PayPal-Donate-00457C?logo=paypal)](https://www.paypal.me/hawkynt)

## 📜 License

Licensed under LGPL-3.0-or-later — see [LICENSE](LICENSE).