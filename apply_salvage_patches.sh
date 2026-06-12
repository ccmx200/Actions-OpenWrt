#!/usr/bin/env bash
set -euo pipefail

#===========================
# Color & Emoji
#===========================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
CHECK="✅"; WARN="⚠️"; GEAR="⚙️"; FILE_ICON="📄"; PARTY="🎉"; MAG="🔍"

#===========================
# Helper
#===========================
print_header() {
    echo -e "${CYAN}${BOLD}============================================${NC}"
    echo -e "${CYAN}${BOLD}   Salvage-1 自动补丁脚本（稳定版）${NC}"
    echo -e "${CYAN}${BOLD}============================================${NC}\n"
}
print_step() { echo -e "${BOLD}${GEAR} 步骤 $1/$2: $3${NC}"; }
print_ok()   { echo -e "   ${GREEN}${CHECK} ${1}${NC}"; }
print_skip() { echo -e "   ${YELLOW}${WARN} 跳过：${1}（已存在）${NC}"; }
backup_file() {
    local f="$1"
    if [ -f "$f" ]; then
        cp "$f" "${f}.bak.$(date +%s)"
        echo -e "   ℹ️  已备份：${f}.bak"
    fi
}

#===========================
# Pre-check
#===========================
if [ ! -f feeds.conf.default ] && [ ! -f Makefile ]; then
    echo -e "${RED}❌ 错误：请在 OpenWrt 源码根目录运行。${NC}"
    exit 1
fi
print_header

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DTS_SRC="${SCRIPT_DIR}/ipq8072-salvage-1.dts"
BOARD_SRC="${SCRIPT_DIR}/board-cuicanmx_salvage-1.ipq8074"
[ ! -f "$DTS_SRC" ] && echo -e "${RED}❌ 缺失 DTS: ${DTS_SRC}${NC}" && exit 1
[ ! -f "$BOARD_SRC" ] && echo -e "${RED}❌ 缺失 Board: ${BOARD_SRC}${NC}" && exit 1

TOTAL_STEPS=8
STEP=0

#===========================
# 1. 复制 DTS
#===========================
STEP=$((STEP+1)); print_step $STEP $TOTAL_STEPS "复制 DTS"
DST="target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq8072-salvage-1.dts"
mkdir -p "$(dirname "$DST")"
if [ -f "$DST" ]; then print_skip "$DST"; else cp "$DTS_SRC" "$DST"; print_ok "DTS 已复制"; fi

#===========================
# 2. 复制 Board 固件
#===========================
STEP=$((STEP+1)); print_step $STEP $TOTAL_STEPS "复制 Board 固件"
DST="package/firmware/ipq-wifi/src/board-cuicanmx_salvage-1.ipq8074"
mkdir -p "$(dirname "$DST")"
if [ -f "$DST" ]; then print_skip "$DST"; else cp "$BOARD_SRC" "$DST"; print_ok "Board 已复制"; fi

#===========================
# 3. uboot-envtools
#===========================
STEP=$((STEP+1)); print_step $STEP $TOTAL_STEPS "uboot-envtools"
F="package/boot/uboot-tools/uboot-envtools/files/qualcommax_ipq807x"
if grep -q 'cuicanmx,salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    # 使用真实 Tab 缩进
    add=$'\tcuicanmx,salvage-1)\n\t\tubootenv_add_mtd "0:APPSBLENV" "0x0" "0x10000" "0x10000"\n\t\t;;'
    awk -v add="$add" '{print} /zte,mf269)/{print add}' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    print_ok "$F"
fi

#===========================
# 4. ipq-wifi Makefile
#===========================
STEP=$((STEP+1)); print_step $STEP $TOTAL_STEPS "ipq-wifi Makefile"
F="package/firmware/ipq-wifi/Makefile"
if grep -q 'cuicanmx_salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    # ALLWIFIBOARDS 行 (带 Tab 和续行符)
    add=$'\tcuicanmx_salvage-1 \\'
    awk -v add="$add" '{print} /cmiot_ax18 \\/{print add}' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    # eval 调用行 (无缩进要求)
    add2='$(eval $(call generate-ipq-wifi-package,cuicanmx_salvage-1,CUICANMX Salvage-1))'
    awk -v add="$add2" '{print} /\$\(eval \$\(call generate-ipq-wifi-package,zyxel_scr50axe,Zyxel SCR50AXE\)\)/{print add}' \
        "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    print_ok "$F"
