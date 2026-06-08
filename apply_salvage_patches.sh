#!/usr/bin/env bash
set -euo pipefail

#===========================
# Color & Emoji Definitions
#===========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

CHECK_MARK="✅"
CROSS_MARK="❌"
WARN="⚠️"
INFO="ℹ️"
ROCKET="🚀"
PACKAGE="📦"
GEAR="⚙️"
FILE_ICON="📄"
PARTY="🎉"

#===========================
# Helper Functions
#===========================
print_header() {
    echo -e "${CYAN}${BOLD}============================================${NC}"
    echo -e "${CYAN}${BOLD}   Salvage-1 设备支持自动补丁脚本${NC}"
    echo -e "${CYAN}${BOLD}============================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BOLD}${GEAR} 步骤 $1/$2: $3${NC}"
}

print_success() {
    echo -e "   ${GREEN}${CHECK_MARK} 成功：${1}${NC}"
}

print_skip() {
    echo -e "   ${YELLOW}${WARN} 跳过：${1}（已存在）${NC}"
}

print_warn() {
    echo -e "   ${YELLOW}${WARN} 警告：${1}${NC}"
}

print_error() {
    echo -e "   ${RED}${CROSS_MARK} 错误：${1}${NC}"
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.bak.$(date +%s)"
        echo -e "   ${INFO} 已备份原文件：${file}.bak.$(date +%s)"
    fi
}

ensure_file_writable() {
    local file="$1"
    if [ -f "$file" ] && [ ! -w "$file" ]; then
        print_error "文件 $file 不可写"
        exit 1
    fi
}

#===========================
# Pre-flight Checks
#===========================
if [ ! -f feeds.conf.default ] && [ ! -f Makefile ]; then
    echo -e "${RED}${CROSS_MARK} 错误：请在 OpenWrt 源码根目录运行此脚本。${NC}"
    exit 1
fi

print_header

TOTAL_STEPS=8
CURRENT_STEP=0

#===========================
# 1. uboot-envtools
#===========================
CURRENT_STEP=$((CURRENT_STEP+1))
print_step $CURRENT_STEP $TOTAL_STEPS "uboot-envtools 环境变量支持"
file="package/boot/uboot-tools/uboot-envtools/files/qualcommax_ipq807x"
ensure_file_writable "$file"
if grep -q 'cuicanmx,salvage-1' "$file"; then
    print_skip "$file"
else
    backup_file "$file"
    sed -i '/zte,mf269)/a\\tcuicanmx,salvage-1)\n\t\tubootenv_add_mtd "0:APPSBLENV" "0x0" "0x10000" "0x10000"\n\t\t;;' "$file"
    print_success "$file 已修改"
fi

#===========================
# 2. ipq-wifi Makefile
#===========================
CURRENT_STEP=$((CURRENT_STEP+1))
print_step $CURRENT_STEP $TOTAL_STEPS "ipq-wifi 固件包注册"
file="package/firmware/ipq-wifi/Makefile"
ensure_file_writable "$file"
if grep -q 'cuicanmx_salvage-1' "$file"; then
    print_skip "$file"
else
    backup_file "$file"
    sed -i '/cmiot_ax18 \\/a\\\tcuicanmx_salvage-1 \\' "$file"
    sed -i '/$(eval $(call generate-ipq-wifi-package,zyxel_scr50axe,Zyxel SCR50AXE))/a$(eval $(call generate-ipq-wifi-package,cuicanmx_salvage-1,CUICANMX Salvage-1))' "$file"
    print_success "$file 已修改"
fi

#===========================
# 3. DTS 文件
#===========================
CURRENT_STEP=$((CURRENT_STEP+1))
print_step $CURRENT_STEP $TOTAL_STEPS "设备树源文件 (DTS)"
file="target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq8072-salvage-1.dts"
if [ -f "$file" ]; then
    print_skip "$file"
else
    mkdir -p "$(dirname "$file")"
    # 注意：此处使用 heredoc 原样写入，内容与之前完全一致，为节省篇幅省略具体内容，实际脚本中应保留完整 DTS
    cat > "$file" << 'DTS_EOF'
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT
/* Copyright (c) 2025-2026, cuicanmx <arl96075@163.com> */

/dts-v1/;

#include "ipq8074.dtsi"
#include "ipq8074-hk-cpu.dtsi"
#include "ipq8074-ess.dtsi"
#include "ipq8074-nss.dtsi"
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
#include <dt-bindings/leds/common.h>

