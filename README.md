# TWRP device tree — Honor V20 (princeton / PCT-AL10)

Kirin 980, EMUI 9.1 (Android 9 / API 28), system-as-root.

Every value here is derived from the stock EMUI 9.1 `recovery_ramdisk` and
`recovery_vendor` images rather than from a template check. Where a value
came from one of those images it is noted next to it, so it can be diffed
against a different firmware version.

## Layout

```
BoardConfig.mk                            board/TWRP settings
twrp_princeton.mk                         product makefile
AndroidProducts.mk                        product registration
vendorsetup.sh                            kept as a no-op (see file)
system.prop                               properties the stock recovery sets
recovery/root/init.recovery.princeton.rc   recovery init for this device
recovery/root/etc/twrp/twrp.fstab          partitions + encryption
prebuilt/kernel_dummy                     placeholder kernel, never in the image
tools/mkbootimg_from_ramdisk.py            rewrites a boot header by hand
build_twrp.sh                             runs that tool by hand + verifies
```

## How the image is laid out (this is the part that differs from most devices)

The stock `recovery_ramdisk.img` has **`kernel_size = 0`**. The kernel is
not in the recovery image at all — it has its own partition:

```
kernel              24MB
recovery_ramdisk    32MB     <- ramdisk only
recovery_vendor     16MB
recovery_vbmeta
```

AOSP gates the `recoveryimage` target on `TARGET_NO_KERNEL`:

```make
ifeq (,$(filter true, $(TARGET_NO_KERNEL) $(TARGET_NO_RECOVERY)))
INSTALLED_RECOVERYIMAGE_TARGET := $(PRODUCT_OUT)/recovery.img
else
INSTALLED_RECOVERYIMAGE_TARGET :=          # make recoveryimage does nothing
endif
```

So setting `TARGET_NO_KERNEL := true` makes the build produce **nothing**,
which is the opposite of what is wanted. The tree therefore keeps the target
alive with `prebuilt/kernel_dummy` and drops the kernel on the mkbootimg
command line itself:

```make
# BoardConfig.mk
BOARD_RECOVERY_MKBOOTIMG_ARGS := --header_version 0 --kernel /dev/null
```

`build-recoveryimage-target` runs
`$(MKBOOTIMG) --kernel $(recovery_kernel) $(INTERNAL_RECOVERYIMAGE_ARGS) ... $(BOARD_RECOVERY_MKBOOTIMG_ARGS)`,
and `BOARD_RECOVERY_MKBOOTIMG_ARGS` comes **after** the internal
`--kernel`, so mkbootimg's argparse keeps the last value: the header is
written with `kernel_size = 0` and no kernel pages — exactly the shape of
the stock partition image, straight out of the build. The dummy kernel is
never read and never executed.

(An earlier version of this tree rewrote `recovery.img` after the build via
a `build/tasks/*.mk` hook. That never ran: nothing in the twrp-11 AOSP
tree includes device `build/tasks` files — the omni 9 tree only loaded
`vendor/omni/build/tasks/*` because `vendor/omni/Android.mk` includes its
own tree. The hook is gone.)

Boot header fields are the AOSP defaults on base `0x10000000`, which is what
the stock image uses:

| field | value |
|---|---|
| base | `0x10000000` |
| kernel_addr | `0x10008000` (base + 0x8000) |
| ramdisk_addr | `0x11000000` (base + 0x1000000) |
| second_addr | `0x10f00000` (base + 0xf00000) |
| tags_addr | `0x10000100` (base + 0x100) |
| page size | 2048 |
| header version | 0 |

## Building

Manifest: **`platform_manifest_twrp_aosp`, branch `twrp-11`**.
The tree is written against the Android 11 (API 30) TWRP branches: the
product makefile inherits `base.mk` (Android 11 removed `embedded.mk`),
and the crypto/`prebuilt` wiring matches the `android-11` branch of
`android_bootable_recovery`. The omni `twrp-9.0` tree is **not** usable
with this device tree anymore: its build assumes API 28 and the product
chain differs.

With Action-TWRP-builder:

| parameter | value |
|---|---|
| `MANIFEST_URL` | `https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git` |
| `MANIFEST_BRANCH` | `twrp-11` |
| `DEVICE_TREE_URL` | this repo |
| `DEVICE_TREE_BRANCH` | `main` (also the workflow default; there is no `master` branch) |
| `DEVICE_PATH` | `device/huawei/princeton` |
| `DEVICE_NAME` | `princeton` |
| `MAKEFILE_NAME` | `twrp_princeton` |
| `BUILD_TARGET` | `recovery` |

That produces `out/target/product/princeton/recovery.img` with
`kernel_size = 0` already — the mkbootimg override in BoardConfig.mk drops
the kernel at image creation time, so there is no post-processing step and
whatever uploads `recovery.img` uploads the right image.

If you have a `recovery.img` from somewhere else (a full boot image with a
kernel in it), convert it by hand:

```sh
./build_twrp.sh path/to/recovery.img
# -> out/recovery_ramdisk-princeton.img
```

Flash to the **recovery_ramdisk** partition, not `recovery`:

```sh
# confirm the partition names on the device first
adb shell 'ls /dev/block/by-name/ | grep -i recov'

# from a full build, recovery.img is already converted:
fastboot flash recovery_ramdisk out/target/product/princeton/recovery.img

# or, when converting by hand:
fastboot flash recovery_ramdisk out/recovery_ramdisk-princeton.img
```

