# 书源规则数据致谢与许可说明

`sources.json` 中的 25 个书源规则**派生自开源项目 [so-novel](https://github.com/pcdd/sonovel)**（© pcdd，[AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html)）。

- 原项目：通用小说搜索下载器（Java），规则文件位于其 `bundle/rules/*.json`。
- 本文件：规则的**数据**移植——选择器/限流/过滤参数保持原义，原 `@js:`/`@java:`
  短脚本改写为漫读引擎的 `@op:` 具名算子（引擎为独立 Dart 实现，见
  `app/lib/features/source/`）。
- 每个源保留原 `comment` 备注（限流/维护状态等）。

## 来源对照

| group（本文件） | so-novel 原文件 | 源 |
|---|---|---|
| main | `bundle/rules/main.json` | 香书小说/书海阁/梦书中文/鸟书网/笔趣阁22/笔尖中文/悠久小说网/阅读库/顶点小说/笔趣阁365/燃文小说网 |
| proxy-required | `bundle/rules/proxy-required.json` | 69书吧/全本小说网/大熊猫文学/101看书 |
| rate-limit | `bundle/rules/rate-limit.json` | 新天禧小说/零点小说/老幺小说网/速读谷 |
| no-search | `bundle/rules/no-search.json` | 小说虎/天天看小说/小说之家 |
| cloudflare | `bundle/rules/cloudflare.json` | 黄易天地/96读书/东滩小说（默认禁用：CF 人机验证风险） |

转换工具：`tools/convert_rules.py`（一次性脚本，规则升级时重跑并核对差异）。
转换日期：2026-10-04。

## 用户导入的书源

App 内「源管理」可导入自定义 JSON（与 `sources.json` 单条同构），用户源与本文件
无关，其权利义务由导入者自负。请勿导入来源不明、包含可执行脚本书源。