/ {
	model = "Salvage-1";
	compatible = "cuicanmx,salvage-1", "qcom,ipq8074";

	aliases {
		serial0 = &blsp1_uart5;
		ethernet0 = &dp5;
		ethernet1 = &dp3;
		ethernet2 = &dp2;
		ethernet3 = &dp1;
	};

	chosen {
		stdout-path = "serial0:115200n8";
		bootargs-append = " root=/dev/ubiblock0_1";
	};

	/* SD 卡 3.3V 电源，由 GPIO21 使能 */
	vqmmc_sd_reg: regulator-vqmmc-sd {
		compatible = "regulator-fixed";
		regulator-name = "vqmmc_sd";
		regulator-min-microvolt = <3300000>;
		regulator-max-microvolt = <3300000>;
		regulator-always-on;
		gpios = <&tlmm 21 GPIO_ACTIVE_HIGH>;
		enable-active-high;
	};

	/* 原厂 WPS 按键 */
	gpio_keys {
		compatible = "gpio-keys";
		pinctrl-0 = <&button_pins>;
		pinctrl-names = "default";

		wps {
			label = "wps";
			gpios = <&tlmm 34 GPIO_ACTIVE_LOW>;
			linux,code = <KEY_WPS_BUTTON>;
			debounce-interval = <60>;
		};
	};

	/* 原厂 LED */
	leds {
		compatible = "gpio-leds";
		pinctrl-0 = <&led_pins>;
		pinctrl-names = "default";

		led_heartbeat: led_heartbeat {
			label = "led_heartbeat";
			gpios = <&tlmm 20 GPIO_ACTIVE_HIGH>;
			linux,default-trigger = "heartbeat";
		};

		led_sys_r: SYS_R {
			label = "SYS_R";
			gpios = <&tlmm 30 GPIO_ACTIVE_HIGH>;
			default-state = "on";
		};

		led_sys_g: SYS_G {
			label = "SYS_G";
			gpios = <&tlmm 54 GPIO_ACTIVE_HIGH>;
			default-state = "on";
		};

		led_5g_r: 5G_R {
			label = "5G_R";
			gpios = <&tlmm 51 GPIO_ACTIVE_HIGH>;
			default-state = "on";
		};

		led_5g_g: 5G_G {
			label = "5G_G";
			gpios = <&tlmm 19 GPIO_ACTIVE_HIGH>;
			default-state = "on";
		};

		led_5g_b: 5G_B {
			label = "5G_B";
			gpios = <&tlmm 29 GPIO_ACTIVE_HIGH>;
			default-state = "on";
		};

		led_rssi_r: RSSI_R {
			label = "RSSI_R";
			gpios = <&tlmm 55 GPIO_ACTIVE_HIGH>;
			default-state = "on";
		};

		led_rssi_g: RSSI_G {
			label = "RSSI_G";
			gpios = <&tlmm 56 GPIO_ACTIVE_HIGH>;
			default-state = "on";
		};

		led_rssi_b: RSSI_B {
			label = "RSSI_B";
			gpios = <&tlmm 50 GPIO_ACTIVE_HIGH>;
			default-state = "on";
		};
	};
};

/* 主线缺失的 SD 卡控制器 */
&soc {
	sdhc_2: mmc@7864900 {
		compatible = "qcom,ipq8074-sdhci", "qcom,sdhci-msm-v4";
		reg = <0x7864900 0x500>, <0x7864000 0x800>;
		reg-names = "hc", "core";
		interrupts = <GIC_SPI 125 IRQ_TYPE_LEVEL_HIGH>,
			     <GIC_SPI 221 IRQ_TYPE_LEVEL_HIGH>;
		interrupt-names = "hc_irq", "pwr_irq";
		clocks = <&gcc GCC_SDCC2_AHB_CLK>,
			 <&gcc GCC_SDCC2_APPS_CLK>,
			 <&xo>;
		clock-names = "iface", "core", "xo";
		resets = <&gcc GCC_SDCC2_BCR>;
		max-frequency = <192000000>;
		mmc-ddr-1_8v;
		bus-width = <4>;
		status = "okay";
	};
};

