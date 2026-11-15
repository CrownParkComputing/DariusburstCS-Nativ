#!/usr/bin/env bash
# setup.sh -- build this port from YOUR OWN copy of the game.
#
#   ./setup.sh /path/to/your/dump                       a folder copied off a Vita, or a PKG
#   ./setup.sh /path/to/game /path/to/update            the game and its 1.11 update, separately
#   ./setup.sh /path/to/your/dump --run                 ...and play it when it is built
#
# This game plays as its 1.11 update, so the update has to be there. A single dump that holds both
# (a release zip, or a copy with ux0:app and ux0:patch under it) is one argument; two separate
# downloads are two, the game first.
#
# Nothing of the game ships here: this repository holds the port's own work (the pack that describes
# the game, any host code it needs, and this script). The game's code and data come from the copy you
# point at, are decrypted on this machine, and stay here.
#
# What it does, in order:
#   1. fetches the Nativ engine (the recompiler and runtime) beside this repository
#   2. fetches Sony's firmware once, which the engine needs for libgxm, the GPU services library and libc
#   3. decrypts your copy, and CHECKS IT IS THE RIGHT GAME AND VERSION against the SHA-256 this port pins
#   4. recompiles it to C and builds the host program
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TITLE=PCSE00792
NAME="DARIUSBURST Chronicle Saviours"
ENGINE=${NATIV_ENGINE:-$HERE/engine}
ENGINE_REPO=${NATIV_ENGINE_REPO:-https://github.com/CrownParkComputing/nativ.git}
ENGINE_REF=${NATIV_ENGINE_REF:-txk}

RUN=0; DUMPS=()
for a in "$@"; do
  case $a in
    --run) RUN=1 ;;
    -*) echo "unknown option: $a" >&2; exit 1 ;;
    *) DUMPS+=("$a") ;;
  esac
done
[[ ${#DUMPS[@]} -gt 0 ]] || { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
for d in "${DUMPS[@]}"; do [[ -e $d ]] || { echo "no such copy: $d" >&2; exit 1; }; done

say() { printf '\n== %s\n' "$*"; }

say "the engine"
if [[ -d $ENGINE/.git ]]; then git -C "$ENGINE" fetch --quiet origin "$ENGINE_REF" && git -C "$ENGINE" checkout --quiet "$ENGINE_REF" && git -C "$ENGINE" pull --quiet --ff-only
else git clone --quiet --branch "$ENGINE_REF" "$ENGINE_REPO" "$ENGINE"; fi
[[ -f $ENGINE/pipeline/vitarecomp.py ]] || { echo "$ENGINE does not look like the Nativ engine" >&2; exit 1; }

# the port's own files go into the engine's tree, where its pipeline looks for them: this repository
# is the port, the engine is generic and knows nothing about this game until now
mkdir -p "$ENGINE/packs/$TITLE"
cp -f "$HERE"/pack/* "$ENGINE/packs/$TITLE/"

PY=$ENGINE/.venv/bin/python
if [[ ! -x $PY ]]; then
  say "the engine's python environment"
  python3 -m venv "$ENGINE/.venv"
  "$ENGINE/.venv/bin/pip" install --quiet -r "$ENGINE/requirements.txt"
fi
V() { "$PY" "$ENGINE/pipeline/vitarecomp.py" "$@"; }

say "Sony's firmware (once)"
# the engine needs the console's own libgxm, GPU services library and libc, taken from a firmware
# update file. It keeps them in its library folder; this is where they land.
LIB=${ATIV_DUMP:-$HOME/.local/share/ProjectNativ/Nativ/library}
HAVE_FW=0
for f in "$LIB"/firmware/*/os0/us/libgxm_es4.suprx.elf; do [[ -f $f ]] && HAVE_FW=1 && break; done
if [[ $HAVE_FW -eq 0 ]]; then
  PUP=${NATIV_PUP:-}
  if [[ -z $PUP ]]; then
    URL=$(curl -fsSL http://dus01.psp2.update.playstation.net/update/psp2/list/us/psp2-updatelist.xml \
          | grep -oE 'http[^"]*\.PUP' | head -1)
    [[ -n $URL ]] || { echo "could not find the firmware URL; download a PUP yourself and pass NATIV_PUP=<file>" >&2; exit 1; }
    PUP=$HERE/.cache/$(basename "$URL"); mkdir -p "$HERE/.cache"
    [[ -f $PUP ]] || { echo "   downloading $URL"; curl -fL# -o "$PUP" "$URL"; }
  fi
  V firmware "$PUP"
fi

say "your copy of $NAME"
# each copy but the last is decrypted and kept (--no-build); the last one imports and builds them together
for i in "${!DUMPS[@]}"; do
  if [[ $i -lt $(( ${#DUMPS[@]} - 1 )) ]]; then V add "${DUMPS[$i]}" --no-build
  else V add "${DUMPS[$i]}"; fi
done

say "which version this is"
V versions "$TITLE"          # the pack pins each version's eboot SHA-256; this says which one you have

say "recompiling and building (the largest game this engine runs: expect an hour or two, and 25 GB)"
# 10.5M instructions become 1.4 GB of C in 64 parts. The build picks its own number of parallel
# compiles from the memory free at the time; JOBS=<n> overrides it if yours is tighter than it guessed.
V ready "$TITLE"

say "done"
echo "   play it:  $PY $ENGINE/pipeline/vitarecomp.py run $TITLE"
[[ $RUN -eq 1 ]] && V run "$TITLE"
