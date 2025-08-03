# 🖼️ PB-SvgaLibrary

[![License](https://img.shields.io/badge/License-LGPL_3.0-blue)](https://licenses.nuget.org/LGPL-3.0-or-later)
[![PowerBASIC](https://img.shields.io/badge/powerbasic%203.5-100%25-purple.svg)](https://en.wikipedia.org/wiki/PowerBASIC)

> Power BASIC 3.5 library to use VESA graphic modes

This library provides a comprehensive set of functions and subroutines for working with SVGA graphics in Power BASIC 3.5. It allows you to draw shapes, manipulate images, and manage various graphics modes, making it easier to create graphical applications and games.

## 🚀 Features

- **Graphics Primitives:** Draw basic shapes like lines, circles, boxes, and 3D bars.
- **Image Support:** Load and display various image formats, including:
  - 🖼️ BMP (Windows Bitmap)
  - 🎨 PCX (ZSoft Paintbrush)
  - 🖼️ ICO (Windows Icon)
- **Animation:** Basic animation support with `.ANI` files.
- **Font Handling:** Load and use custom fonts.
- **Color Palette Management:** Get and set color palettes.
- **VESA Modes:** Supports a wide range of VESA graphics modes.
- **Mode-X Graphics:** Provides optimized 256-color planar modes for animation and specific resolutions.
- **Windowing:** Create and manage virtual windows within the screen.
- **Sprite Handling:** Basic sprite manipulation functions.

## 🛠️ Usage

To use this library in your Power BASIC project, you need to include the `SVGA.SUB` file in your main program using the `$INCLUDE` metacommand.

```basic
$INCLUDE "SVGA.SUB"

' Your code goes here
```

## 📖 Functions

Here are some of the key functions available in the library:

| Function | Description |
|---|---|
| `SETVGA(mode)` | Initializes a VESA graphics mode. |
| `SETMODEX(mode)` | Initializes a Mode-X graphics mode. |
| `CLOSEVGA` | Returns to text mode. |
| `PUTPIXEL(x, y, color)` | Draws a pixel at the specified coordinates. |
| `GETPIXEL(x, y)` | Returns the color of the pixel at the specified coordinates. |
| `LINEDRAW(x1, y1, x2, y2, color)` | Draws a line between two points. |
| `BOX(x1, y1, x2, y2, color)` | Draws a filled box. |
| `BAR(x1, y1, x2, y2, border, fill)` | Draws a rectangle with a border and fill color. |
| `BAR3D(x1, y1, x2, y2, depth, border, fill)` | Draws a 3D-style bar. |
| `CIRCLEDRAW(x, y, xr, yr, start, end, color, fill)` | Draws a circle or ellipse. |
| `SHOWBMP(file, x, y)` | Loads and displays a BMP image. |
| `SHOWPCX(file, x, y)` | Loads and displays a PCX image. |
| `SHOWICON(file, x, y)` | Loads and displays an ICO file. |
| `INITFONT(file, flag)` | Loads a custom font file. |
| `PRINTFONT(text, x, y, color)` | Prints text using the loaded font. |

## 📂 File Support

The library supports the following file formats for graphics and fonts:

- **SVB:** Custom format for saving and loading screen blocks.
- **BMP:** Windows Bitmap files.
- **PCX:** ZSoft Paintbrush image files.
- **ICO:** Windows Icon files.
- **ANI:** Animated cursor files.
- **Custom Font Files:** 8x8 pixel fonts in a specific text format.

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

## 👨‍💻 Author

This library was created by Hawkynt.

## 📄 Supported File Formats

### 🖼️ Image Formats

#### BMP (Windows Bitmap) Files
- **Supported Color Depths:** 4-bit (16 colors), 8-bit (256 colors)
- **Compression:** Uncompressed only
- **Palette:** Automatically loaded and set for 8-bit images
- **Orientation:** Bottom-up (standard BMP format)
- **Usage:** `CALL SHOWBMP("image.bmp", x, y)`

#### PCX (ZSoft Paintbrush) Files  
- **Supported Color Depths:** 8-bit (256 colors)
- **Compression:** RLE (Run-Length Encoding) supported
- **Palette:** 256-color palette loaded from end of file (last 768 bytes)
- **Usage:** `CALL SHOWPCX("image.pcx", x, y)`

#### ICO (Windows Icon) Files
- **Supported Color Depths:** 4-bit (16 colors), 8-bit (256 colors)
- **Multiple Icons:** Displays first icon in file
- **Sizes:** Standard icon sizes (16x16, 32x32, etc.)
- **Transparency:** Basic transparency support
- **Usage:** `CALL SHOWICON("icon.ico", x, y)`

#### ANI (Animated Cursor) Files
- **Animation Support:** Multi-frame animated cursors
- **Frame Extraction:** Individual frames can be extracted
- **Usage:** Animation functions for frame-by-frame display

### 🔤 Font Format

#### Custom 8x8 Bitmap Fonts
The library uses a custom text-based font format for 8x8 pixel bitmap fonts:

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
00011000  (24)  - Row 1: ##
00111100  (60)  - Row 2: ####  
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
- **Color Depth:** 8-bit (256 colors) planar

#### Mode-X Support
- **Resolutions:** 320x240, 360x240, 320x400, 360x400, 320x480, 360x480, 256x256, 400x300
- **Color Depth:** 8-bit (256 colors) planar
- **Optimization:** Optimized for animation and efficient pixel/block operations

#### VESA Mode Support
- **Standard Modes:** 640x480, 800x600, 1024x768, 1280x1024
- **Color Depths:** 8-bit (256 colors), 16-bit, 24-bit
- **Fallback:** Automatic fallback to VGA Mode 13h if VESA unavailable
- **Memory:** EMS (Expanded Memory) support for large graphics buffers

#### Hardware Requirements
- **Minimum:** VGA-compatible graphics card
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

## 📜 License

This project is licensed under the LGPL 3.0 License - see the [LICENSE](https://licenses.nuget.org/LGPL-3.0-or-later) file for details.