&tlmm {
	mdio_pins: mdio-pins {
		mdc {
			pins = "gpio68";
			function = "mdc";
			drive-strength = <8>;
			bias-pull-up;
		};
		mdio {
			pins = "gpio69";
			function = "mdio";
			drive-strength = <8>;
			bias-pull-up;
		};
	};

	spi1_pins: spi1-pins {
		mux {
			pins = "gpio42", "gpio43", "gpio44", "gpio45";
			function = "blsp1_spi";
			drive-strength = <8>;
			bias-disable;
		};
	};

	sd_pins: sd-pins {
		mux {
			pins = "gpio63";
			function = "sd_card";
			drive-strength = <8>;
			bias-pull-up;
		};
	};

	/* PCIe0 引脚 */
	pcie0_pins: pcie0-pins {
		pcie0_rst {
			pins = "gpio58";
			function = "pcie0_rst";
			drive-strength = <8>;
			bias-pull-down;
		};
		pcie0_wake {
			pins = "gpio59";
			function = "pcie0_wake";
			drive-strength = <8>;
			bias-pull-down;
		};
	};

	/* 原厂按键引脚 */
	button_pins: button-pins {
		wps_button {
			pins = "gpio34";
			function = "gpio";
			drive-strength = <8>;
			bias-pull-up;
		};
	};

	/* 原厂 LED 引脚 */
	led_pins: led-pins {
		led_heartbeat {
			pins = "gpio20";
			function = "gpio";
			drive-strength = <8>;
			bias-pull-down;
		};
		SYS_R {
			pins = "gpio30";
			function = "gpio";
			drive-strength = <8>;
			bias-pull-down;
		};
		SYS_G {
			pins = "gpio54";
			function = "gpio";
			drive-strength = <8>;
			bias-pull-down;
		};
		5G_R {
			pins = "gpio51";
			function = "gpio";
			drive-strength = <8>;
			bias-pull-down;
		};
		5G_G {
			pins = "gpio19";
			function = "gpio";
			drive-strength = <8>;
			bias-pull-down;
		};
		5G_B {
			pins = "gpio29";
			function = "gpio";
			drive-strength = <8>;
			bias-pull-down;
		};
		RSSI_R {
			pins = "gpio55";
			function = "gpio";
			drive-strength = <8>;
			bias-pull-down;
		};
		RSSI_G {
			pins = "gpio56";
			function = "gpio";
			drive-strength = <8>;
			bias-pull-down;
		};
		RSSI_B {
			pins = "gpio50";
			function = "gpio";
			drive-strength = <8>;
			bias-pull-down;
		};
	};
};

/* 基础外设 */
&blsp1_uart5 { status = "okay"; };
&prng { status = "okay"; };
&cryptobam { status = "okay"; };
&crypto { status = "okay"; };
&qpic_bam { status = "okay"; };

/* SPI NOR */
&blsp1_spi1 {
	status = "okay";
	pinctrl-0 = <&spi1_pins>;
	pinctrl-names = "default";

	flash@0 {
		reg = <0>;
		compatible = "jedec,spi-nor";
		spi-max-frequency = <50000000>;

		partitions {
			compatible = "fixed-partitions";
			#address-cells = <1>;
			#size-cells = <1>;

			partition@0 { label = "0:SBL1"; reg = <0x0 0x50000>; read-only; };
			partition@50000 { label = "0:MIBIB"; reg = <0x50000 0x10000>; read-only; };
			partition@60000 { label = "0:BOOTCONFIG"; reg = <0x60000 0x20000>; read-only; };
			partition@80000 { label = "0:BOOTCONFIG1"; reg = <0x80000 0x20000>; read-only; };
			partition@a0000 { label = "0:QSEE"; reg = <0xa0000 0x180000>; read-only; };
			partition@220000 { label = "0:QSEE_1"; reg = <0x220000 0x180000>; read-only; };
			partition@3a0000 { label = "0:DEVCFG"; reg = <0x3a0000 0x10000>; read-only; };
			partition@3b0000 { label = "0:DEVCFG_1"; reg = <0x3b0000 0x10000>; read-only; };
			partition@3c0000 { label = "0:APDP"; reg = <0x3c0000 0x10000>; read-only; };
			partition@3d0000 { label = "0:APDP_1"; reg = <0x3d0000 0x10000>; read-only; };
			partition@3e0000 { label = "0:RPM"; reg = <0x3e0000 0x40000>; read-only; };
			partition@420000 { label = "0:RPM_1"; reg = <0x420000 0x40000>; read-only; };
			partition@460000 { label = "0:CDT"; reg = <0x460000 0x10000>; read-only; };
			partition@470000 { label = "0:CDT_1"; reg = <0x470000 0x10000>; read-only; };
			partition@480000 { label = "0:APPSBLENV"; reg = <0x480000 0x10000>; };
			partition@490000 { label = "0:APPSBL"; reg = <0x490000 0xa0000>; read-only; };
			partition@530000 { label = "0:APPSBL_1"; reg = <0x530000 0xa0000>; read-only; };
			partition@5d0000 { label = "0:ART"; reg = <0x5d0000 0x40000>; read-only; };
			partition@610000 { label = "0:ETHPHYFW"; reg = <0x610000 0x80000>; read-only; };
		};
	};
};

