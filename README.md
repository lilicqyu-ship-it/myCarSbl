# myCarSbl — TC275 OTA 二级引导（SBL）工程

智能车 TC275 主控的 OTA 升级引导程序：上电由 SBL 接管 reset 向量，读取
DFlash 中的 OTA 元数据，决定跳入 PFlash 双 bank（Slot A / Slot B）中的哪个
App 镜像，并在升级失败时自动回滚，保证车辆不变砖。

对应设计方案见 [doc/24-ota-sbl-dualbank.md](doc/24-ota-sbl-dualbank.md)
（双 bank 分区、OtaMeta 双页元数据、SBL/App 状态机、"TCFW" 固件包格式）。

## 当前状态

工程骨架（AURIX Development Studio + TASKING）：三核入口 `Cpu0/1/2_Main.c`
仍为模板代码，SBL 引导逻辑与双 bank linker（`Lcf_SBL.lsl` / `Lcf_AppA.lsl` /
`Lcf_AppB.lsl`）按设计文档 P3 阶段逐步落地。

## 目录结构

| 路径 | 说明 |
|---|---|
| `Cpu0/1/2_Main.c` | 三核入口（后续改为 SBL 引导跳入） |
| `Lcf_Tasking_Tricore_Tc.lsl` | TASKING linker 命令文件（现单 bank 布局） |
| `Libraries/` | Infineon iLLD / Infra / Service 驱动库（TC27D） |
| `Configurations/` | `Ifx_Cfg.h` 等芯片配置 |
| `doc/` | 设计文档 |
| `.cproject` / `.project` / `.settings/` | AURIX Development Studio 工程配置 |

## 开发环境

- AURIX Development Studio 1.10.36（内含 TASKING TriCore 编译器）
- 目标芯片：Infineon AURIX TC275（三核 200 MHz，2×2 MB PFlash 双 bank）

## 构建

导入 AURIX Development Studio 后直接 build 即可，产物（`.elf/.hex/.map`）
生成于 `Debug/`（已 gitignore）。
