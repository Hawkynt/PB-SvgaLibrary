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

## 📜 License

This project is licensed under the LGPL 3.0 License - see the [LICENSE](https://licenses.nuget.org/LGPL-3.0-or-later) file for details.