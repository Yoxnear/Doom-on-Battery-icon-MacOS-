# MenuDoom

**Doom, running inside a battery icon in your Mac's menu bar.**

![MenuDoom preview: Doom frames inside a tiny battery icon, enlarged 6×](docs/preview.png)

*(Enlarged 6×. The real thing is the size of your battery icon. Green outline = you're playing.)*

MenuDoom adds a small battery to your menu bar that plays Doom's demo loop. Click it and it grabs the keyboard so you can actually play. Click anywhere else and your keyboard goes back to your other apps.

It's completely impractical, which is the point.

## Requirements

- A Mac running macOS 12 (Monterey) or later
- [Xcode](https://apps.apple.com/app/xcode/id497799582) (free from the App Store)
- A Doom WAD file (not included, see below)

## Getting the game data

This repository contains only the engine and the app. The levels, graphics and monsters come from a separate file called a **WAD**, which isn't included here.

- **Free:** the shareware `doom1.wad` (Episode 1) is freely distributable and widely mirrored. Search for "doom1.wad shareware".
- **Fully open:** [Freedoom](https://freedoom.github.io/)'s `freedoom1.wad` also works.
- **Own a copy of Doom?** Your `doom.wad` or `doom2.wad` works too.

Put the WAD file in the project folder next to `Package.swift`. If MenuDoom can't find one, it asks you to choose it when it starts and remembers your choice.

## Build and run

1. Clone or download this repository.
2. Put your WAD in the folder (see above).
3. Double-click `Package.swift` to open it in Xcode.
4. At the top of the window, make sure the scheme shows **MenuDoom › My Mac**.
5. Press **⌘R**.

No window opens. Look for the battery in the menu bar at the top right of your screen.

From the command line instead:

```sh
swift run -c release
```

## Controls

| Action | Key |
|---|---|
| Start playing (outline turns green) | Click the battery |
| Stop playing | Click anywhere else, or click the battery again |
| App menu (Choose WAD, Saves folder, Quit) | Right-click the battery |
| Move / turn | Arrow keys |
| Fire | Control or Command |
| Open doors, flip switches | Space |
| Run | Shift (hold) |
| Strafe | Option + ← / → |
| Doom menu | Esc |
| Switch weapon | 1–7 |
| Map | Tab |

Settings and save games are stored in `~/Library/Application Support/MenuDoom`.

## How it works

- **`Sources/DoomGeneric/`** is [doomgeneric](https://github.com/ozkl/doomgeneric), a portable version of the Doom engine, plus `doomgeneric_menubar.c`, a small layer that passes each frame to Swift and passes key presses back in.
- **`Sources/MenuDoom/main.swift`** is the Mac app. It runs Doom 70 times a second, draws each new frame into a battery-shaped image, and shows it as a menu bar item. Clicking the icon opens an invisible 1×1 window that receives the keyboard.

To change the look, edit `iconSize`, `bodyRect` and `focusFromTop` at the top of `main.swift`.

## Troubleshooting

- **The battery appears, then disappears.** Doom hit a fatal error, usually a missing or unreadable WAD. Run it from Xcode and check the console at the bottom of the window.
- **I can't see the battery.** Your menu bar may be full, especially on a MacBook with a notch. Quit a few other menu bar apps.
- **No sound.** That's deliberate.

## Credits and license

- Doom by id Software. Engine source released under the GNU GPL v2.
- [doomgeneric](https://github.com/ozkl/doomgeneric) by ozkl, based on Chocolate Doom.

MenuDoom is released under the **GNU General Public License v2.0** (see [LICENSE](LICENSE)), the same as the Doom source it's built on. If you share builds, share the source as well.

Doom is a trademark of id Software. This project isn't affiliated with or endorsed by id Software.