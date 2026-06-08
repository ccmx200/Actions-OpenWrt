#!/usr/bin/env bash
set -euo pipefail

#===========================
# Color & Emoji Definitions
#===========================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
CHECK="✅"; WARN="⚠️"; GEAR="⚙️"; FILE_ICON="📄"; PARTY="🎉"

#===========================
# Helper Functions
#===========================
print_header() {
    echo -e "${CYAN}${BOLD}============================================${NC}"
    echo -e "${CYAN}${BOLD}   Salvage-1 设备支持自动补丁脚本${NC}"
    echo -e "${CYAN}${BOLD}============================================${NC}\n"
}

print_step() { echo -e "${BOLD}${GEAR} 步骤 $1/$2: $3${NC}"; }
print_ok()   { echo -e "   ${GREEN}${CHECK} ${1}${NC}"; }
print_skip() { echo -e "   ${YELLOW}${WARN} 跳过：${1}（已存在）${NC}"; }
print_warn() { echo -e "   ${YELLOW}${WARN} 警告：${1}${NC}"; }

backup_file() {
    local f="$1"
    if [ -f "$f" ]; then
        cp "$f" "${f}.bak.$(date +%s)"
        echo -e "   ℹ️  已备份：${f}.bak"
    fi
}

#===========================
# Pre-flight Checks
#===========================
if [ ! -f feeds.conf.default ] && [ ! -f Makefile ]; then
    echo -e "${RED}❌ 错误：请在 OpenWrt 源码根目录运行此脚本。${NC}"
    exit 1
fi

print_header

# 寻找同目录下的补丁文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DTS_SRC="${SCRIPT_DIR}/ipq8072-salvage-1.dts"
BOARD_SRC="${SCRIPT_DIR}/board-cuicanmx_salvage-1.ipq8074"

if [ ! -f "$DTS_SRC" ]; then
    echo -e "${RED}❌ 未找到设备树文件: ${DTS_SRC}${NC}"
    echo "请将 ipq8072-salvage-1.dts 放置在与脚本相同的目录。"
    exit 1
fi
if [ ! -f "$BOARD_SRC" ]; then
    echo -e "${RED}❌ 未找到 WiFi 板级固件: ${BOARD_SRC}${NC}"
    echo "请将 board-cuicanmx_salvage-1.ipq8074 放置在与脚本相同的目录。"
    exit 1
fi

TOTAL_STEPS=8
STEP=0

#===========================
# 1. 复制设备树文件
#===========================
STEP=$((STEP+1))
print_step $STEP $TOTAL_STEPS "复制设备树 (DTS)"
DTS_DST="target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq8072-salvage-1.dts"
mkdir -p "$(dirname "$DTS_DST")"
if [ -f "$DTS_DST" ]; then
    print_skip "$DTS_DST"
else
    cp "$DTS_SRC" "$DTS_DST"
    print_ok "DTS 已复制到 $DTS_DST"
fi

#===========================
# 2. 复制 WiFi 板级固件
#===========================
STEP=$((STEP+1))
print_step $STEP $TOTAL_STEPS "复制 WiFi 板级固件"
BOARD_DST="package/firmware/ipq-wifi/src/board-cuicanmx_salvage-1.ipq8074"
mkdir -p "$(dirname "$BOARD_DST")"
if [ -f "$BOARD_DST" ]; then
    print_skip "$BOARD_DST"
else
    cp "$BOARD_SRC" "$BOARD_DST"
    print_ok "Board 文件已复制到 $BOARD_DST"
fi

#===========================
# 3. uboot-envtools
#===========================
STEP=$((STEP+1))
print_step $STEP $TOTAL_STEPS "uboot-envtools 环境变量"
F="package/boot/uboot-tools/uboot-envtools/files/qualcommax_ipq807x"
if grep -q 'cuicanmx,salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    sed -i '/zte,mf269)/a\\tcuicanmx,salvage-1)\n\t\tubootenv_add_mtd "0:APPSBLENV" "0x0" "0x10000" "0x10000"\n\t\t;;' "$F"
    print_ok "$F 已修改"
fi