/* NAND */
&qpic_nand {
	status = "okay";

	nand@0 {
		reg = <0>;
		nand-ecc-strength = <8>;
		nand-ecc-step-size = <512>;
		nand-bus-width = <8>;

		partitions {
			compatible = "fixed-partitions";
			#address-cells = <1>;
			#size-cells = <1>;

			partition@0 {
				label = "rootfs";
				reg = <0x0 0x10000000>;
			};
		};
	};
};

/* eMMC */
&sdhc_1 {
	status = "okay";
	non-removable;
	mmc-ddr-1_8v;
	mmc-hs200-1_8v;
	mmc-hs400-1_8v;
	max-frequency = <192000000>;
};

/* SD 卡槽 */
&sdhc_2 {
	pinctrl-0 = <&sd_pins>;
	pinctrl-names = "default";
	cd-gpios = <&tlmm 63 GPIO_ACTIVE_LOW>;
	vqmmc-supply = <&vqmmc_sd_reg>;
};

/* 双 USB */
&qusb_phy_0 { status = "okay"; };
&ssphy_0 { status = "okay"; };
&usb_0 { status = "okay"; };

&qusb_phy_1 { status = "okay"; };
&ssphy_1 { status = "okay"; };
&usb_1 { status = "okay"; };

/* ========== PCIe 全部启用 ========== */
&pcie_qmp0 { status = "okay"; };
&pcie_qmp1 { status = "okay"; };

&pcie0 {
	status = "okay";
	perst-gpios = <&tlmm 58 GPIO_ACTIVE_LOW>;
};

&pcie1 {
	status = "okay";
	perst-gpios = <&tlmm 61 GPIO_ACTIVE_LOW>;
};

/* MDIO 和 PHY */
&mdio {
	status = "okay";
	pinctrl-0 = <&mdio_pins>;
	pinctrl-names = "default";

	ethernet-phy-package@0 {
		#address-cells = <1>;
		#size-cells = <0>;
		compatible = "qcom,qca8075-package";
		reg = <0>;
		qcom,package-mode = "qsgmii";

		qca8075_0: ethernet-phy@0 {
			compatible = "ethernet-phy-ieee802.3-c22";
			reg = <0>;
		};
		qca8075_1: ethernet-phy@1 {
			compatible = "ethernet-phy-ieee802.3-c22";
			reg = <1>;
		};
		qca8075_2: ethernet-phy@2 {
			compatible = "ethernet-phy-ieee802.3-c22";
			reg = <2>;
		};
	};

	qca8081: ethernet-phy@24 {
		compatible = "ethernet-phy-id004d.d101";
		reg = <24>;
		reset-deassert-us = <10000>;
		reset-gpios = <&tlmm 44 GPIO_ACTIVE_LOW>;
	};
};

/* 交换机 */
&switch {
	status = "okay";

	switch_lan_bmp = <(ESS_PORT1 | ESS_PORT2 | ESS_PORT3)>;
	switch_wan_bmp = <ESS_PORT5>;
	switch_mac_mode = <MAC_MODE_QSGMII>;
	switch_mac_mode1 = <MAC_MODE_SGMII_PLUS>;

	qcom,port_phyinfo {
		port@1 { port_id = <1>; phy_address = <0>; };
		port@2 { port_id = <2>; phy_address = <1>; };
		port@3 { port_id = <3>; phy_address = <2>; };
		port@5 { port_id = <5>; phy_address = <24>; port_mac_sel = "QGMAC_PORT"; };
	};
};

&edma { status = "okay"; };

/* 网络接口 */
&dp1 {
	status = "okay";
	phy-mode = "qsgmii";
	phy-handle = <&qca8075_0>;
	label = "lan3";
};

&dp2 {
	status = "okay";
	phy-mode = "qsgmii";
	phy-handle = <&qca8075_1>;
	label = "lan2";
};

&dp3 {
	status = "okay";
	phy-mode = "qsgmii";
	phy-handle = <&qca8075_2>;
	label = "lan1";
};

&dp5 {
	status = "okay";
	phy-mode = "sgmii";
	phy-handle = <&qca8081>;
	label = "wan";
};

/* Wi‑Fi */
&wifi {
	status = "okay";
	qcom,ath11k-calibration-variant = "Salvage-1";
};
DTS_EOF
    print_success "新建设备树文件 $file"
fi

#===========================
# 4. 映像 Makefile 设备定义
#===========================
CURRENT_STEP=$((CURRENT_STEP+1))
print_step $CURRENT_STEP $TOTAL_STEPS "映像生成规则 (ipq807x.mk)"
file="target/linux/qualcommax/image/ipq807x.mk"
ensure_file_writable "$file"
if grep -q 'Device/cuicanmx_salvage-1' "$file"; then
    print_skip "$file"
