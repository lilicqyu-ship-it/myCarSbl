#ifndef MW_APP_VERSION_H
#define MW_APP_VERSION_H

/*
 * SBL 固件版本（SemVer）—— 本工程唯一的版本真源。
 *
 * 发布流程：bump 三个数字 -> 提交 -> 打同名 git tag（如 v0.1.0）。
 * SBL 无 UART 输出，版本经产物可见：
 *   - SCons 产物名自动携带版本（build 各配置目录下 tc275_sbl_vX.Y.Z.elf 与 .hex）；
 *   - 产物内可检索：strings tc275_sbl_vX.Y.Z.elf | grep SBLFW（调试器亦可读）。
 */

#define APP_VERSION_MAJOR 0
#define APP_VERSION_MINOR 1
#define APP_VERSION_PATCH 0
#define APP_VERSION_STRING "0.1.0"

/* 魔术前缀 "SBLFW" 使版本串在 elf/hex 里可直接检索 */
extern const char g_sbl_version[];

#endif