Keep a copy of the stock `recovery_ramdisk` from the firmware package before
flashing, so the device can be restored.

## Encryption

`/data` is **f2fs with file based encryption**, from the stock fstab:

```
/dev/block/bootdevice/by-name/userdata /data f2fs \
    length=-16384,fileencryption=aes-256-xts:aes-256-cts,reservedsize=20M
```

`fileencryption=` means FBE, not FDE. The settings that the twrp-11 tree
actually reads:

```
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_CRYPTO_SYSTEM_VOLD_DEBUG := true
RECOVERY_SDCARD_ON_DATA := true
```

`TW_INCLUDE_CRYPTO` builds `crypto/fde` (libcryptfsfde); on API >= 24 TWRP
also sets `TW_INCLUDE_CRYPTO_FBE` itself, which pulls in `crypto/ext4crypt`.
Keymaster support is chosen by the platform SDK version inside
`prebuilt/Android.mk`: on the SDK 30 twrp-11 tree it links
`android.hardware.keymaster@4.0` + `libkeymaster4support` with
`TW_KEYMASTER_MAX_API=4`, and at runtime it walks down to the 3.0 HAL this
device actually has.

Names that appear in other TWRP device trees — `TW_CRYPTO_FS_TYPE`,
`TW_CRYPTO_KEY_LOC`, `TW_CRYPTO_MNT_POINT`, `TW_INCLUDE_KEYMASTER`,
`TW_USE_FSCRYPT_POLICY`, `TW_INCLUDE_FBE_METADATA_DECRYPT` — do not exist on
the twrp-11 tree either and do nothing there.

`TARGET_HW_DISK_ENCRYPTION` is deliberately **not** set: it is a Qualcomm
switch that makes TWRP link `libcryptfs_hw` from
`device/qcom/common/cryptfs_hw`, which this device does not have. Enabling it
fails the build with a missing-module error that names a file which looks
like it should exist. It has nothing to do with FBE on Kirin.

The stock fstab uses `length=-16384`, so the crypto footer lives at the end
of the f2fs filesystem. If `/data` is reformatted with different parameters
the footer is gone and only a factory reset recreates it.

**The keys are hardware-wrapped.** The stock
`recovery_vendor:/vendor/etc/init/init.recovery.huawei.rc` starts `teecd`
before vold touches `/data`:

```
on post-fs-data
    start teecd
on property:vold.status=start
    exec /system/bin/vdc --wait cryptfs enablefilecrypto
    init_user0
    unlock_user0_key
```

`unlock_user0_key` asks the TEE to unwrap the key. `recovery/root/init.recovery.princeton.rc`
reproduces the ordering, and `teecd` itself comes from the stock
`recovery_vendor` (`/vendor/bin/teecd`, statically linked aarch64) — the
vendor partition is mounted by the recovery, so the binary is present.

If the device has been unlocked, the teeos reflashed, or credentials changed
outside the stock flow, keymaster can refuse and no retry in TWRP will help.

## Partitions

From `recovery_vendor:/vendor/etc/recovery.fstab`:

| partition | mount | fs |
|---|---|---|
| system | `/system_root` | ext4 |
| vendor | `/vendor` | erofs (ro by design) |
| product | `/product` | ext4 |
| version | `/version` | ext4 |
| cust | `/cust` | ext4 |
| splash2 | `/splash2` | ext4 |
| cache | `/cache` | ext4 |
| userdata | `/data` | f2fs (FBE) |
| misc | `/misc` | emmc |

Everything goes through `/dev/block/bootdevice/by-name/*`. This is UFS and
the raw nodes are `/dev/block/sd*` with unstable numbering, so the by-name
symlinks are the only safe reference.

The modem partitions are listed but commented out in `twrp.fstab`: they only
matter when debugging the radio, and mounting them read-write can disturb it.

## Screen

6.4" 2310x1080 LTPS, `TW_THEME := portrait_hdpi`. The panel is picked at
runtime by `lcd_kit` from the device tree — the DTS lists several candidates
(`samsung_ea8074`, `lg_nt36772a`, `jdi_td4336`, `sharp_td4336`,
`boe_hx83112e`), each enabled per unit. TWRP does not need to know which one.

`TW_BRIGHTNESS_PATH` is `/sys/class/leds/lcd_backlight0/brightness`. If the
screen stays dark, check that node on the device — the name comes from the
stock kernel's backlight driver.

## Known limitations

- Not yet verified on hardware. The device tree compiles into the expected
  shape; whether TWRP comes up depends on the points below.
- **Touch**: `TW_INPUT_BLACKLIST := "hbtp_vm"` is a guess. Check
  `/proc/bus/input/devices` on the device and adjust.
- **SELinux**: the stock ramdisk's sepolicy is used. If teecd or keymaster
  are denied, `dmesg | grep avc` will say which rule is missing.
- **`system.prop` sets `ro.hardware=kirin980`**, and the recovery init imports
  `init.recovery.${ro.hardware}.rc`. The same rc file is therefore installed
  under **both** names — `init.recovery.kirin980.rc` and
  `init.recovery.princeton.rc` — so whichever value `ro.hardware` has on the
  running device, the import hits. If TWRP comes up without teecd, check
  `getprop ro.hardware` in the running recovery and rename accordingly.
