# DARIUSBURST Chronicle Saviours, natively

Taito and Pyramid's entry in the Darius line for the PS Vita (PCSE00792), recompiled to native code
and run on the desktop and on Android handhelds through the
[Nativ](https://github.com/CrownParkComputing/nativ) engine — a static recompiler that turns the
Vita's ARM code into C, and a runtime that stands in for the console's kernel and draws its GXM
graphics on Vulkan.

**No part of the game is here.** This repository holds the port's own work: the pack that describes
the game to the engine, and the setup that builds it. The game's code and data come from **your own
copy**, are decrypted on your machine, and stay there.

## What you need

- A copy of the game you own **and its 1.11 update** — a folder taken off a Vita (`ux0:app/PCSE00792`
  with `ux0:patch/PCSE00792`, and `sce_sys/package/work.bin`), or the PKGs with their licence. The
  port plays the game with 1.11 layered over it; that is the version it pins.
- Linux, macOS or Windows, with a C compiler and a Vulkan-capable GPU.
- **About 25 GB free, and patience.** This is by far the largest game the engine runs: 23.5 MB of
  Vita code, 39,879 functions, 10.5 million instructions, which become 1.4 GB of C across 64 part
  files and a 160 MB program. The first build takes an hour or two.

## Build it

```bash
./setup.sh /path/to/your/dump                    # one copy holding the game and its update
./setup.sh /path/to/game /path/to/update         # or the two separately, game first
```

That fetches the engine, fetches Sony's firmware once (the engine needs the console's own libgxm,
GPU services library and libc), decrypts your copy, **checks it is the right game and version**
against the SHA-256 this port pins, then recompiles it and builds the host program. It prints the
command to play it, or pass `--run` to go straight there.

If the compile runs your machine out of memory, give it `JOBS=<n>` — the build otherwise picks how
many part files to compile at once from the memory free at the time, and a part file is ~20 MB of C.

## Playing it

Keyboard and mouse, or a controller. The game opens with an autosave notice and then assigns you a
cabinet; confirm both to reach the title screen.

The menu (frame rate, renderer, controls) is **F10**, or both stick clicks together on a controller.

**On an ultra-wide screen, set Display → Fullscreen and aspect → Fill.** The arcade modes draw the
cabinet's two-screens-wide view letterboxed into the Vita's 960x544 frame, so by default most of the
window is black bars and the picture is a thin strip. Fill crops to the window's shape: at 32:9 it
keeps the middle 270 of the 544 rows, and the arcade view is about 277 rows tall, so the bars go and
little else does. CS mode uses a taller view, where Fit is the better choice.

## On Android

The engine builds this for arm64 handhelds and packages it as its own app, with the game's own icon
off the Vita dump. Once, for the toolchain it cross-compiles against:

```bash
engine/runtime/platform/android/setup-toolchain.sh     # builds SDL3 for arm64 (a few minutes)
```

That wants a Linux x86-64 machine with an Android SDK (build-tools and a platform; `ANDROID_HOME`,
default `~/Android/Sdk`) and an NDK — `ANDROID_NDK` picks one, otherwise the newest installed. API 28
is the floor, the oldest Android with the Vulkan the renderer needs. There is no Gradle anywhere: the
package is a manifest, one dex and a few `.so` files, assembled with the SDK's own `aapt2`, `d8` and
`apksigner`.

Then, with the device on USB or paired over wireless adb:

```bash
engine/dev/android-install.sh PCSE00792 <adb serial>     # `adb devices` lists serials
```

That builds the game for arm64, installs the package, and pushes the game's data beside it — the
data is **never** inside the package. The push is the slow part over wireless adb; it only has to
happen once.

It runs at 60 fps on a Retroid Pocket Flip2, on Turnip.

**The in-game menu is Android's Back button**, or three fingers at once on the screen. (There is no
F10 on a handheld, and Android keeps the controller's Guide button for itself.) Inside it the d-pad
moves, A activates, and L1/R1 change section.

A Mesa Turnip driver can replace the device's own Vulkan, which on most handhelds is years behind —
a Retroid Pocket Flip2's Adreno driver reports Vulkan 1.1 where Turnip reports 1.3. Pass
`TURNIP_DRIVER=<a .so or a Turnip .zip>` to the install above, then pick it in the menu under
**Display → Vulkan driver** and restart the game. Drivers live in `drivers/` beside the game's files,
so a newer Turnip is one `adb push` into that folder away rather than a reinstall. The startup log
(`adb logcat -s nativ`) names the driver actually in use, which is the only place the answer shows.

## Keeping it up to date

The engine is its own repository and keeps moving; a game is only as new as the last time it was
built, and the menu and runtime are compiled into each game's binary. To pick up engine changes:

```bash
./setup.sh /path/to/your/dump                                  # desktop: pulls the engine, rebuilds what changed
APK_ONLY=1 engine/dev/android-install.sh PCSE00792 <adb serial>  # Android: the package only, keeping the pushed data
```

`APK_ONLY=1` is the one to use for every Android rebuild after the first: it skips re-pushing the
game's data, which is all of the waiting.

## What works

Boots, runs and draws: loading screen → the autosave notice → the title screen with its menu, at a
steady 60 fps. Beyond that is not yet explored.

The port's notebook is `pack/pack.toml`: what the game needs, which version it plays, and — kept as
a worked example — the hunt for the bug that blocked it, where a bogus length the game handed to
`memset` quietly zeroed the engine's thread stacks and surfaced three frames later as the display
queue losing the game's flip callback.

## Licence

GPL-2.0-or-later, as the engine is. See [LICENSE](LICENSE). The game is not covered by it and is not
distributed here.