#===========================
# 4. ipq-wifi Makefile
#===========================
STEP=$((STEP+1))
print_step $STEP $TOTAL_STEPS "ipq-wifi 包注册"
F="package/firmware/ipq-wifi/Makefile"
if grep -q 'cuicanmx_salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    # 在 ALLWIFIBOARDS 列表插入一行（带续行符）
    awk -v add='\tcuicanmx_salvage-1 \\' \
      '{print} /cmiot_ax18 \\/{print add}' \
      "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    # 在末尾追加 eval 调用
    awk -v add='$(eval $(call generate-ipq-wifi-package,cuicanmx_salvage-1,CUICANMX Salvage-1))' \
      '{print} /\$\(eval \$\(call generate-ipq-wifi-package,zyxel_scr50axe,Zyxel SCR50AXE\)\)/{print add}' \
      "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    print_ok "$F 已修改"
fi

#===========================
# 5. 映像生成规则
#===========================
STEP=$((STEP+1))
print_step $STEP $TOTAL_STEPS "映像生成规则 (ipq807x.mk)"
F="target/linux/qualcommax/image/ipq807x.mk"
if grep -q 'Device/cuicanmx_salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    cat >> "$F" << 'MK_EOF'

define Device/cuicanmx_salvage-1
  $(call Device/FitImage)
  $(call Device/UbiFit)
  DEVICE_VENDOR := CUICANMX
  DEVICE_MODEL := Salvage-1
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  DEVICE_DTS_CONFIG := config@hk01
  SOC := ipq8072
  DEVICE_PACKAGES := ath11k-firmware-ipq8074 ipq-wifi-cuicanmx_salvage-1
endef
TARGET_DEVICES += cuicanmx_salvage-1
MK_EOF
    print_ok "已追加设备定义到 $F"
fi

#===========================
# 6. 网络接口配置
#===========================
STEP=$((STEP+1))
print_step $STEP $TOTAL_STEPS "网络接口 (02_network)"
F="target/linux/qualcommax/ipq807x/base-files/etc/board.d/02_network"
if grep -q 'cuicanmx,salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    sed -i '/compex,wpq873\\/a\\tcuicanmx,salvage-1|\\' "$F"
    print_ok "$F 已修改"
fi

#===========================
# 7. WiFi 校准数据
#===========================
STEP=$((STEP+1))
print_step $STEP $TOTAL_STEPS "WiFi 校准数据提取"
F="target/linux/qualcommax/ipq807x/base-files/etc/hotplug.d/firmware/11-ath11k-caldata"
if grep -q 'cuicanmx,salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    sed -i '/zyxel,nwa210ax)/a\\tcuicanmx,salvage-1)\n\t\tcaldata_extract "0:ART" 0x20000 0x20000\n\t\t;;' "$F"
    print_ok "$F 已修改"
fi

#===========================
# 8. 升级支持
#===========================
STEP=$((STEP+1))
print_step $STEP $TOTAL_STEPS "升级平台 (platform.sh)"
F="target/linux/qualcommax/ipq807x/base-files/lib/upgrade/platform.sh"
if grep -q 'cuicanmx,salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    sed -i '/aliyun,ap8220\\/a\\tcuicanmx,salvage-1|\\' "$F"
    print_ok "$F 已修改"
fi

#===========================
# Summary
#===========================
echo -e "\n${CYAN}${BOLD}============================================${NC}"
echo -e "${CYAN}${BOLD}   ${PARTY} 补丁应用完毕！关键修改摘要${NC}"
echo -e "${CYAN}${BOLD}============================================${NC}\n"
echo -e "  ${FILE_ICON}  DTS               : ipq8072-salvage-1.dts → 设备树"
echo -e "  ${FILE_ICON}  Board Firmware    : board-cuicanmx_salvage-1.ipq8074"
echo -e "  ${FILE_ICON}  uboot-envtools    : APPSBLENV 分区 (0x10000)"
echo -e "  ${FILE_ICON}  ipq-wifi Makefile : 注册板级包"
echo -e "  ${FILE_ICON}  ipq807x.mk        : FIT/Ubi 映像，NAND 升级"
echo -e "  ${FILE_ICON}  02_network        : lan/wan 接口绑定"
echo -e "  ${FILE_ICON}  caldata           : ART 偏移 0x20000 校准"
echo -e "  ${FILE_ICON}  platform.sh       : sysupgrade 支持"
echo -e "\n${GREEN}现在可以执行 make menuconfig 并选择 Target Profile = CUICANMX Salvage-1${NC}"
