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
# Optional argument: path to an App slot-A hex (e.g. tc275_car's build output);
# the script then also emits Debug/factory_full.hex = SBL + App in ONE file
# for whole-chip flashing:  sh tools/build_sbl.sh ../tc275_car/"TriCore Debug (TASKING)"/tc275_car.hex
set -e

CTC="/c/Program Files/TASKING/TriCore v6.3r1/ctc/bin"
PROJ=$(pwd)
OUT=Debug
VER=$(python -c "import re; print(re.search(r'#define\s+APP_VERSION_STRING\s+\"([^\"]+)\"', open('mw/app_version.h').read()).group(1))")

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
for f in ('Cpu0_Main.c', 'Cpu1_Main.c', 'Cpu2_Main.c', 'sbl_led.c',
          'sbl/sbl_boot.c', 'bsp/flash_ota.c',
          'mw/app_version.c',
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
       for x in Cpu0_Main Cpu1_Main Cpu2_Main sbl_led; do [ -f "$OUT/$x.o" ] && echo "$OUT/$x.o"; done; true)

echo "link tc275_sbl.elf ($(echo "$OBJS" | wc -l) objects)"
"$CTC/cctc" --lsl-file="Lcf_SBL.lsl" -Wl-Oc -Wl-OL -Wl-Ot -Wl-Ox -Wl-Oy \
    -Wl--map-file="$OUT/tc275_sbl.map" -Wl-mc -Wl-mf -Wl-mi -Wl-mk -Wl-ml -Wl-mm -Wl-md -Wl-mr -Wl-mu \
    --no-warnings= -Wl--error-limit=42 --fp-model=3 -lrt --lsl-core=vtc --exceptions --strict \
    --anachronisms --force-c++ -Ctc27xd -o"$OUT/tc275_sbl.elf" -Wl-o"$OUT/tc275_sbl.hex:IHEX" \
    $OBJS

"$CTC/elfsize" "$OUT/tc275_sbl.elf"
echo "hex: $(ls -l $OUT/tc275_sbl.hex | awk '{print $5}') bytes"
cp "$OUT/tc275_sbl.hex" "$OUT/tc275_sbl_v${VER}.hex"    # 版本化副本（SCons 构建同名约定）

if [ -n "$1" ]; then
    python tools/merge_hex.py "$OUT/factory_full.hex" "$OUT/tc275_sbl.hex" "$1"
fi
