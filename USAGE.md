> **Legacy reference only.** These instructions run the retained community C++ engine against retail files. The Revival product will use a one-way Swift importer and will not mount retail archives at runtime. See [REVIVAL.md](REVIVAL.md) and [One-way content pipeline](docs/revival/content-pipeline.md).

# Descent 3 Open source usage instructions

**Important note**: This open source distribution of Descent 3 DOES NOT CONTAIN
GAME ASSETS. Assets must be acquired separately from an official copy of the
game, and copied as described in the next section.

This document describes the retained community engine in this checkout. If you find a current reference-engine bug that has not been reported, open a ticket on the [upstream issue tracker](https://github.com/DescentDevelopers/Descent3/issues).

1. Make sure that you have a copy of Descent 3. You can purchase a copy of
Descent 3 from [GOG](https://www.gog.com/game/descent_3_expansion) or
[Steam](https://store.steampowered.com/app/273590/Descent_3/).

2. Install Descent 3.
**Note for Steam users:** If you own Descent 3 on Steam, then it’s recommended
that you install the Windows version of the game even if you’re running macOS
or Linux, otherwise movies will not work due to
[current lack of OGV support](https://github.com/DescentDevelopers/Descent3/issues/240).
You can use either [Steam Play](https://help.steampowered.com/en/faqs/view/08F7-5D56-9654-39AF)
or [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD#Cross-Platform_Installation)
to install the Windows version of the game on macOS or Linux.

3. If your version of Descent 3 is older than v1.4, then
[update it to v1.4](http://descent3.com/downloads.php).

4. Find the installation location of Descent 3. Using the Steam client, you can
find it from the library page using the `Manage > Browse local files`
context menu.

5. Create a new folder named `D3-open-source`.

6. Copy the following files from your installation of Descent 3 to `D3-open-source`:
    - All `.hog` files
    - The `missions` folder
    - _(Optional)_ All `.pld` files
    - _(Optional)_ The `movies` folder

7. Create the `custom/` folder in `D3-open-source`

8. Obtain new Descent 3 engine files:
    - If you want to use pre-built binaries, then download the latest
      [release](https://github.com/DescentDevelopers/Descent3/releases). For a
      more cutting-edge experience with the latest features, use the artifacts
      from the latest automated build. You can find the list of automated
      builds [here](https://github.com/DescentDevelopers/Descent3/actions/workflows/build.yml?query=branch%3Amain+event%3Apush).
    - If you want to build the engine files yourself, follow the
      instructions in [BUILD.md](BUILD.md). Once you build the engine files,
      they’ll be put in `builds/<platform>/build/<build-type>/`. For example, if
      you’re using Linux and you create a “Release” build, then the files will
      be located at `builds/linux/build/Release`.

9. Copy all the new engine files into `D3-open-source` and overwrite any
conflicts.

10. Special notes:
    - D3 Open Source compiles level scripts in their own hogfiles. Make sure
      you copy and overwrite `d3-{platform}.hog`.

11. Run the game:
    - On Windows, run `D3-open-source\Descent3.exe` from a command-line or
      double-click on the `Descent3` executable.
    - On Linux, `cd` to `D3-open-source` and run `./Descent3`. Wayland users
      may need to set environment variable `SDL_VIDEODRIVER=wayland` before
      launching the game.
    - On macOS, open the terminal, `cd` to `D3-open-source`, and run `./Descent3.app/Contents/MacOS/Descent3`.

## Troubleshooting

```
Descent 3 Message(Error: Couldn't find the string table.)
```

This error means that game data was not found in any configured base directory. Confirm that the retail data is in a recognized search root described below. Run with `-logfile` and inspect the `Base directories` entry in `Descent3.log` to see the roots the engine accepted.

## Base directories

A base directory is a directory that Descent 3 expects game files to be in. When you run Descent 3, it will try to access many different files. Most of those files need to be stored in a base directory. There are two different types of files that are stored in base directories:

- Read-write files are files that can change while you play Descent 3. Examples: `<your name>.plt` and files in the `savegame/` directory.
- Read-only files are files that do not change while you play Descent 3. Examples: `d3.hog` and files in the `movies/` directory.

Descent 3 has two types of base directories:

- The writable base directory can contain both read-write and read-only files. There is one writable base directory: the platform-specific SDL preference directory created for Descent 3.
- Additional base directories supply read-only game data. They can come from build defaults, command-line options, saved configuration, the installed data location, and the executable directory.

The current engine has no `-setdir` or `-useexedir` option. Add a custom read-only root with `-additionaldir <path>`; repeat the option to add more than one. Build-time roots come from the `DEFAULT_ADDITIONAL_DIRS` CMake option described in [BUILD.md’s Build Options section](./BUILD.md#build-options).

At startup, Descent 3 adds base directories in this order:

- the writable SDL preference directory;
- the `DEFAULT_ADDITIONAL_DIRS` build-time roots;
- each `-additionaldir` root in command-line order;
- the saved `GAME_base_directory`, if configured;
- the platform data directory compiled as `D3_DATADIR`;
- the executable directory, when it is distinct from the platform data directory.

Later entries have higher read precedence, so the engine searches that list in reverse. Among repeated `-additionaldir` options, the last path wins when two roots contain the same relative file. Nonexistent directories are ignored with a warning. Writes still go to the SDL preference directory.

## Command-Line Options

The current executable parses the following user-facing command-line options. Pass them directly after the executable name. Case is not significant, and `-`, `--`, and `+` prefixes are accepted.

### Display Options

- `-aspect <value>`

    **Type:** floating-point number

    **Default:** 1.3333333333333333

    **Platform:** all

    **Description:** Specifies the screen aspect ratio for non-standard displays, such as wide-screen TVs.

- `-display <number>`

    **Type:** integer

    **Default:** 0

    **Platforms:** all

    **Description:** Run game on the selected display.

- `-fullscreen` or `-f`

    **Type:** boolean

    **Default:** Saved window mode when available; otherwise On

    **Platform:** all

    **Description:** Run game in fullscreen mode.

- `-height <height>`

    **Type:** integer

    **Default:** Saved resolution when available; otherwise the current display height, with 720 as the fallback-list default

    **Platform:** all

    **Description:** Sets the screen resolution to the specified height, if possible. Supply `-width` and `-height` together.

- `-himem`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Forces normal operations even when low memory conditions are detected.

- `-lowmem`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Uses scaled-down textures and lower quality (8-bit) sounds to conserve memory.

- `-NoRenderWindows`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Causes all windows to be fully transparent. Use this option if your card does not correctly render partially-transparent windows.

- `-superlowmem`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Uses the `-lowmem` settings and further scales down textures to conserve memory.

- `-vsync`

    **Type:** boolean

    **Default:** Saved setting when available; otherwise On

    **Platform:** all

    **Description:** Turns on Vertical Sync. The current community engine stores the resulting setting in its configuration database so it remains enabled on later runs.

- `-width <width>`

    **Type:** integer

    **Default:** Saved resolution when available; otherwise the current display width, with 1280 as the fallback-list default

    **Platform:** all

    **Description:** Sets the screen resolution to the specified width, if possible. Supply `-width` and `-height` together.

- `-windowed` or `-w`

    **Type:** boolean

    **Default:** Saved window mode when available; otherwise Off

    **Platform:** all

    **Description:** Runs the game in a window.

### Audio Options

- `-nomusic`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Disables music.

- `-nosound`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Disables all sound, including music.

### Input Options

- `-deadzone# <k>`

    **Type:** `#` is either the character `0` or the character `1`. `k` is a floating-point number.

    **Default:** 0.2

    **Platform:** all

    **Description:** Specifies the size of the deadzone for a joystick.

- `-mlooksens <scale>`

    **Type:** floating-point number

    **Default:** 9.102

    **Platform:** all

    **Description:** Determines how much the player moves when the mouse is moved.

- `-mousesens <scale>`

    **Type:** floating-point number

    **Default:** 1.0

    **Platform:** all

    **Description:** Adjusts the sensitivity of the mouse when not using mouselook mode.

- `-nomousegrab` or `-m`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Disable mouse capture.

### Performance Options

- `-fastdemo`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Causes a demo to play back at the highest speed your computer is capable of.

- `-framecap <fps>`

    **Type:** integer

    **Default:** 60

    **Platform:** all

    **Description:** Limits the framerate to the number of frames per second specified.

- `-nomotionblur`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Disables motion blur on robots.

- `-nosatomega`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Disables alpha saturation on the omega cannon effect.

- `-nosparkles`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Disables powerup sparkles.

### Multiplayer and Network Options

- `-audiotauntdelay <time>`

    **Type:** floating-point number

    **Default:** 5.0

    **Platform:** all

    **Description:** Sets the number of seconds a player must wait after sending an audio taunt before sending another. This option applies only when starting a server.

- `-autoexec <file>`

    **Type:** path

    **Default:** `<writable-base-directory>/netgames/autoexec.dmfc`

    **Platform:** all

    **Description:** Specifies the full path and file name of the multiplayer config file to be loaded and executed when a multiplayer game is initialized.

- `-dedicated <config file>` or `-d <config file>`

    **Type:** path

    **Default:** None

    **Platform:** all

    **Description:** Starts a dedicated server.

- `-gamespyport <port>`

    **Type:** integer

    **Default:** 20142

    **Platform:** all

    **Description:** Specifies the port on which to listen for GameSpy requests.

- `-gspyfile <config file>`

    **Type:** path

    **Default:** gamespy.cfg

    **Platform:** all

    **Description:** Specifies a GameSpy configuration file to use.

- `-httpproxy <addr>` or `-httpproxy <addr:port>`

    **Type:** string

    **Default:** None

    **Platform:** all

    **Description:** Specifies an HTTP proxy server. Descent 3 uses HTTP to auto-download a mission; use this option if your ISP requires a proxy server for HTTP connections. If the first form is used, the port value defaults to 80.

- `-nooutragelogo`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Disables the Outrage logo that is normally displayed for five seconds at the start of a multiplayer game.

- `-nomultibmp`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Disables multiplayer custom-file transfer, including the ship texture and four voice taunts.

- `-nonetwork`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Disables all network multiplayer functionality.

- `-playermessages`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Filters the broader player-status HUD message surface in multiplayer, including pickup, weapon, shield, energy, inventory, and scripted messages that use the filtered-message path.

- `-pxoport <port>`

    **Type:** integer

    **Default:** 0 (no override)

    **Platform:** all

    **Description:** Overrides the port that PXO tells clients to use when contacting a server. Zero leaves the tracker-selected port unchanged.

- `-useip <IP>`

    **Type:** string

    **Default:** All available network interfaces

    **Platform:** all

    **Description:** Binds Descent 3 to this IP address. Use this option to tell D3 which IP address to use if your computer has multiple IP addresses.

- `-useport <port>`

    **Type:** integer

    **Default:** 2092

    **Platform:** all

    **Description:** Specifies the port that TCP/IP networking will use.

- `-usesmoothing`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Enables code to smooth the interpolation for fast-moving objects. This will fix "skipping" problems with fast weapons, such as the Phoenix. This option applies to clients only; using it on the server has no effect.

### Base Directory Options

- `-additionaldir <path>`

    **Type:** path

    **Default:** None

    **Platform:** all

    **Description:** Adds a read-only base directory. Repeat the option to add multiple directories; later occurrences have higher read precedence.

### Other Options

- `-loadlevel <number>`

    **Type:** integer

    **Default:** None

    **Platform:** all

    **Description:** Loads a specific level from the mission selected with `-mission`. It has an effect only when `-mission` is specified.

- `-logfile`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Enables the rolling file logger in Release and Debug builds and writes `Descent3.log` in the process working directory. Messages at or above the selected `-loglevel` are included.

- `-loglevel <LEVEL>`

    **Type:** string

    **Default:** INFO (on Release), DEBUG (on Debug)

    **Platform:** all

    **Description:** Set log level (NONE, VERBOSE, DEBUG, INFO, WARNING, ERROR, FATAL)

- `-makemovie`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Causes the demo system to save a screenshot of every frame during playback.

- `-mission <name>`

    **Type:** string

    **Default:** None

    **Platform:** all

    **Description:** Loads the specified mission file at startup. Example: `-mission d3` to load the main campaign. Combine this option with `-loadlevel` to load a specific level from the mission.

- `-pilot <name>`

    **Type:** string

    **Default:** None

    **Platform:** all

    **Description:** Specifies the pilot to use, skipping the pilot selection dialog when the game starts.

- `-service`

    **Type:** boolean

    **Default:** Off

    **Platform:** all

    **Description:** Run game in service mode.

- `-winconsole`

    **Type:** boolean

    **Default:** Off

    **Platform:** WIN

    **Description:** Enable windows console (off by default).
