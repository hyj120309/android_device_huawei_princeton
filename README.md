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
vendorsetup.sh                            lunch entry
system.prop                               properties the stock recovery sets
recovery/root/init.recovery.princeton.rc   recovery init for this device
recovery/root/etc/twrp/twrp.fstab          partitions + encryption
prebuilt/kernel_dummy                     placeholder kernel, discarded
prebuilt/stock_ramdisk.gz                 stock recovery_ramdisk (gzip cpio)
prebuilt/stock_recovery_vendor.gz         stock recovery_vendor (gzip cpio)
tools/mkbootimg_from_ramdisk.py            rewrites the boot header
build_twrp.sh                             runs that tool + verifies the result
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
which is the opposite of what is wanted. The tree therefore builds a normal
`recovery.img` with `prebuilt/kernel_dummy` as the kernel, and then
`tools/mkbootimg_from_ramdisk.py` rewrites the header with `kernel_size = 0`
and drops the kernel. The dummy kernel is never executed.

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

Manifest: **`platform_manifest_twrp_omni`, branch `twrp-9.0`**.
The `platform_manifest_twrp_aosp` repo has no 9.0 branch (it starts at
twrp-11), so omni is the only option for API 28.

With Action-TWRP-builder:

| parameter | value |
|---|---|
| `MANIFEST_URL` | `https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git` |
| `MANIFEST_BRANCH` | `twrp-9.0` |
| `DEVICE_TREE_URL` | this repo |
| `DEVICE_PATH` | `device/huawei/princeton` |
| `DEVICE_NAME` | `princeton` |
| `MAKEFILE_NAME` | `twrp_princeton` |
| `BUILD_TARGET` | `recovery` |

That produces `recovery.img`. Convert it:

```sh
./build_twrp.sh path/to/recovery.img
# -> out/recovery_ramdisk-princeton.img
```

Or run the included `Convert TWRP recovery.img to recovery_ramdisk` workflow
on that image.

Flash the converted image to the **recovery_ramdisk** partition, not
`recovery`:

```sh
# confirm the partition names on the device first
adb shell 'ls /dev/block/by-name/ | grep -i recov'

fastboot flash recovery_ramdisk out/recovery_ramdisk-princeton.img
```

Keep the stock `recovery_ramdisk` image from the firmware package before
flashing; a copy is in `prebuilt/stock_ramdisk.gz`.

## Encryption

`/data` is **f2fs with file based encryption**, from the stock fstab:

```
/dev/block/bootdevice/by-name/userdata /data f2fs \
    length=-16384,fileencryption=aes-256-xts:aes-256-cts,reservedsize=20M
```

`fileencryption=` means FBE, not FDE. The relevant settings:

```
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_CRYPTO_FS_TYPE := "f2fs"
TW_CRYPTO_REAL_BLKDEV := "/dev/block/bootdevice/by-name/userdata"
TW_CRYPTO_KEY_LOC := "footer"
TW_INCLUDE_KEYMASTER := true
```

`TW_CRYPTO_KEY_LOC := "footer"` because the stock layout uses
`length=-16384`: the crypto footer lives at the end of the f2fs filesystem.
If `/data` is reformatted with different parameters the footer is gone and
only a factory reset recreates it.

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
| vendor | `/vendor` | ext4 |
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
- **`system.prop` sets `ro.hardware=kirin980`** while the init file is named
  `init.recovery.princeton.rc`. The recovery init imports
  `init.recovery.${ro.hardware}.rc` and TWRP additionally imports
  `init.recovery.${TARGET_DEVICE}.rc`; if neither fires, rename the file.
