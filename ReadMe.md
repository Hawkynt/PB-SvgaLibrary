# 🖼️ PB-SvgaLibrary

![License](https://img.shields.io/github/license/Hawkynt/PB-SvgaLibrary)
[![PowerBASIC](https://img.shields.io/badge/powerbasic%203.5-100%25-purple.svg)](https://en.wikipedia.org/wiki/PowerBASIC)
[![Last Commit](https://img.shields.io/github/last-commit/Hawkynt/PB-SvgaLibrary?branch=main)![Activity](https://img.shields.io/github/commit-activity/y/Hawkynt/PB-SvgaLibrary?branch=main)](https://github.com/Hawkynt/PB-SvgaLibrary/commits/main)
[![Tests](https://github.com/Hawkynt/PB-SvgaLibrary/actions/workflows/tests.yml/badge.svg)](https://github.com/Hawkynt/PB-SvgaLibrary/actions/workflows/tests.yml)

> High-performance Power BASIC 3.5 library for VESA graphics with micro-optimized assembly routines

This library provides a comprehensive set of functions and subroutines for working with SVGA graphics in Power BASIC 3.5. It features heavily optimized assembly code for pixel operations, drawing primitives, and image manipulation across VGA, Mode-X, and VESA modes.

## 🚀 Features

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
  - Mode-X (planar 256-color modes)
  - VESA (up to 1600x1200)
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

## 🛠️ Usage

To use this library in your Power BASIC project, you need to include the `SVGA.SUB` file in your main program using the `$INCLUDE` metacommand. This includes everything else.

```basic
$INCLUDE "SVGA.SUB"

' Your code goes here
```

## 📖 Complete API Reference

### 🎮 Mode Management

| Function | Description |
|---|---|
| `INITSVGA` | Initialize the SVGA library (call first) |
| `SETRES(xres, yres, colors)` | Set graphics resolution (auto-selects best mode) |
| `SETVGA(mode)` | Set specific VESA mode number |
| `ModeX_SetMode(mode)` | Initialize Mode-X graphics mode |
| `VGA_InitMode13h` | Initialize standard VGA Mode 13h |
| `CLOSEVGA` | Return to text mode |
| `CLEANUPSVGA` | Clean up library resources |
| `VGAINFO` | Display VESA capabilities information |
| `GETVESAMODE(xres, yres, colors)` | Get VESA mode number for resolution |

### 🖊️ VGA Drawing Primitives

| Function | Description |
|---|---|
| `VGA_PutPixel(x, y, color)` | Ultra-optimized Mode 13h pixel write |
| `VGA_GetPixel(x, y)` | Ultra-optimized Mode 13h pixel read |
| `VGA_HLine(x1, x2, y, color)` | Hardware-optimized horizontal line |
| `VGA_VLine(x, y1, y2, color)` | Hardware-optimized vertical line |
| `VGA_LineDraw(x1, y1, x2, y2, color)` | Bresenham line algorithm |
| `VGA_FillRect(x1, y1, x2, y2, color)` | Filled rectangle |
| `VGA_DrawRect(x1, y1, x2, y2, color)` | Rectangle outline |
| `VGA_DrawCircle(cx, cy, r, color)` | Circle outline (midpoint algorithm) |
| `VGA_FillCircle(cx, cy, r, color)` | Filled circle |
| `VGA_ClearScreen(color)` | Ultra-fast screen clear |
| `VGA_CopyBlock(sx, sy, dx, dy, w, h)` | Block copy with overlap handling |
| `VGA_PatternFill(x1, y1, x2, y2, pattern)` | Pattern-based fill |

### 🎨 VESA Drawing Functions

| Function | Description |
|---|---|
| `VESA_PutPixel(x, y, color)` | VESA banked pixel write |
| `VESA_GetPixel(x, y)` | VESA banked pixel read |
| `VESA_HLine(x1, x2, y, color)` | VESA horizontal line with banking |
| `VESA_VLine(x, y1, y2, color)` | VESA vertical line with banking |
| `VESA_LineDraw(x1, y1, x2, y2, color)` | VESA line drawing |
| `VESA_FillRect(x1, y1, x2, y2, color)` | VESA filled rectangle |
| `VESA_DrawRect(x1, y1, x2, y2, color)` | VESA rectangle outline |
| `VESA_ClearScreen(color)` | VESA screen clear with banking |
| `VESA_CopyBlock(sx, sy, dx, dy, w, h)` | VESA block copy |
| `VESA_CopyScanline(sx, sy, dx, dy, w)` | Single scanline copy |

### 🔲 Mode-X Functions

| Function | Description |
|---|---|
| `ModeX_InitTables` | Initialize Mode-X lookup tables |
| `ModeX_PutPixel(x, y, color)` | Mode-X planar pixel write |
| `ModeX_GetPixel(x, y)` | Mode-X planar pixel read |
| `ModeX_HLine(x1, x2, y, color)` | Mode-X optimized horizontal line |
| `ModeX_VLine(y1, y2, x, color)` | Mode-X optimized vertical line |
| `MODEX_LineDraw(x1, y1, x2, y2, color)` | Mode-X line drawing |
| `MODEX_FillRect(x1, y1, x2, y2, color)` | Mode-X filled rectangle |
| `MODEX_DrawRect(x1, y1, x2, y2, color)` | Mode-X rectangle outline |
| `MODEX_DrawCircle(cx, cy, r, color)` | Mode-X circle outline |
| `MODEX_FillCircle(cx, cy, r, color)` | Mode-X filled circle |
| `ModeX_ClearScreen(color)` | Mode-X screen clear |
| `ModeX_CopyBlock(sx, sy, dx, dy, w, h)` | Mode-X block copy |
| `MODEX_FastFill(x1, y1, x2, y2, color)` | Ultra-fast Mode-X fill |
| `MODEX_SetActivePage(page)` | Set active draw page |
| `MODEX_SetVisiblePage(page)` | Set visible display page |
| `MODEX_CopyPage(src, dest)` | Copy between pages |

### 🖼️ Image File Formats

| Function | Description |
|---|---|
| **BMP Support** | |
| `SHOWBMP(file, x, y)` | Load and display BMP file |
| `DrawExt_ShowBMP(file, x, y)` | Extended BMP loader |
| `GETBMPSIZE(file, width, height)` | Get BMP dimensions |
| `GETBMPPAL(file, pal[], depth)` | Extract BMP palette |
| **PCX Support** | |
| `SHOWPCX(file, x, y)` | Load and display PCX file |
| `DrawExt_ShowPCX(file, x, y)` | Extended PCX loader |
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
| `DRAWTIF(filename, x, y)` | Draw TIFF image (PackBits/LZW) |
| `DRAWTGA(filename, x, y)` | Draw TGA image (RLE/uncompressed) |
| `DRAWGIF(filename, x, y)` | Draw GIF image (LZW/transparency) |
| **Icon Libraries** | |
| `OPENICOLIB(filename)` | Open Windows DLL icon library |
| `GETICOLIBCOUNT(handle)` | Get number of icon groups |
| `EXTRACTICON(handle, groupID, index)` | Extract icon from library |
| `CLOSEICOLIB(handle)` | Close icon library |

### 🔤 Font System

| Function | Description |
|---|---|
| `INITFONT(file, mode)` | Load 8x8 bitmap font |
| `VGAPRINT(x, y, fg, bg, text, flags)` | Print text with current font |
| `BMPPRINT(x, y, fg, bg, text, flags)` | Print text as bitmap |
| `GETFONTINFO()` | Get font metrics |

### 🎯 High-Level Graphics

| Function | Description |
|---|---|
| `BAR(x1, y1, x2, y2, border, fill)` | Rectangle with border and fill |
| `BAR3D(x1, y1, x2, y2, depth, border, fill)` | 3D-style bar |
| `BOX(x1, y1, x2, y2, color)` | Filled box |
| `CIRCLEDRAW(cx, cy, rx, ry, start, end, color, fill)` | Circle/ellipse/arc |
| `FRAME(x1, y1, x2, y2, color)` | Rectangle frame |
| `PIXEL(x, y, color)` | Generic pixel plot |

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
| `TAKEEMS(sizekb, handle)` | Allocate EMS memory |
| `CLOSEEMS(handle)` | Free EMS memory |
| `EMSBYTE(page, offset, value, handle)` | Read/write EMS byte |
| `PUTEMSBYTE(seg, off, byte, handle)` | Write byte to EMS |
| `GETEMSBYTE(seg, off, handle)` | Read byte from EMS |
| `PUTEMSSTRING(seg, off, data, handle)` | Write string to EMS |
| `GETEMSSTRING$(seg, off, len, handle)` | Read string from EMS |
| `SETVESAWINDOW(window)` | Set VESA bank window |
| `MEMCOPY(sseg, soff, ssize, dseg, doff, dsize, bytes)` | Memory block copy |
| `MEMSWAP(seg1, off1, size1, seg2, off2, size2, bytes)` | Memory block swap |
| `ClearVideoMemory(color)` | Ultra-fast A000h segment clear |

### ⏰ High-Precision Timer System

| Function | Description |
|---|---|
| `INITTIMER` | Initialize 10ms precision timer system |
| `GETTIMERTICK` | Get current timer tick (10ms resolution) |
| `WAITTICKS(count)` | Wait for specified number of ticks |
| `DELAY10MS(count)` | High-resolution delay function |
| `SETANIMTIMER(delay)` | Set animation timer delay |
| `ANIMTIMERREADY` | Check if animation timer is ready |
| `GETELAPSEDTIME` | Get elapsed time since init |
| `RESETTIMER` | Reset timer system |
| `CREATETIMER(id, delay)` | Create named timer |
| `ISTIMERREADY(id)` | Check if named timer is ready |
| `DESTROYTIMER(id)` | Destroy named timer |
| `ONTIMER(interval, callback)` | Install timer interrupt handler |
| `OFFTIMER` | Remove timer interrupt handler |
| `HRTIMER(freq, callback)` | High-resolution PIT timer |
| `RESTORETIMER` | Restore default timer frequency |
| `CLEANUPTIMER` | Cleanup timer system |

### 🏃 Advanced Cursor Management

| Function | Description |
|---|---|
| `INITCURSOR` | Initialize cursor management system |
| `LOADCURSOR(filename, index)` | Load cursor from ICO/CUR file |
| `SETCURSOR(handle)` | Set active cursor |
| `MOVECURSOR(x, y)` | Move cursor with auto backup/restore |
| `SHOWCURSOR` | Make cursor visible |
| `HIDECURSOR` | Hide cursor |
| `ISCURSORVISIBLE` | Check cursor visibility |
| `GETCURSORPOS(x, y)` | Get current cursor position |
| `UPDATECURSOR` | Update cursor display |
| `FREECURSOR(handle)` | Free cursor resources |
| `CLEANUPCURSOR` | Cleanup cursor system |

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
| `PUTPIXEL(x, y, color)` | Generic pixel plot (dispatched) |
| `GETPIXEL(x, y)` | Generic pixel read (dispatched) |
| `LINEDRAW(x1, y1, x2, y2, color)` | Generic line (dispatched) |
| `CLEARSCREEN(color)` | Generic clear (dispatched) |
| `HLINE(x1, x2, y, color)` | Generic horizontal line |
| `VLINE(x, y1, y2, color)` | Generic vertical line |
| `FILLRECT(x1, y1, x2, y2, color)` | Generic filled rectangle |
| `DRAWRECT(x1, y1, x2, y2, color)` | Generic rectangle outline |
| `DRAWCIRCLE(cx, cy, r, color)` | Generic circle outline |
| `FILLCIRCLE(cx, cy, r, color)` | Generic filled circle |
| `WAITVRETRACE` | Wait for vertical retrace |
| `WAITHRETRACE` | Wait for horizontal retrace |
| `SETSCALE(xscale, yscale)` | Set global scaling |
| `GETSCALE(type, unused)` | Get global scale |
| `SETVGAWINDOW(maxx, maxy)` | Set VGA window |
| `SETVGAVIEW(x1, y1, x2, y2)` | Set VGA viewport |

## ✍️ Example

Here's a simple example of how to initialize a graphics mode, draw a box, and wait for a key press:

```basic
$INCLUDE "SVGA.SUB"

' Initialize a 640x480 graphics mode with 256 colors
SETRES 640, 480, 256

' Draw a red box
BOX 100, 100, 200, 200, 4

' Wait for a key press
WHILE INKEY$ = "" : WEND

' Return to text mode
CLOSEVGA
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
$INCLUDE "SVGA_NEW.SUB"

' Initialize library
CALL INITSVGA

' Set graphics mode
CALL SETRES(800, 600, 256)

' Load and display resources
CALL INITFONT("font8x8.txt", 0)
CALL SHOWBMP("background.bmp", 0, 0)
CALL VGAPRINT(100, 100, 15, 0, "Hello SVGA!", 0)

' Cleanup
CALL CLEANUPSVGA
```

## ✅ Recently Implemented Features

### Complete Animation and Resource Management System

The library now includes a comprehensive animation system with full resource management:

```basic
' Load and manage animations
animHandle = LOADANI("animated.ani")
CALL STARTANI(animHandle, x, y, loopCount, useTimer)

' Resource management
CALL PAUSEANI(animHandle)      ' Pause animation
CALL RESUMEANI(animHandle)     ' Resume paused animation
CALL FREEZEANI(animHandle)     ' Stop but keep resources
state = GETANISTATE(animHandle) ' Get current state

' Auto-cleanup and timer integration
CALL SETANIAUTOCLEANUP(animHandle, 1)
CALL UPDATEANI(animHandle, x, y)  ' Call in main loop
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
CALL INITCURSOR
cursorHandle = LOADCURSOR("cursor.cur", 0)
CALL SETCURSOR(cursorHandle)

' Automatic damage-free movement
CALL MOVECURSOR(mouseX, mouseY)  ' Saves background, restores old area
CALL SHOWCURSOR / CALL HIDECURSOR

' Query cursor state
visible = ISCURSORVISIBLE
CALL GETCURSORPOS(currentX, currentY)
```

### High-Precision Timer System

Interrupt-driven 10ms resolution timing:

```basic
' Initialize 10ms precision timing
CALL INITTIMER
currentTick = GETTIMERTICK  ' Get current 10ms tick

' Named timers
CALL CREATETIMER(0, 50)     ' Timer 0: 500ms interval
IF ISTIMERREADY(0) THEN     ' Non-blocking check
    ' Timer elapsed, do something
END IF

' Interrupt-driven callbacks
result = ONTIMER(100, CODEPTR(TimerCallback))  ' 100ms interrupts
' Your TimerCallback SUB gets called automatically
CALL OFFTIMER  ' Disable when done

' High-resolution delays
CALL DELAY10MS(10)  ' Precise 100ms delay
```

### Multi-Format Image Support

Extended format support with compression and transparency:

```basic
' Additional image formats
CALL DRAWTIF("image.tif", x, y)     ' TIFF with PackBits/LZW
CALL DRAWTGA("image.tga", x, y)     ' TGA with RLE support  
CALL DRAWGIF("image.gif", x, y)     ' GIF with transparency

' Windows DLL icon extraction
libHandle = OPENICOLIB("shell32.dll")
iconCount = GETICOLIBCOUNT(libHandle)
iconHandle = EXTRACTICON(libHandle, 0, 0)  ' Extract first icon
CALL DRAWICO(iconHandle, x, y)
CALL CLOSEICOLIB(libHandle)
```

## 🚧 Future Enhancements

### Potential Additional Features

- **Sound Integration:** MOD/S3M music playback with sample mixing
- **Network Support:** IPX/TCP multiplayer game support  
- **Compression:** LZ77/Huffman compression for sprites and images
- **3D Graphics:** Basic 3D wireframe and filled polygon support
- **Hardware Support:** Enhanced VGA features (unchained Mode-X variants)
- **File Formats:** PNG support with proper alpha blending

## 📜 License

This project is licensed under the LGPL 3.0 License - see the [LICENSE](https://licenses.nuget.org/LGPL-3.0-or-later) file for details.