else
    backup_file "$file"
    cat >> "$file" << 'MK_EOF'

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
    print_success "追加设备定义到 $file"
fi

#===========================
# 5. 网络接口配置
#===========================
CURRENT_STEP=$((CURRENT_STEP+1))
print_step $CURRENT_STEP $TOTAL_STEPS "网络接口配置 (02_network)"
file="target/linux/qualcommax/ipq807x/base-files/etc/board.d/02_network"
ensure_file_writable "$file"
if grep -q 'cuicanmx,salvage-1' "$file"; then
    print_skip "$file"
else
    backup_file "$file"
    sed -i '/compex,wpq873\\/a\\tcuicanmx,salvage-1|\\' "$file"
    print_success "已添加接口配置到 $file"
fi

#===========================
# 6. 校准数据提取
#===========================
CURRENT_STEP=$((CURRENT_STEP+1))
print_step $CURRENT_STEP $TOTAL_STEPS "WiFi 校准数据 (11-ath11k-caldata)"
file="target/linux/qualcommax/ipq807x/base-files/etc/hotplug.d/firmware/11-ath11k-caldata"
ensure_file_writable "$file"
if grep -q 'cuicanmx,salvage-1' "$file"; then
    print_skip "$file"
else
    backup_file "$file"
    sed -i '/zyxel,nwa210ax)/a\\tcuicanmx,salvage-1)\n\t\tcaldata_extract "0:ART" 0x20000 0x20000\n\t\t;;' "$file"
    print_success "已添加校准数据提取规则"
fi

#===========================
# 7. 升级平台支持
#===========================
CURRENT_STEP=$((CURRENT_STEP+1))
print_step $CURRENT_STEP $TOTAL_STEPS "固件升级平台 (platform.sh)"
file="target/linux/qualcommax/ipq807x/base-files/lib/upgrade/platform.sh"
ensure_file_writable "$file"
if grep -q 'cuicanmx,salvage-1' "$file"; then
    print_skip "$file"
else
    backup_file "$file"
    sed -i '/aliyun,ap8220\\/a\\tcuicanmx,salvage-1|\\' "$file"
    print_success "已添加升级支持"
fi

#===========================
# 8. 二进制 WiFi 板级文件检查
#===========================
CURRENT_STEP=$((CURRENT_STEP+1))
print_step $CURRENT_STEP $TOTAL_STEPS "WiFi 板级固件二进制文件"
binary_file="../board-cuicanmx_salvage-1.ipq8074"
if [ -f "$binary_file" ]; then
    print_success "二进制文件已就位：$binary_file"
else
    print_warn "缺少二进制文件：$binary_file"
    echo -e "   ${YELLOW}请手动将 board-cuicanmx_salvage-1.ipq8074 放置到源码上层目录，${NC}"
    echo -e "   ${YELLOW}或修改脚本中的路径。编译时软件包 ipq-wifi-cuicanmx_salvage-1 需要此文件。${NC}"
fi

#===========================
# Summary & Key Modifications
#===========================
echo ""
echo -e "${CYAN}${BOLD}============================================${NC}"
echo -e "${CYAN}${BOLD}   ${PARTY} 补丁应用完毕！关键修改摘要${NC}"
echo -e "${CYAN}${BOLD}============================================${NC}"
echo ""
echo -e "  ${FILE_ICON}  uboot-envtools   : 添加 appsblenv 分区 (大小 0x10000)"
echo -e "  ${FILE_ICON}  ipq-wifi Makefile: 注册板级固件包 ipq-wifi-cuicanmx_salvage-1"
echo -e "  ${FILE_ICON}  DTS 文件         : ipq8072-salvage-1.dts (455 行)"
echo -e "  ${FILE_ICON}  ipq807x.mk       : 生成 FIT/Ubi 映像，启用 NAND 升级"
echo -e "  ${FILE_ICON}  02_network       : 设定 lan wan 接口 (eth0~eth3)"
echo -e "  ${FILE_ICON}  11-ath11k-caldata: 从 0:ART 分区 0x20000 偏移提取校准数据"
echo -e "  ${FILE_ICON}  platform.sh      : 支持 sysupgrade (nand_do_upgrade)"
echo ""
echo -e "${YELLOW}  ${WARN} 若二进制文件缺失，编译 ipq-wifi-cuicanmx_salvage-1 包时将失败。${NC}"
echo -e "${GREEN}  现在可以运行 make menuconfig 并选择 Target Profile = CUICANMX Salvage-1${NC}"
echo ""
