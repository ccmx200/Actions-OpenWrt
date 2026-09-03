# Salvage-1 OpenWrt 固件 

**硬件平台：IPQ8072a（三木爱折腾） | 自适配设备(注意建议去看这个自己编译，云编译的固件可能有问题，https://github.com/ccmx200/openwrt-6.x) | QCA8075 + QCA8081**

---

## 当前状态

| 组件 | 状态 |
|---|---|
| NAND 全盘 256 MiB rootfs（UBI） | 正常挂载 |
| eMMC HS400（3.59 GiB） | 已识别，可按需格式化挂载 |
| 运行内存 | 1 GB |
| Wi-Fi | 正常工作（依赖 ART 分区） |
| 有线网络（lan1–lan3 + wan 2.5G，NSS 加速） | 正常 |
| USB 3.0 | 正常 |
| SD 卡槽 | 正常 |

**已知限制：**

- M.2 接口暂无法驱动，需通过 USB 转接板使用。
- 网口 MAC 地址需自行固化。
- QModem 不再内置于当前构建中，如有需要请自行安装。

---

## 快速安装

### 准备工作

- 在电脑上安装 TFTP 服务器（如 `tftpd64`）。
- 将固件文件 `libwrt-qualcommax-ipq807x-cuicanmx_salvage-1-squashfs-factory.ubi` 放入 TFTP 根目录。
- 使用 console 线连接路由器（靠近电源的网口）。
- 将电脑 IP 设为 `192.168.1.200`，网线接入路由器 LAN 口。

### 写入固件（U-Boot 环境）

> **请务必提前备份所有 mtd 分区，再执行下述操作。本仓库及固件不对因使用导致的任何设备损坏承担责任。**

1. 启动路由器，按任意键进入 `IPQ807x#` 提示符。
2. 依次执行以下命令：

```bash
setenv serverip 192.168.1.200
setenv ipaddr 192.168.1.100

# 加载固件到内存（请替换为实际文件名）
tftpboot 0x60000000 openwrt-qualcommax-ipq807x-cuicanmx_salvage-1-squashfs-factory.ubi

# 擦除整个 NAND 并写入（xxxxxx 请替换为 tftpboot 显示的实际对齐大小）
nand erase 0x0 0x10000000
nand write 0x60000000 0x0 0xxxxxx

# 设置环境变量（固定分区，全盘 rootfs）
setenv mtdids 'nand0=nand0'
setenv mtdparts 'mtdparts=nand0:0x10000000@0x0(rootfs)'
setenv bootargs 'console=ttyMSM0,115200n8 ubi.mtd=rootfs root=mtd:ubi_rootfs rootfstype=squashfs rootwait'
setenv bootcmd 'ubi part rootfs; ubi read 0x44000000 kernel; bootm 0x44000000'
saveenv
reset
```

3. 路由器重启后，稍等片刻即可通过 `http://192.168.1.1` 或 SSH 访问（无密码）。

---

## 设备树关键配置

设备树通过 SPI NOR 的 `0:ART` 分区提供 Wi-Fi 校准数据与网口 MAC 地址。NAND 已定义为全盘 `rootfs`，eMMC 控制器已启用 HS400 模式。

---

## 恢复原厂

如需回到原厂系统，请使用备份的原厂分区文件通过 U-Boot 恢复，并还原原始的 U-Boot 环境变量（`mtdparts`、`bootcmd` 等）。

---

## Q&A

**问题：** Wi-Fi 无法启动出现以下日志：

```
[   76.696620] ath11k c000000.wifi: qmi failed to load CAL data file:cal-ahb-c000000.wifi.bin
[   76.696713] ath11k c000000.wifi: failed to load board data file: -12
```

**解决：** 执行以下命令：

```bash
dd if=/dev/mtd18 of=/lib/firmware/ath11k/IPQ8074/hw2.0/cal-ahb-c000000.wifi.bin bs=1 skip=131072 count=131072
```

---

## 贡献与反馈

- 硬件适配：cuicanmx
- 项目地址：[ActionsOP](https://github.com/ccmx200/Actions-OpenWrt)
- 问题反馈：提交 Issue 或邮件联系

---

> **⚠️ 重要提示**
>
> 本固件为个人自用适配版本。刷机前请务必备份原厂分区。
>
> 固件通过 GitHub Actions 自动编译，未植入任何危害信息安全的后门、脚本或恶意程序。若对已发布固件的安全性存有疑虑，请自行查阅源码并编译使用。
>
> 本仓库仅为个人自用编译，`.config` 中集成了社区呼声较高的常见插件。若对固件有任何不满，请勿无端指责或散播未经证实的言论。
