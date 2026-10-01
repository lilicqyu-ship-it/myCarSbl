#!/bin/sh
# build_sbl.sh - command-line TASKING build of the SBL, mirroring the flags
# AURIX Development Studio generates (Debug/makefile), with Lcf_SBL.lsl.
#
# Compiles the same source set ADS builds (project sources + the iLLD subset
# left after the .cproject source exclusions), so it does not need a prior
# ADS build and survives "Clean". Objects mirror the ADS Debug/ layout; a
# source is recompiled only when its .o is missing or older.
#
# ADS's bundled TASKING refuses to run outside the IDE ("license does not
# support standalone"); the full TASKING v6.3r1 install on this bench does.
# Newer major version than ADS's 1.1r8 - this build is a compile/link
# validation, the authoritative binary still comes from ADS.
# Run from the repo root:  sh tools/build_sbl.sh
set -e

CTC="/c/Program Files/TASKING/TriCore v6.3r1/ctc/bin"
PROJ=$(pwd)
OUT=Debug

CFLAGS="-cs --misrac-version=2012 -D__CPU__=tc27xd --iso=99 --c++14 --language=+volatile --exceptions --anachronisms --fp-model=3 -O0 --tradeoff=4 --compact-max-size=200 -g -Wc-w544 -Wc-w557 -Ctc27xd -Y0 -N0 -Z0"
INC="$PROJ/Debug/TASKING_C_C___Compiler-Include_paths__-I_.opt"

cd "$PROJ"

# source list: project files + every non-excluded .c under Libraries/ and
# Configurations/ (the exclusion set is parsed from .cproject, like ADS)
SRCS=$(python - <<'PY'
import os, re
s = open('.cproject', encoding='utf8').read()
m = re.search(r'<entry excluding="([^"]+)"', s)
excl = set(m.group(1).split('|')) if m else set()
out = []
for f in ('Cpu0_Main.c', 'Cpu1_Main.c', 'Cpu2_Main.c', 'Blinky_LED.c',
          'sbl/sbl_boot.c', 'bsp/flash_ota.c',
          'mw/ota/crc32.c', 'mw/ota/ota_meta.c', 'mw/ota/ota_boot.c',
          'mw/ota/tcfw_bundle.c', 'mw/ota/ota_rx.c',
          'mw/crypto/sha512.c', 'mw/crypto/ed25519v.c'):
    assert os.path.isfile(f), f
    out.append(f)
for root in ('Libraries', 'Configurations'):
    for dirpath, dirs, files in os.walk(root):
        rel = dirpath.replace('\\', '/')
        if any(rel == e or rel.startswith(e + '/') for e in excl):
            dirs[:] = []
            continue
        for fn in sorted(files):
            if fn.endswith('.c'):
                out.append(rel + '/' + fn)
print(' '.join(out))
PY
)

for f in $SRCS; do
    src="$PROJ/$f"
    o="$OUT/${f%.c}.o"
    mkdir -p "$(dirname "$o")"
    if [ ! -f "$o" ] || [ "$src" -nt "$o" ]; then
        echo "cctc $f"
        "$CTC/cctc" $CFLAGS "-f$INC" --dep-file="${o%.o}.d" -o "${o%.o}.src" "$f"
        "$CTC/astc" -Og -Os --no-warnings= --error-limit=42 -o "$o" "${o%.o}.src"
    fi
done

OBJS=$(find "$OUT/Libraries" "$OUT/Configurations" "$OUT/sbl" "$OUT/bsp" "$OUT/mw" -name '*.o' | tr '\\' '/'; \
       for x in Cpu0_Main Cpu1_Main Cpu2_Main Blinky_LED; do [ -f "$OUT/$x.o" ] && echo "$OUT/$x.o"; done; true)

echo "link myCarSbl.elf ($(echo "$OBJS" | wc -l) objects)"
"$CTC/cctc" --lsl-file="Lcf_SBL.lsl" -Wl-Oc -Wl-OL -Wl-Ot -Wl-Ox -Wl-Oy \
    -Wl--map-file="$OUT/myCarSbl.map" -Wl-mc -Wl-mf -Wl-mi -Wl-mk -Wl-ml -Wl-mm -Wl-md -Wl-mr -Wl-mu \
    --no-warnings= -Wl--error-limit=42 --fp-model=3 -lrt --lsl-core=vtc --exceptions --strict \
    --anachronisms --force-c++ -Ctc27xd -o"$OUT/myCarSbl.elf" -Wl-o"$OUT/myCarSbl.hex:IHEX" \
    $OBJS

"$CTC/elfsize" "$OUT/myCarSbl.elf"
echo "hex: $(ls -l $OUT/myCarSbl.hex | awk '{print $5}') bytes"
