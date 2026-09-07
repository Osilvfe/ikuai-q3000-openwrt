#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$PWD}"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SELF_DIR/.." && pwd)"

DTS_DIR="$ROOT/target/linux/mediatek/dts"
IMAGE_MK="$ROOT/target/linux/mediatek/image/filogic.mk"
NETWORK="$ROOT/target/linux/mediatek/filogic/base-files/etc/board.d/02_network"
WIFI_MAC="$ROOT/target/linux/mediatek/filogic/base-files/etc/hotplug.d/ieee80211/11_fix_wifi_mac"

for f in "$IMAGE_MK" "$NETWORK" "$WIFI_MAC"; do
    [[ -f "$f" ]] || { echo "Missing expected OpenWrt file: $f" >&2; exit 1; }
done

install -m 0644 "$REPO_DIR/dts/mt7981b-ikuai-q3000.dtsi" "$DTS_DIR/mt7981b-ikuai-q3000.dtsi"
install -m 0644 "$REPO_DIR/dts/mt7981b-ikuai-q3000.dts" "$DTS_DIR/mt7981b-ikuai-q3000.dts"

python3 - "$IMAGE_MK" "$NETWORK" "$WIFI_MAC" <<'PY'
from pathlib import Path
import sys

image_mk, network, wifi_mac = map(Path, sys.argv[1:])

# Add the stock-iKuai U-Boot-compatible profile.  The 64 MiB image limit
# matches the stock Q3000 UBI partition (0x0580000 + 0x04000000).
text = image_mk.read_text()
if "define Device/ikuai_q3000" not in text:
    marker = "TARGET_DEVICES += jcg_q30-pro\n"
    if marker not in text:
        raise SystemExit("Could not find jcg_q30-pro insertion point in filogic.mk")
    block = r'''

define Device/ikuai_q3000
  DEVICE_VENDOR := iKuai
  DEVICE_MODEL := Q3000
  DEVICE_DTS := mt7981b-ikuai-q3000
  DEVICE_DTS_DIR := ../dts
  SUPPORTED_DEVICES := ikuai,q3000
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 65536k
  KERNEL_IN_UBI := 1
  IMAGES += factory.bin
  IMAGE/factory.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += ikuai_q3000
'''
    text = text.replace(marker, marker + block, 1)
    image_mk.write_text(text)

# Q3000 exposes three LAN DSA ports and one WAN port.
text = network.read_text()
if "\tikuai,q3000|\\\n" not in text:
    marker = "\tjcg,q30-pro|\\\n"
    if marker not in text:
        raise SystemExit("Could not find network insertion point")
    text = text.replace(marker, marker + "\tikuai,q3000|\\\n", 1)
    network.write_text(text)

# Derive deterministic radio MACs from the calibration/Factory base MAC.
text = wifi_mac.read_text()
if "\tikuai,q3000)\n" not in text:
    marker = "\tiptime,ax3000q)\n"
    if marker not in text:
        raise SystemExit("Could not find Wi-Fi MAC insertion point")
    block = '''\tikuai,q3000)\n\t\taddr=$(mtd_get_mac_binary "Factory" 0x4)\n\t\t[ "$PHYNBR" = "0" ] && macaddr_add $addr 1 > /sys${DEVPATH}/macaddress\n\t\t[ "$PHYNBR" = "1" ] && macaddr_add $addr 2 > /sys${DEVPATH}/macaddress\n\t\t;;\n'''
    text = text.replace(marker, block + marker, 1)
    wifi_mac.write_text(text)
PY

echo "Q3000 support applied to $ROOT"
