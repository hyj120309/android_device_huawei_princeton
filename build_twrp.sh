#!/usr/bin/env bash
#
# Copyright (C) 2026 The android_device_huawei_princeton contributors
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

#
# Turn a TWRP recovery.img into the image the recovery_ramdisk partition
# expects.
#
# The EMUI layout keeps the kernel in its own partition, so the
# recovery_ramdisk partition holds a boot image with kernel_size = 0. AOSP
# always builds a full recovery.img (with a kernel), because the
# recoveryimage target does not exist otherwise, so this drops the kernel
# and rewrites the header. Nothing else changes: every address in the header
# still comes from BoardConfig.mk, which in turn mirrors the stock image.
#
# usage:
#   ./build_twrp.sh [recovery.img] [output.img]
#
# With no arguments it looks for the build output of a twrp_princeton tree.
#
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)

IN=${1:-}
OUT=${2:-$HERE/out/recovery_ramdisk-princeton.img}

if [ -z "$IN" ]; then
	# Standard locations, newest tree layout first.
	for c in \
		"$HERE/../../../out/target/product/princeton/recovery.img" \
		"$HERE/out/recovery.img"
	do
		if [ -f "$c" ]; then IN=$c; break; fi
	done
fi

[ -n "$IN" ] || {
	echo "usage: $0 <recovery.img> [output.img]" >&2
	echo "could not find a recovery.img to convert" >&2
	exit 1
}
[ -f "$IN" ] || { echo "no such file: $IN" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"

echo "input : $IN ($(stat -c%s "$IN") bytes)"
python3 "$HERE/tools/mkbootimg_from_ramdisk.py" "$IN" "$OUT"

# Sanity: the result must be a v0 boot image with no kernel, and the ramdisk
# has to start with gzip or an lz4/cpio magic depending on the compression
# TWRP was built with.
python3 - "$OUT" <<'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
f = struct.unpack_from("<8s10I16s512s32s", d, 0)
if f[0] != b"ANDROID!":
    sys.exit("not a boot image")
if f[1] != 0:
    sys.exit(f"kernel_size is {f[1]}, expected 0")
rd = d[f[8]:f[8] + f[3]]
magic = rd[:4]
kind = {b"\x1f\x8b\x08\x00": "gzip",
        b"\x04\x22\x4d\x18": "lz4",
        b"070701": "cpio"}.get(magic, f"unknown ({magic.hex()})")
print(f"ok: kernel_size=0 ramdisk={f[3]:#x} compression={kind}")
print(f"    kernel_addr={f[2]:#x} ramdisk_addr={f[4]:#x} "
      f"tags_addr={f[7]:#x} page={f[8]}")
PY

echo "done: $OUT"
echo
echo "The recovery_ramdisk partition is separate from the kernel partition:"
echo "  fastboot flash recovery_ramdisk $OUT"
echo "Verify the partition name on the device first - on some builds it is"
echo "recovery instead. Check /dev/block/by-name/ before flashing."
