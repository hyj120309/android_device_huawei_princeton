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
# Rewrite recovery.img into the image the recovery_ramdisk partition expects.
#
# This device keeps its kernel in a separate partition, and the stock
# recovery_ramdisk.img has kernel_size = 0 in its boot header: that
# partition holds a ramdisk and nothing else.
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
# So build the normal recovery.img and rewrite its header in place
# afterwards. The rewrite only drops the kernel and recomputes the header
# id; the ramdisk bytes, addresses and page size are untouched, which makes
# the result byte-identical to what mkbootimg produces without --kernel.
#
# Overwriting recovery.img rather than emitting a second file keeps the
# usual upload paths working: whatever collects
# out/target/product/<device>/recovery.img picks up the flashable image.
#
# This file is read from device/*/*/build/tasks/*.mk late in main.mk, after
# the recoveryimage rule exists, so appending to it works.
#

PRINCETON_RECOVERY_IMG := $(INSTALLED_RECOVERYIMAGE_TARGET)
PRINCETON_MKBOOTIMG_TOOL := $(TOPDIR)device/huawei/princeton/tools/mkbootimg_from_ramdisk.py

ifneq ($(strip $(PRINCETON_RECOVERY_IMG)),)

# A stamp is needed because the recipe modifies its own prerequisite: without
# it make would compare the stamp against the rewritten recovery.img and run
# the conversion again on every build.
PRINCETON_RECOVERY_STAMP := $(PRODUCT_OUT)/.recovery_ramdisk_converted

$(PRINCETON_RECOVERY_STAMP): $(PRINCETON_RECOVERY_IMG) $(PRINCETON_MKBOOTIMG_TOOL)
	@echo "Rewriting recovery header for the recovery_ramdisk partition"
	$(hide) python3 $(PRINCETON_MKBOOTIMG_TOOL) $(PRINCETON_RECOVERY_IMG) $(PRINCETON_RECOVERY_IMG).tmp
	$(hide) mv -f $(PRINCETON_RECOVERY_IMG).tmp $(PRINCETON_RECOVERY_IMG)
	@echo "recovery.img now has kernel_size = 0"
	$(hide) touch $@

# `make recoveryimage` produces the flashable image directly.
recoveryimage: $(PRINCETON_RECOVERY_STAMP)

.PHONY: recovery_ramdisk
recovery_ramdisk: $(PRINCETON_RECOVERY_STAMP)

endif # PRINCETON_RECOVERY_IMG
