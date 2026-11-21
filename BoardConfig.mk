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
# TWRP device tree for the Honor V20 (princeton / PCT-AL10).
#
# Kirin 980, EMUI 9.1 (Android 9 / API 28), system-as-root.
#
# Derived from the stock recovery_ramdisk and recovery_vendor of the EMUI
# 9.1 package. See README.md for where each value comes from and what
# decryption depends on.
#

LOCAL_PATH := device/huawei/princeton

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a75
TARGET_CPU_VARIANT_RUNTIME := cortex-a75
TARGET_CPU_SMP := true

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_USES_64_BIT_BINDER := true
TARGET_SUPPORTS_64_BIT_APPS := true

# Bootloader / platform
TARGET_BOOTLOADER_BOARD_NAME := kirin980
TARGET_NO_BOOTLOADER := true
TARGET_BOARD_PLATFORM := kirin980
TARGET_BOARD_PLATFORM_GPU := mali-g76

# Kernel
#
# The stock image layout puts the kernel in its own "kernel" partition and
# the recovery_ramdisk partition holds only a ramdisk (kernel_size = 0 in
# the boot header). We still have to let the build produce a normal
# recovery.img, because AOSP gates the whole recoveryimage target on
# TARGET_NO_KERNEL being false:
#
#   ifeq (,$(filter true,$(TARGET_NO_KERNEL) $(TARGET_NO_RECOVERY)))
#   INSTALLED_RECOVERYIMAGE_TARGET := $(PRODUCT_OUT)/recovery.img
#   else
#   INSTALLED_RECOVERYIMAGE_TARGET :=        # make recoveryimage does nothing
#   endif
#
# So build a full recovery.img and strip the kernel back out afterwards:
# tools/mkbootimg_from_ramdisk.py rewrites the header with kernel_size = 0,
# which is exactly the shape the stock partition has. The kernel never needs
# to actually work, it is discarded.
#
# Addresses below come from the stock recovery_ramdisk.img header. They are
# exactly the AOSP defaults applied to base 0x10000000:
#
#   kernel_addr  0x10008000 = base + 0x00008000
#   ramdisk_addr 0x11000000 = base + 0x01000000
#   second_addr  0x10f00000 = base + 0x00f00000
#   tags_addr    0x10000100 = base + 0x00000100
#
# so only the base has to be set; the offsets are the defaults mkbootimg
# already uses. They are spelled out in the comment rather than the makefile
# so a change to the stock layout is easy to spot.
BOARD_KERNEL_BASE     := 0x10000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_CMDLINE  :=
BOARD_MKBOOTIMG_ARGS  := --header_version 0

# A kernel file is required by the build even though it gets discarded.
# Point at the dummy that ships with this tree (a 1-sector file is enough
# for mkbootimg).
TARGET_PREBUILT_KERNEL := $(LOCAL_PATH)/prebuilt/kernel_dummy

# Recovery image shape
BOARD_USES_RECOVERY_AS_BOOT := false
TARGET_RECOVERY_FSTAB := $(LOCAL_PATH)/recovery/root/etc/twrp/twrp.fstab
TARGET_RECOVERY_PIXEL_FORMAT := "ABGR_8888"
TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT := true

# Partition sizes. Not enforced by the build (nothing here does assert-max-
# image-size on recovery because BOARD_RECOVERYIMAGE_PARTITION_SIZE is unset),
# but kept for reference: the stock recovery_ramdisk partition is 32MB and
# the ramdisk alone has to fit in it.
# BOARD_RECOVERYIMAGE_PARTITION_SIZE := 0x2000000

# The stock recovery ramdisk uses system-as-root, so the build has to put
# /system under /system_root and symlink it.
BOARD_BUILD_SYSTEM_ROOT_IMAGE := false

# Screen: 6.4" 2310x1080. The panel itself is picked at runtime by lcd_kit
# from the device tree, so only the geometry is set here.
TW_THEME := portrait_hdpi
DEVICE_RESOLUTION := 1080x2310
TW_MAX_BRIGHTNESS := 4095
TW_DEFAULT_BRIGHTNESS := 2000
TW_NO_SCREEN_BLANK := true
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd_backlight0/brightness"

# Decryption: /data is f2fs with file based encryption
# (aes-256-xts:aes-256-cts), so this is FBE and the keys are unwrapped by
# the TEE through keymaster. teecd must be running first; see
# recovery/root/init.recovery.princeton.rc.
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 1
TW_CRYPTO_FS_TYPE := "f2fs"
TW_CRYPTO_REAL_BLKDEV := "/dev/block/bootdevice/by-name/userdata"
TW_CRYPTO_MNT_POINT := "/data"
TW_CRYPTO_KEY_LOC := "footer"
TW_CRYPTO_SYSTEM_VOLD_DEBUG := true
BOARD_USES_METADATA_PARTITION := false
TW_INCLUDE_KEYMASTER := true

# TARGET_HW_DISK_ENCRYPTION is deliberately not set. It is a Qualcomm
# switch: turning it on makes TWRP link libcryptfs_hw from
# device/qcom/common/cryptfs_hw, which this device does not have, and the
# build fails with
#
#   ninja: error: '.../libcryptfs_hw_intermediates/export_includes',
#   needed by '.../libcryptfsfde_intermediates/import_includes', missing
#
# It has nothing to do with FBE: on Kirin the keys are unwrapped by the TEE
# through keymaster, which is TW_INCLUDE_CRYPTO_FBE and TW_INCLUDE_KEYMASTER
# above.

# Filesystems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_SUPPRESS_SECURE_ERASE := true
BOARD_HAS_LARGE_FILESYSTEM := true

# Storage. UFS raw nodes are /dev/block/sd* with unstable numbering; the
# fstab uses the by-name symlinks.
TW_INTERNAL_STORAGE_PATH := "/data/media/0"
TW_INTERNAL_STORAGE_MOUNT_POINT := "data"
TW_EXTERNAL_STORAGE_PATH := "/external_sd"
TW_EXTERNAL_STORAGE_MOUNT_POINT := "external_sd"
TW_HAS_USB_STORAGE := true

# Properties
TARGET_SYSTEM_PROP := $(LOCAL_PATH)/system.prop

# Files this tree contributes to the recovery ramdisk are listed in
# twrp_princeton.mk via PRODUCT_COPY_FILES. AOSP 9 has no
# TARGET_RECOVERY_DEVICE_DIRS (that was removed after 8.1) and the build
# never reads the device tree's own recovery/root directory, so anything
# that has to end up in the ramdisk must go through PRODUCT_COPY_FILES.

# TWRP behaviour
TW_EXTRA_LANGUAGES := true
TW_DEFAULT_LANGUAGE := zh_CN
TW_SCREEN_BLANK_ON_BOOT := true
TW_INPUT_BLACKLIST := "hbtp_vm"
TW_USE_TOOLBOX := true
TW_INCLUDE_FUSE_EXFAT := true
TW_EXCLUDE_TWRPAPP := true
TW_NO_LEGACY_PROPS := true

# system-as-root, matching the stock recovery ramdisk layout
BOARD_ROOT_EXTRA_SYMLINKS := \
    /vendor:system/vendor \
    /bin:system/bin \
    /etc:system/etc
