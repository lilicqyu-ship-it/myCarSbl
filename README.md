# myCarSbl — TC275 OTA 二级引导（SBL）工程

智能车 TC275 主控的 OTA 升级引导程序：上电由 SBL 接管 reset 向量，读取
DFlash 中的 OTA 元数据，决定跳入 PFlash 双 bank（Slot A / Slot B）中的哪个
App 镜像，并在升级失败时自动回滚，保证车辆不变砖。

设计方案见 [doc/24-ota-sbl-dualbank.md](doc/24-ota-sbl-dualbank.md)
（双 bank 分区、OtaMeta 双页元数据、SBL/App 状态机、"TCFW" 固件包格式）。

## 当前状态

**软件层已实现，未上板**（2026-09-30）：

- ✅ host 单测 282 断言全绿（验收门 G-OTA-1/2）：TCFW 验签器、SF OTA 帧布局
  （与 C6 逐字节一致）、ota_rx 接收状态机（12 场景）、OtaMeta 双页掉电恢复、
  §5.1 回滚决策梯度
- ✅ SBL 经 TASKING 命令行编译链接验证：11.2 KB 代码，落在 32 KB SBL 区域
  内，入口 0x80000020（用本机完整版 TASKING v6.3r1 验证；正式产物请从 ADS 构建）
- ✅ 三个 linker 文件冒烟链接通过：AppA `.start`@0x80008020、
  AppB `.start`@0x80208020（槽基址+0x20 入口约定）
- ⬜ 上板项 G-OTA-3/4/5/6：ADS 构建烧录、SBL→App 跳转小样、写 B 换槽回滚、
  传输中断/验签失败/自检失败三种回滚路径、掉电恢复
- ⬜ myCar（App 工程）接入：`OtaRxOps` 五类回调 + `OTABOOT_confirmSelftest`
  自检确认 + `Lcf_AppA/AppB.lsl` 切换构建

## 目录结构

| 路径 | 说明 |
|---|---|
| `Cpu0_Main.c` | SBL 入口（watchdog 处理后进 `SBL_boot()`，不返回） |
| `sbl/sbl_boot.[ch]` | §5.1 引导决策落地：元数据加载→决策→LED 信号→跳槽/安全态 |
| `bsp/flash_ota.[ch]` | IfxFlash 封装：槽扇区擦除、32B 页 staging 写、DFlash 元数据后端、入口探测 |
| `mw/ota/` | 可移植 OTA 栈（纯 C99，host/TriCore 同源编译）：`ota_layout.h` 地址真源、`ota_meta` 双页、`ota_boot` 决策、`tcfw_bundle` 验签、`ota_rx` 接收状态机、`crc32`、`ota_keys.h` 公钥 |
| `mw/crypto/` | `ed25519v`/`sha512`/`c6_consts` — 自 c6_car 逐字拷贝（验签与 C6 共用真源） |
| `mw/sf/sf_frame.h` | SF 帧编码头 — 自 myCar 逐字拷贝（线格式真源） |
| `test/host/sf_frame.c` | SF 帧编解码实现 — 同样逐字拷贝；只由 host 测试编译（myCar 有自己的正本，SBL 镜像不引用） |
| `Lcf_SBL.lsl` | **本工程构建用**：SBL 定位 32 KB（0x80000000..0x80007FFF） |
| `Lcf_AppA.lsl` / `Lcf_AppB.lsl` | App 槽 linker（给 myCar 工程切换构建；App 不占物理 reset） |
| `test/host/` | host 单测 + mock 后端 + `make check` |
| `tools/` | `gen_test_vectors.py`（TCFW 测试向量）、`build_sbl.sh`（命令行编译验证） |
| `Cpu1/2_Main.c`、`Blinky_LED.c` | 模板遗留（Cpu1/2 不被 SBL 启动，仅为链接完整保留） |
| `Libraries/`、`Configurations/` | Infineon iLLD（TC27D）与芯片配置 |
| `doc/` | 设计文档 |

## 分区与地址（mw/ota/ota_layout.h 为真源）

| 区域 | 范围（cached） | 大小 | 说明 |
|---|---|---|---|
| SBL | 0x80000000..0x80007FFF | 32 KB | 持有 reset 向量，永不参与 OTA |
| Slot A | 0x80008000..0x801FFFFF | 2040 KB | PF0 S2..S26，出厂镜像 |
| Slot B | 0x80208000..0x803FFFFF | 2040 KB | PF1 S2..S26，OTA 目标槽（镜像对称） |
| OtaMeta | DFlash0 0xAF01A000 / 0xAF01C000 | 2×8 KB | 双页提交；扇区 15 归 myCar calib |

槽入口 = 槽基址 + 0x20（App 的 `.start` 段，镜像 BMHD 约定），SBL 跳该地址。

## 构建

**ADS（正式）**：导入本工程直接 build —— `.cproject` 已指向 `Lcf_SBL.lsl`，
新目录（`sbl/ bsp/ mw/`）会自动纳入构建；`test/ tools/ doc/` 已从目标构建排除。
编译器 include 路径的第一项是工程根 `${ProjDirPath}`（`mw/...`、`bsp/...`
这类仓库根相对包含依赖它——若 IDE 里工程是改 `.cproject` 前导入的，确认
Project Properties → C/C++ Build → Compiler → Include paths 里能看到该条）。

**命令行（验证用）**：`sh tools/build_sbl.sh`（用本机完整版 TASKING v6.3r1；
ADS 内置版许可禁止 IDE 外运行）。脚本自带完整源集（含 iLLD 子集，从
`.cproject` 排除表解析），Clean 后也能独立出产物。产物在 `Debug/`（已
gitignore）。

**host 单测**：

```sh
cd test/host
make check        # CC 默认 C:/msys64/ucrt64/bin/gcc，可 CC=gcc 覆盖
```

测试向量由 `python tools/gen_test_vectors.py` 生成（依赖 c6_car 的
ed25519 参考实现与 dev 密钥；`test_vectors.h` 已提交，格式或密钥变更时重生成）。

## 首次上板步骤（G-OTA-3 起）

1. ADS 构建 SBL → 烧 `Debug/myCarSbl.hex`（含 BMHD0，reset 有效）
2. 调试器把 AppA 版 App（myCar + `Lcf_AppA.lsl`）镜像写入 0x80008000 区
3. 上电：无元数据时 SBL 探测 Slot A 入口非擦除态 → 闪 1 下 → 跳 A
   （`SBL_ALLOW_FIRST_BOOT`，首次 OTA 后即由元数据接管）
4. App 内接入 `OTARX_init` + 自检 `OTABOOT_confirmSelftest`，C6 推 TCFW 走 §5.3
5. 验证 SWAP → 重启进 B → 自检 VALID；断电/坏包/不自检三种回滚路径

## 开发环境

- AURIX Development Studio 1.10.36+（内含 TASKING；本机另有完整版 v6.3r1 用于命令行验证）
- 目标芯片：Infineon AURIX TC275（TC27xTP D-Step，三核 200 MHz，2×2 MB PFlash 双 bank）
- host 测试：MSYS2 ucrt64 gcc（或任意 C99 编译器）+ Python 3
