# Salvage-1 OpenWrt 固件

**Netgear WAX218 (IPQ8074) | 自适配设备 | QCA8075 + QCA8081**

---

## 当前状态

- ✅ NAND 全盘 256 MiB rootfs，UBI 挂载正常
- ✅ eMMC HS400 模式已识别 (3.59 GiB)，可按需格式化挂载
- ✅ Wi‑Fi 已正常工作（ath11k，原厂 ART 校准数据）
- ✅ 有线网络正常（lan1‑lan3 + wan 2.5G，NSS 加速）
- ✅ USB 3.0 正常
- ✅ 所有网口自动从 ART 分区获取 MAC 地址

---

## 快速安装

### 准备工作
- 电脑安装 TFTP 服务器（如 `tftpd64`）
- 将固件文件 `libwrt-qualcommax-ipq807x-cuicanmx_salvage-1-squashfs-factory.ubi` 放入 TFTP 目录
- console线连接路由器（`靠近电源的那个网口`）
- 电脑 IP 设为 `192.168.1.200`，网线接路由器 LAN 口

### 写入固件（U‑Boot 环境）
1. 启动路由器，按任意键进入 `IPQ807x#` 提示符。
2. 依次执行以下命令：

```bash
setenv serverip 192.168.1.200
setenv ipaddr 192.168.1.100

# 加载固件到内存 (替换为实际文件名)
tftpboot 0x60000000 openwrt-qualcommax-ipq807x-cuicanmx_salvage-1-squashfs-factory.ubi

# 擦除整个 NAND 并写入 (注意：必须用实际传输大小，对齐到 0x800)
nand erase 0x0 0x10000000
nand write 0x60000000 0x0 xxxxx   # 替换为 tftpboot 后显示的实际对齐大小

# 设置环境变量 (固定分区，全盘 rootfs)
setenv mtdids 'nand0=nand0'
setenv mtdparts 'mtdparts=nand0:0x10000000@0x0(rootfs)'
setenv bootargs 'console=ttyMSM0,115200n8 ubi.mtd=rootfs root=mtd:ubi_rootfs rootfstype=squashfs rootwait'
setenv bootcmd 'ubi part rootfs; ubi read 0x44000000 kernel; bootm 0x44000000'
saveenv

reset
```

3. 路由器重启后，稍等片刻即可通过 `http://192.168.1.1` 或 SSH 访问（无密码）。

## 设备树关键配置

设备树中已通过 SPI NOR 的 `0:ART` 分区提供 Wi‑Fi 校准数据和网口 MAC 地址：
同时，NAND 已定义为全盘 `rootfs`，eMMC 控制器已启用 HS400 模式。

---

## 恢复原厂

若想回到原厂系统，请用备份的原厂分区文件通过 U‑Boot 恢复，并恢复原始 U‑Boot 环境变量（`mtdparts`、`bootcmd` 等）。
---

## 贡献与反馈

- 硬件适配：cuicanmx
- 项目地址：[ActionsOP](https://github.com/ccmx200/Actions-OpenWrt)
- 问题反馈：提交 Issue 或邮件联系

---

**注意**：本固件为自用适配版，使用前请做好原厂分区备份。固件持续完善中，欢迎反馈使用问题。