fi

#===========================
# 5. ipq807x.mk 映像定义
#===========================
STEP=$((STEP+1)); print_step $STEP $TOTAL_STEPS "映像定义 ipq807x.mk"
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
    print_ok "$F"
fi

#===========================
# 6. 02_network (修复模式)
#===========================
STEP=$((STEP+1)); print_step $STEP $TOTAL_STEPS "网络接口 02_network"
F="target/linux/qualcommax/ipq807x/base-files/etc/board.d/02_network"
if grep -q 'cuicanmx,salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    add=$'\tcuicanmx,salvage-1|\\'
    awk -v add="$add" '{print} /compex,wpq873\|\\/{print add}' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    print_ok "$F"
fi

#===========================
# 7. 11-ath11k-caldata
#===========================
STEP=$((STEP+1)); print_step $STEP $TOTAL_STEPS "WiFi 校准数据"
F="target/linux/qualcommax/ipq807x/base-files/etc/hotplug.d/firmware/11-ath11k-caldata"
if grep -q 'cuicanmx,salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    add=$'\tcuicanmx,salvage-1)\n\t\tcaldata_extract "0:ART" 0x20000 0x20000\n\t\t;;'
    awk -v add="$add" '{print} /zyxel,nwa210ax)/{print add}' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    print_ok "$F"
fi

#===========================
# 8. platform.sh (修复模式)
#===========================
STEP=$((STEP+1)); print_step $STEP $TOTAL_STEPS "升级平台 platform.sh"
F="target/linux/qualcommax/ipq807x/base-files/lib/upgrade/platform.sh"
if grep -q 'cuicanmx,salvage-1' "$F"; then
    print_skip "$F"
else
    backup_file "$F"
    add=$'\tcuicanmx,salvage-1|\\'
    awk -v add="$add" '{print} /aliyun,ap8220\|\\/{print add}' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    print_ok "$F"
fi

#===========================
# 最终展示修改内容
#===========================
echo -e "\n${CYAN}${BOLD}============================================${NC}"
echo -e "${CYAN}${BOLD}   ${MAG} 修改验证：关键文件内容展示${NC}"
echo -e "${CYAN}${BOLD}============================================${NC}\n"

show_section() {
    local title="$1" file="$2" pattern="$3" context="${4:-2}"
    echo -e "${BOLD}${FILE_ICON}  ${title} (${file})${NC}"
    if grep -q "$pattern" "$file"; then
        grep -n -A${context} -B${context} "$pattern" "$file" | sed 's/^/  /'
    else
        echo -e "   ${RED}❌ 未找到匹配行！${NC}"
    fi
    echo ""
}

# uboot-envtools
show_section "uboot-envtools 新增片段" \
  "package/boot/uboot-tools/uboot-envtools/files/qualcommax_ipq807x" \
  "cuicanmx,salvage-1" 2

# ipq-wifi Makefile: 两个位置
echo -e "${BOLD}${FILE_ICON}  ipq-wifi Makefile ALLWIFIBOARDS${NC}"
grep -n -A1 "cuicanmx_salvage-1" package/firmware/ipq-wifi/Makefile | sed 's/^/  /'
echo ""
echo -e "${BOLD}${FILE_ICON}  ipq-wifi Makefile 包评估${NC}"
grep -n "cuicanmx_salvage-1,CUICANMX" package/firmware/ipq-wifi/Makefile | sed 's/^/  /'
echo ""

# ipq807x.mk (Device)
show_section "ipq807x.mk 设备定义" \
  "target/linux/qualcommax/image/ipq807x.mk" \
  "cuicanmx_salvage-1" 5

# 02_network
show_section "02_network 接口" \
  "target/linux/qualcommax/ipq807x/base-files/etc/board.d/02_network" \
  "cuicanmx,salvage-1" 1

# 11-ath11k-caldata
show_section "11-ath11k-caldata" \
  "target/linux/qualcommax/ipq807x/base-files/etc/hotplug.d/firmware/11-ath11k-caldata" \
  "cuicanmx,salvage-1" 2

# platform.sh
show_section "platform.sh 升级匹配" \
  "target/linux/qualcommax/ipq807x/base-files/lib/upgrade/platform.sh" \
  "cuicanmx,salvage-1" 1

echo -e "${GREEN}${PARTY} 全部完成！现在可运行 make menuconfig，选择 Target Profile = CUICANMX Salvage-1${NC}"
