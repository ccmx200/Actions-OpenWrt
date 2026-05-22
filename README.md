# Salvage-1 OpenWrt 固件

**咸鱼 BIG 板 | 自适配设备 | IPQ8072A (Hawkeye) | QCA8075 + QCA8081**

---

## 当前状态
- ✅ 有线网络 NSS正常运转 内网测试100MB/s左右CPU占用为0 (eth0‑3 / lan1‑3 + wan 2.5G)  
- ✅ 基础系统稳定运行
- ✅ USB3.0 正常运转
- ❌ WiFi 暂不可用（校准数据适配中）  
- ❌ eMMC 暂未挂载（设备树已就绪，内核支持待验证）

---

## 快速安装

### 准备工作
- 电脑安装 TFTP 服务器（如 `tftpd64`）
- 将以下文件放入 TFTP 目录：
  - `openwrt-qualcommax-ipq807x-cuicanmx_salvage-1-squashfs-factory.ubi`
- USB‑TTL 串口连接路由器（`115200 8N1`）
- 电脑 IP 设为 `192.168.1.200`，网线接路由器 LAN 口

### 写入固件（U‑Boot 环境）
1. 启动路由器，按任意键进入 `IPQ807x#` 提示符。
2. 依次执行以下命令：

```bash
setenv serverip 192.168.1.200
setenv ipaddr 192.168.1.100

# 设置与设备树一致的分区表（固定分区，超大 rootfs）
setenv mtdparts 'mtdparts=nand0:0x50000@0x0(0:SBL1),0x10000@0x50000(0:MIBIB),0x20000@0x60000(0:BOOTCONFIG),0x20000@0x80000(0:BOOTCONFIG1),0x180000@0xa0000(0:QSEE),0x180000@0x220000(0:QSEE_1),0x10000@0x3a0000(0:DEVCFG),0x10000@0x3b0000(0:DEVCFG_1),0x10000@0x3c0000(0:APDP),0x10000@0x3d0000(0:APDP_1),0x40000@0x3e0000(0:RPM),0x40000@0x420000(0:RPM_1),0x10000@0x460000(0:CDT),0x10000@0x470000(0:CDT_1),0x10000@0x480000(0:APPSBLENV),0xa0000@0x490000(0:APPSBL),0xa0000@0x530000(0:APPSBL_1),0x40000@0x5d0000(0:ART),0x80000@0x610000(0:ETHPHYFW),0xf970000@0x690000(rootfs)'
setenv bootcmd 'ubi part rootfs; ubi read 0x44000000 kernel; bootm 0x44000000'
setenv bootargs 'console=ttyMSM0,115200n8 ubi.mtd=rootfs root=mtd:ubi_rootfs rootfstype=squashfs rootwait'
saveenv

# 刷写固件
tftpboot 0x60000000 openwrt-qualcommax-ipq807x-cuicanmx_salvage-1-squashfs-factory.ubi
nand erase 0x690000 0x0f970000
nand write 0x60000000 0x690000 ${filesize}
reset
```

3. 路由器重启后，稍等片刻即可通过 `http://192.168.1.1` 或 SSH 访问（无密码）。

---

## 云编译（自用）
本项目基于 OpenWrt 主线 + 自定义 DTS，使用 GitHub Actions 自动构建。  
主要修改文件：
- `target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq8072-salvage-1.dts`
- `target/linux/qualcommmax/image/ipq807x.mk`
- `package/firmware/ipq-wifi/Makefile` 及对应的 `board-cuicanmx_salvage-1.ipq8074`

如需自行编译，请将上述文件放入对应位置，然后执行：
```bash
make menuconfig   # 选中 Target Profile: CUICANMX Salvage-1
make -j$(nproc)
```

---

## 恢复原厂
若想回到原厂系统，请用备份的 `mtd19_rootfs.bin` 等文件覆盖，并恢复原始 U‑Boot 环境变量。详见备份时的文档。

---

## 贡献与反馈
- 硬件适配：cuicanmx  
- 项目地址：[ActionsOP](https://github.com/ccmx200/Actions-OpenWrt)
- 问题反馈：提交 Issue 或邮件联系

---

**注意**：本固件目前为自用测试版，WiFi 和 eMMC 功能仍在完善中。刷机前请做好原厂分区备份！
