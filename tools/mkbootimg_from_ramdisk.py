#!/usr/bin/env python3
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

"""
Rewrite a recovery.img so its boot header says kernel_size = 0.

The stock EMUI layout keeps the kernel in its own partition, so the
recovery_ramdisk partition holds nothing but a ramdisk: its boot header has
kernel_size = 0 and the ramdisk starts at the first page boundary.

AOSP's build always produces a recovery.img with a kernel in it (the
recoveryimage target does not exist otherwise, see BoardConfig.mk), so this
takes that output, drops the kernel and rewrites the header. Every other
field is preserved, and the header id is recomputed the way AOSP's
mkbootimg does it, so the result is byte-identical to what

    mkbootimg --ramdisk <rd> --base <base> --pagesize <ps>

would have produced.

usage: mkbootimg_from_ramdisk.py <in.img> <out.img>
"""

import hashlib
import struct
import sys

# Android boot image header v0.
#   8s  magic
#  10I  kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size,
#       second_addr, tags_addr, page_size, header_version, os_version
#  16s  name
# 512s  cmdline
#  32s  id
#  32s  extra_cmdline
HDR_FMT = "<8s10I16s512s32s32s"
HDR_SIZE = struct.calcsize(HDR_FMT)
ID_OFF = 8 + 10 * 4 + 16 + 512      # 576
ID_LEN = 32

F_IDX_KERNEL_SIZE = 1
F_IDX_KERNEL_ADDR = 2
F_IDX_RAMDISK_SIZE = 3
F_IDX_RAMDISK_ADDR = 4
F_IDX_SECOND_SIZE = 5
F_IDX_TAGS_ADDR = 7
F_IDX_PAGE_SIZE = 8
F_IDX_HEADER_VERSION = 9


def pages(n, page):
    return (n + page - 1) // page


def pad(n, page):
    return pages(n, page) * page


def header_id(kernel, ramdisk, second):
    """The 32-byte header id exactly as AOSP mkbootimg computes it.

    The first 20 bytes are sha1(kernel || le32(len) || ramdisk || le32(len)
    || second || le32(len)); the rest is zero padding, so the total field is
    always ID_LEN bytes.
    """
    h = hashlib.sha1()
    for blob in (kernel, ramdisk, second):
        h.update(blob)
        h.update(struct.pack("<I", len(blob)))
    return h.digest().ljust(ID_LEN, b"\0")


def parse(data, src):
    if len(data) < HDR_SIZE:
        sys.exit(f"{src}: too small to be a boot image ({len(data)} bytes)")

    fields = list(struct.unpack_from(HDR_FMT, data, 0))
    magic = fields[0]
    if magic != b"ANDROID!":
        sys.exit(f"{src}: not an Android boot image (magic {magic!r})")

    hdr_ver = fields[F_IDX_HEADER_VERSION]
    if hdr_ver != 0:
        sys.exit(f"{src}: boot header version {hdr_ver}; only v0 is "
                 f"supported (this device uses v0)")

    page = fields[F_IDX_PAGE_SIZE]
    if page not in (2048, 4096, 8192, 16384, 32768, 65536):
        sys.exit(f"{src}: implausible page size {page}")

    ksz = fields[F_IDX_KERNEL_SIZE]
    rsz = fields[F_IDX_RAMDISK_SIZE]
    ssz = fields[F_IDX_SECOND_SIZE]

    k_off = page
    r_off = k_off + pad(ksz, page)
    s_off = r_off + pad(rsz, page)

    if s_off + ssz > len(data):
        sys.exit(f"{src}: truncated image: needs {s_off + ssz} bytes, "
                 f"file has {len(data)}")

    kernel = data[k_off:k_off + ksz]
    ramdisk = data[r_off:r_off + rsz]
    second = data[s_off:s_off + ssz]

    if len(kernel) != ksz:
        sys.exit(f"{src}: truncated kernel")
    if len(ramdisk) != rsz:
        sys.exit(f"{src}: truncated ramdisk ({len(ramdisk)} of {rsz} bytes)")
    if len(second) != ssz:
        sys.exit(f"{src}: truncated second stage")

    return fields, page, kernel, ramdisk, second


def build(fields, page, ramdisk):
    """Header with no kernel and no second stage, plus the ramdisk."""
    out = list(fields)
    out[F_IDX_KERNEL_SIZE] = 0
    out[F_IDX_SECOND_SIZE] = 0
    # Addresses stay as they were: they come from BoardConfig.mk and match
    # the stock image, and dropping the kernel does not move the ramdisk.

    blob = bytearray(struct.pack(HDR_FMT, *out))
    blob[ID_OFF:ID_OFF + ID_LEN] = header_id(b"", ramdisk, b"")

    return bytes(blob) + b"\0" * (page - HDR_SIZE) + \
        ramdisk + b"\0" * (pad(len(ramdisk), page) - len(ramdisk))


def verify(dst, page, expect_ramdisk, expect_addr):
    """Re-read the output and check it is what we meant to write."""
    data = open(dst, "rb").read()
    fields, page2, kernel, ramdisk, second = parse(data, dst)

    problems = []
    if page2 != page:
        problems.append(f"page size {page2} != {page}")
    if fields[F_IDX_KERNEL_SIZE] != 0:
        problems.append(f"kernel_size {fields[F_IDX_KERNEL_SIZE]} != 0")
    if fields[F_IDX_SECOND_SIZE] != 0:
        problems.append(f"second_size {fields[F_IDX_SECOND_SIZE]} != 0")
    if ramdisk != expect_ramdisk:
        problems.append("ramdisk content differs from the input")
    if fields[F_IDX_RAMDISK_ADDR] != expect_addr:
        problems.append(f"ramdisk_addr {fields[F_IDX_RAMDISK_ADDR]:#x} "
                        f"!= {expect_addr:#x}")

    # The ramdisk data we just read back has to have the length the header
    # claims. parse() already sliced by that length, so compare the result.
    if len(ramdisk) != fields[F_IDX_RAMDISK_SIZE]:
        problems.append("ramdisk_size field disagrees with the data")

    # Trailing padding must not contain anything unexpected.
    tail_start = page + pad(len(ramdisk), page)
    if len(data) > tail_start and any(data[tail_start:]):
        problems.append("non-zero trailing bytes")

    if problems:
        for p in problems:
            print(f"  FAIL: {p}", file=sys.stderr)
        sys.exit(f"{dst}: verification failed")

    return fields, ramdisk


def main(src, dst):
    original = open(src, "rb").read()
    fields, page, kernel, ramdisk, second = parse(original, src)

    if fields[F_IDX_SECOND_SIZE]:
        print(f"note: dropping a {fields[F_IDX_SECOND_SIZE]}-byte second "
              f"stage; the stock recovery_ramdisk has none", file=sys.stderr)

    out = build(fields, page, ramdisk)
    with open(dst, "wb") as f:
        f.write(out)

    vfields, vramdisk = verify(dst, page, ramdisk,
                              fields[F_IDX_RAMDISK_ADDR])

    print(f"{src} -> {dst}")
    print(f"  page={page} base_kernel_addr=0x{vfields[F_IDX_KERNEL_ADDR]:x} "
          f"ramdisk_addr=0x{vfields[F_IDX_RAMDISK_ADDR]:x} "
          f"tags_addr=0x{vfields[F_IDX_TAGS_ADDR]:x}")
    print(f"  kernel: {len(kernel)} -> 0 bytes")
    print(f"  ramdisk: {len(vramdisk)} bytes (unchanged)")
    print(f"  output: {len(out)} bytes, header id "
          f"{vfields[-2][:4].hex()}…")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
