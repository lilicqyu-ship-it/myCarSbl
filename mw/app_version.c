#include "mw/app_version.h"

/* 调试器/产物检索用："SBLFW tc275_sbl v0.1.0"。SBL 没有运行时输出，
 * Cpu0_Main 里的 volatile 读锚点保证链接期死码消除（-Wl-Oc）不会剔除它。 */
const char g_sbl_version[] = "SBLFW tc275_sbl v" APP_VERSION_STRING;
