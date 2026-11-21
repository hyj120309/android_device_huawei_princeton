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
# Produce the image the recovery_ramdisk partition actually expects.
#
# This device keeps its kernel in a separate partition, and the stock
# recovery_ramdisk.img has kernel_size = 0 in its boot header: the partition
# holds a ramdisk and nothing else.
#
# AOSP cannot be told to build that directly. The recoveryimage target only
# exists when TARGET_NO_KERNEL is false:
#
#   ifeq (,$(filter true, $(TARGET_NO_KERNEL) $(TARGET_NO_RECOVERY)))
#   INSTALLED_RECOVERYIMAGE_TARGET := $(PRODUCT_OUT)/recovery.img
#   else
#   INSTALLED_RECOVERYIMAGE_TARGET :=       # make recoveryimage does nothing
#   endif
#
# and build-recoveryimage-target always passes --kernel. BOARD_RECOVERY_IMAGE_PREPARE
# runs before mkbootimg, so it cannot post-process the output either.
#
# So build the normal recovery.img and rewrite its header afterwards. The
# rewrite only drops the kernel and recomputes the header id; the ramdisk
# bytes, addresses and page size are untouched, which makes the result
# byte-identical to what mkbootimg produces without --kernel.
#
# This file is read from device/*/*/build/tasks/*.mk late in main.mk, after
# the recoveryimage rule exists, so appending to it works.
#

PRINCETON_RECOVERY_RAMDISK := $(PRODUCT_OUT)/recovery_ramdisk-princeton.img
PRINCETON_MKBOOTIMG_TOOL := $(TOPDIR)device/huawei/princeton/tools/mkbootimg_from_ramdisk.py

$(PRINCETON_RECOVERY_RAMDISK): $(INSTALLED_RECOVERYIMAGE_TARGET) $(PRINCETON_MKBOOTIMG_TOOL)
	@echo "Rewriting recovery header for the recovery_ramdisk partition: $@"
	$(hide) python3 $(PRINCETON_MKBOOTIMG_TOOL) $(INSTALLED_RECOVERYIMAGE_TARGET) $@

# `make recoveryimage` also produces the flashable image, so there is no
# extra step to remember.
recoveryimage: $(PRINCETON_RECOVERY_RAMDISK)

# Explicit targets for when only the conversion is wanted.
.PHONY: recovery_ramdisk
recovery_ramdisk: $(PRINCETON_RECOVERY_RAMDISK)
