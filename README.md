# iKuai Q3000 OpenWrt

GitHub Actions build for the iKuai IK-Q3000, ported to the current OpenWrt 25.12 stable branch.

## Build source

- Upstream: `https://github.com/openwrt/openwrt`
- Ref: `openwrt-25.12`
- Target: `mediatek/filogic`
- Device profile: `ikuai_q3000`

The workflow follows the stock iKuai flash layout and generates the Q3000 initramfs, factory and sysupgrade images.

## Stock-layout image profile

| Partition | Offset | Size |
| --- | ---: | ---: |
| bl2 | `0x000000` | `0x100000` |
| u-boot-env | `0x100000` | `0x080000` |
| Factory | `0x180000` | `0x200000` |
| fip | `0x380000` | `0x200000` |
| ubi | `0x580000` | `0x4000000` |

The SPI NAND definition enables MediaTek NMBM compatibility and keeps the original 64 MiB UBI region used by the stock-layout port. The build does **not** replace BL2, Factory calibration data or FIP.

## Expected output

- `openwrt-...-ikuai_q3000-initramfs-kernel.bin` — temporary RAM boot/testing image
- `openwrt-...-ikuai_q3000-squashfs-factory.bin` — complete UBI image for first installation with the stock layout
- `openwrt-...-ikuai_q3000-squashfs-sysupgrade.bin` — upgrade image once OpenWrt is running

The seed configuration enables SquashFS, initramfs, LuCI and Simplified Chinese LuCI translations.

## Build

Every relevant push to `main` starts the build, or it can be started manually from **Actions → Build iKuai Q3000 OpenWrt → Run workflow**.

The workflow always clones the current `openwrt-25.12` stable branch before compiling and uploads the resulting Q3000 images as an Actions artifact.

## Flashing caution

Test `initramfs-kernel.bin` through U-Boot/TFTP first when possible and back up the original MTD partitions before persistent flashing. The file named `squashfs-factory.bin` is a firmware UBI image; it must never be written to the router's `Factory` calibration partition.
