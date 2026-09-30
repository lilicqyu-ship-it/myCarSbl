#!/bin/sh
# build_sbl.sh - command-line TASKING build of the SBL, mirroring the flags
# AURIX Development Studio generates (Debug/makefile), with Lcf_SBL.lsl.
#
# Reuses the iLLD objects ADS already produced in Debug/ and recompiles only
# the project sources, so it is fast and stays in sync with the IDE build.
# Run from the repo root:  sh tools/build_sbl.sh
set -e

# ADS's bundled TASKING refuses to run outside the IDE ("license does not
# support standalone"); the full TASKING v6.3r1 install on this bench does.
# Newer major version than ADS's 1.1r8 - this build is a compile/link
# validation, the authoritative binary still comes from ADS.
CTC="/c/Program Files/TASKING/TriCore v6.3r1/ctc/bin"
ADS_MAKE=/c/Infineon/AURIX-Studio-1.10.40/tools/make
PROJ=$(pwd)
OUT=Debug

CFLAGS="-cs -I. --misrac-version=2012 -D__CPU__=tc27xd --iso=99 --c++14 --language=+volatile --exceptions --anachronisms --fp-model=3 -O0 --tradeoff=4 --compact-max-size=200 -g -Wc-w544 -Wc-w557 -Ctc27xd -Y0 -N0 -Z0"
INC="$PROJ/Debug/TASKING_C_C___Compiler-Include_paths__-I_.opt"

# project sources (root + new SBL/OTA dirs); Libraries keep their ADS objects
SRCS="Cpu0_Main.c Cpu1_Main.c Cpu2_Main.c Blinky_LED.c \
      sbl/sbl_boot.c \
      bsp/flash_ota.c \
      mw/ota/crc32.c mw/ota/ota_meta.c mw/ota/ota_boot.c mw/ota/tcfw_bundle.c mw/ota/ota_rx.c \
      mw/crypto/sha512.c mw/crypto/ed25519v.c \
      mw/sf/sf_frame.c"

cd "$PROJ"
for f in $SRCS; do
    o="$OUT/$(echo "$f" | tr '/' '_').o"
    echo "cctc $f"
    "$CTC/cctc" $CFLAGS "-f$INC" --dep-file="${o%.o}.d" -o "${o%.o}.src" "$f"
    "$CTC/astc" -Og -Os --no-warnings= --error-limit=42 -o "$o" "${o%.o}.src"
done

# link: every object ADS built (Libraries + Configurations) plus ours
OBJS=$(find "$OUT/Libraries" "$OUT/Configurations" -name '*.o' | tr '\\' '/')
MINE=$(for f in $SRCS; do echo "$OUT/$(echo "$f" | tr '/' '_').o"; done)

echo "link myCarSbl.elf"
"$CTC/cctc" --lsl-file="Lcf_SBL.lsl" -Wl-Oc -Wl-OL -Wl-Ot -Wl-Ox -Wl-Oy \
    -Wl--map-file="$OUT/myCarSbl.map" -Wl-mc -Wl-mf -Wl-mi -Wl-mk -Wl-ml -Wl-mm -Wl-md -Wl-mr -Wl-mu \
    --no-warnings= -Wl--error-limit=42 --fp-model=3 -lrt --lsl-core=vtc --exceptions --strict \
    --anachronisms --force-c++ -Ctc27xd -o"$OUT/myCarSbl.elf" -Wl-o"$OUT/myCarSbl.hex:IHEX" \
    $OBJS $MINE

"$CTC/elfsize" "$OUT/myCarSbl.elf"
echo "hex: $(ls -l $OUT/myCarSbl.hex | awk '{print $5}') bytes"
