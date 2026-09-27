# 漫读 · 漫画小说资源管理应用 设计文档

> 单人自用 / 无服务端 / S3 兼容桶直连 / Android + 桌面端
> 定稿日期：2026-09-28
> 修订记录：2026-09-28 初稿完善（技术选型落地、合并语义明确化、测试策略、错误处理一致性、仓库布局）

---

## 1. 定位与原则

| 原则 | 说明 |
|---|---|
| 无服务端 | App 经 SigV4 直连私有桶；凭证存 Android Keystore 加密 + 应用 PIN 锁 |
| 桶即真相 | 漫画 AVIF、小说 epub+txt+meta、全局索引、用户状态事件全部落桶 |
| 本地优先检索 | `_index` 增量同步到本地 SQLite FTS5，搜索永不打桶 |
| 本地优先阅读 | 图片/文本 LRU 缓存；追更的小说先落本地，**是否上传归档由用户决定** |
| 复用资产 | AVIF 管线、整理工具与 gameColl 游戏库项目共用一套思路（其 `imaging.rs` 转码管线为参照实现） |

## 2. 总体架构

```
┌─────────────────────────────────────────────────────────┐
│ Flutter App（Android / Windows / Linux 同一套代码）         │
│  ├─ UI：书架 / 搜索 / 阅读器(漫画/小说) / 收藏夹 / 设置      │
│  ├─ 本地层                                                  │
│  │   ├─ drift (SQLite)：元数据缓存、收藏夹、标签、进度、书签   │
│  │   │                   FTS5 trigram 检索                  │
│  │   ├─ LRU 缓存：图片 2GB(手机)/10GB(桌面)，文本整本缓存     │
│  │   └─ Keystore：桶凭证加密存储                             │
│  ├─ 源引擎：JSON 书源解析器（搜索/目录/正文/翻页规则）          │
│  └─ BucketClient：基于 minio 包的 SigV4 直连               │
│                    OSS / COS / R2 / MinIO                  │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTPS + SigV4
┌──────────────────────────▼──────────────────────────────┐
│ 私有桶 library/                                           │
│  ├─ _index/works.jsonl      书架级索引（增量同步）           │
│  ├─ _state/events.jsonl     用户状态事件日志（追加式）        │
│  ├─ _fonts/*.ttf|otf        自定义字体                     │
│  ├─ <漫画> 作者/系列/卷/001.avif …                        │
│  └─ <小说> 作者/系列/书名/{book.epub, book.txt,            │
│                            cover.avif, meta.json}          │
└──────────────────────────────────────────────────────────┘
┌──────────────────────────┐
│ 桌面整理工具（可选，本地跑）  │  扫 inbox/ → AVIF 转码 / 小说清洗
│                              → 归档 library/ → 刷新 _index
└──────────────────────────┘
```

### 2.1 技术选型（已落地）

| 关注点 | 选型 | 备注 |
|---|---|---|
| 状态管理 | `flutter_riverpod` | 不引入 codegen，provider 手写 |
| 路由 | `go_router` | 声明式，深浅路由都够用 |
| 本地库 | `drift` + `sqlite3_flutter_libs` | FTS5 trigram 需 SQLite ≥ 3.34，flutter_libs 满足 |
| S3 客户端 | `minio` pub 包（v3.5.8，2025-08 仍在维护） | 外层自封装 `BucketClient`，便于换实现 |
| 密钥存储 | `flutter_secure_storage` | Android Keystore / Windows DPAPI |
| 加密 | `crypto` | PBKDF2 派生 + AES-256-GCM 信封加密 |
| 书源网络 | `http` | M5 源引擎用；minio 内部自带请求层 |
| 代码生成 | `build_runner` + `drift_dev` | 生成物 `*.g.dart` 提交入库 |

### 2.2 仓库布局

```
comics&book/
  app/                  # Flutter 工程（根目录名含 &，工程放子目录规避工具链坑）
    lib/{core,data,features}/
    test/
  docs/design.md        # 本文档
  tools/                # 桌面整理工具（后期，扫 inbox → 转码 → 归档 → 刷索引）
  README.md / AGENTS.md
```

## 3. 存储桶目录结构

```
library/
  _index/
    works.jsonl                 # 每行一本：检索与列表用
  _state/
    events.jsonl                # 追加式事件：进度/书签，只增不改
  _fonts/
    LXGW-Bold.ttf               # 用户上传的字体，跨设备自动同步
  漫画/
    山田太郎/奇幻系列/v01/001.avif …
  小说/
    佚名/散落短篇/书名/
      book.epub                 # 归档原件（可选，见 §8）
      book.txt                  # 规范化全文 UTF-8（桶内唯一文本真相）
      cover.avif
      meta.json
```

**单写入者约定**：`_index/works.jsonl` 只有「桌面整理工具」和「上传归档」流程写；App 端只追加 `_state/events.jsonl`。App 不直接改索引，避免多设备写冲突。

## 4. 元数据 Schema

### 4.1 works.jsonl（书架索引行）

```json
{
  "id": "novel_123",
  "type": "novel",                    // novel | manga
  "title": "书名", "title_jp": "",
  "author": "作者", "series": "系列", "volume": 3,
  "tags": ["奇幻", "慢热"],
  "status": "ongoing",                // ongoing | completed | hiatus
  "total_chars": 2350000,
  "pages": null,                      // 漫画用
  "last_updated": "2026-09-27",
  "cover": "小说/…/cover.avif",
  "origin": "manual",                 // manual 手动上传 | source:<源ID> 源下载
  "local_only": false                 // true = 只存在于本设备（见 §8.3）
}
```

### 4.2 小说 meta.json

```json
{
  "id": "novel_123",
  "title": "…", "author": "…", "series": "…",
  "status": "ongoing",
  "total_chars": 2350000,
  "last_updated": "2026-09-27",
  "source": { "source_id": "sxj", "book_url": "https://…", "last_synced_chapter": 210 },
  "volumes": [
    { "v": 1, "title": "第一卷 …",
      "chapters": [ { "i": 0, "title": "序章", "offset": 0, "chars": 3000 } ] }
  ],
  "tags": ["…"]
}
```

`volumes[]` 支持一卷多章、一卷单章（单卷书就是 v:1 下平铺所有章）；offset 全本连续，进度定位 O(1)。

### 4.3 漫画 meta.json

```json
{
  "id": "manga_456", "type": "manga",
  "title": "…", "author": "…", "series": "…", "volume": 1,
  "pages": 42, "status": "completed",
  "cover": "001.avif", "last_updated": "2026-09-27"
}
```

## 5. 用户状态：events.jsonl 追加日志

每行一事件，多设备各自追加、启动时重放合并，天然无写冲突：

```jsonl
{"ts":"…","dev":"phone","type":"novel_progress","work":"novel_123","loc":{"vol":2,"ch":101,"offset":984500}}
{"ts":"…","dev":"pc","type":"manga_progress","work":"manga_456","loc":{"page":12}}
{"ts":"…","dev":"pc","type":"bookmark","id":"bm_9f3…","work":"manga_456","loc":{"page":12},"note":"","color":"red"}
{"ts":"…","dev":"pc","type":"bookmark","id":"bm_a21…","work":"novel_123","loc":{"vol":1,"ch":3,"offset":15200},"note":"设定关键点","color":"yellow"}
{"ts":"…","dev":"phone","type":"bookmark_delete","id":"bm_9f3…"}
```

- **小说书签**：一本书任意多条，含备注、颜色、创建时间；坐标 = 卷+章+字符偏移（与字体字号解耦，换设备换字体不漂移）。
- **漫画书签**：坐标 = 页码；漫画目录页同样提供书签列表，点击直达对应页。
- 保险：桶开 Versioning + 上传带 Content-MD5；重放时跳过坏行。

### 5.1 合并语义（明确化）

重放结果必须满足确定性——同一份事件日志在任何设备上重放得到同一状态：

| 事件类型 | 合并规则 |
|---|---|
| `novel_progress` / `manga_progress` | 按 `work` 维度取 `ts` 最新一条作为当前进度；`ts` 相同按 `(dev, type)` 字典序决胜 |
| `bookmark` | 按 `id` 插入；同 `id` 后写覆盖（`ts` 更新者） |
| `bookmark_delete` | 按 `id` 删除 |
| 设置同步项 | 按 `key` LWW（`ts` 新者胜） |

**30 天折叠**：后台任务把 30 天前的同 `work` 进度事件折叠成一行快照
`{"type":"snapshot","ts":…,"work":…,"loc":{…},"folded_from":N}`；
被折叠的旧事件保留在桶内（Versioning 兜底，不再参与重放）。书签永不折叠。

**schema_version**：每行事件带 `schema_version`（当前 1），未来迁移时按版本分支处理。

### 5.2 错误处理与一致性

- 统一异常层级：`StorageException` → `BucketConfigException` / `ConnectionException` / `ObjectNotFoundException` / `ChecksumMismatchException` / `RetryExhaustedException`。
- **S3 写路径**（索引、meta、归档）：PUT tmp key（带 Content-MD5）→ HEAD 校验 → COPY 到正式 key → DELETE tmp。任何一步失败不留下半成品正式 key。
- **读路径**：指数退避重试 3 次（基数 500ms，抖动 ±20%）；仍失败抛 `RetryExhaustedException`。
- **jsonl 解析**：逐行 `tryParse`，坏行跳过并记录行号 + 前 120 字符到日志；解析器本身无副作用、纯函数，可直接单测。

## 6. 漫画阅读器

### 6.1 阅读模式

| 模式 | 实现 |
|---|---|
| 竖向滚动 | 原图按 1024px 切片建索引，虚拟化渲染仅解码视口±2屏 |
| 横翻书页 | PageView + 左右各预载 1 页；双页对开模式自动识别跨页横图 |
| 缩放 | **自建 InteractiveViewer 缩放层**（photo_view 官方已停止维护，不再依赖；M3 spike 验证捏合跟手度，必要时评估 fork） |

### 6.2 自动翻页（可设置时间）

- 设置项：**翻页间隔 1–60 秒滑杆（默认 5s）**，步进 0.5s；速度独立记忆：
  - 全局默认值（设置页）
  - 单部作品记忆（进入阅读器自动恢复上次该作品的间隔）
- 行为：定时器触发翻页；滑动/缩放/长按暂停自动翻页，停止操作 3s 后恢复；
- 漫画式滚动模式（竖向）下自动翻页 = 匀速滚动，速度换算为 px/s。

### 6.3 漫画书签

- 阅读器内「加书签」按钮记录当前页（页码+缩略图快照）。
- 目录面板分「书签」页签：列表显示页码缩略图/备注/时间，点击跳转、长按删除。
- 进度同样记 `manga_progress`，关闭应用自动保存。

## 7. 小说阅读器

### 7.1 护眼模式

内置四套预设 + 完全自定义：

| 预设 | 背景 | 文字 | 适用 |
|---|---|---|---|
| 白昼 | #FFFFFF | #1A1A1A | 默认 |
| 护眼绿 | #C7EDCC | #3A4A3C | 长时间阅读 |
| 羊皮纸 | #F5F0E1 | #4A4234 | 夜间前过渡 |
| 夜间 | #111318 | #B8BDC7 | 黑暗环境 |

- 自定义：背景色/文字色/强调色任取（色盘），另支持**图片背景**（淡雅纸张纹理）。
- **定时切换**：跟随系统深色模式，或按时间段自动切换预设（如 20:00–07:00 切夜间）。
- 亮度：独立阅读亮度滑杆（不修改系统亮度）。

### 7.2 字体与排版

- **字体**：内置 3 款开源字体——思源宋体、思源黑体、霞鹜文楷（均为 SIL OFL 1.1 许可，可合法随包分发）；用户可导入 TTF/OTF：
  - 本地导入（App 内文件选择）
  - 上传至 `library/_fonts/`（跨设备自动同步，桶内唯一字体库）
- 排版项：字号（12–32px）、行距（1.2–2.0）、段距、边距、首行缩进开关、两端对齐/左对齐、字间距。
- 全部排版项 per-书可覆盖全局默认。

### 7.3 翻页方式

仿真翻页（覆盖）/ 左右平移 / 上下滚动 三种，进度坐标均为字符 offset，切换翻页方式不丢进度。

## 8. 小说源系统（导入书源 + 下载 + 上传决策）

### 8.1 书源格式

兼容「阅读/legado」风格的 JSON 规则源，App 内置 Dart 规则引擎：

```json
{
  "id": "sxj", "name": "示例小说网", "enabled": true,
  "base_url": "https://example.com",
  "search": {
    "url": "/search?q={{key}}",
    "list": "$.data[]", "name": "$.title", "author": "$.author",
    "book_url": "$.url"
  },
  "toc": {
    "url": "{{book_url}}",
    "list": "class.chapter@tag.a", "title": "text", "chapter_url": "href"
  },
  "content": {
    "url": "{{chapter_url}}",
    "text": "id.content@html",
    "next_page": "class.next@href"
  },
  "headers": { "User-Agent": "…" },
  "charset": "utf-8"
}
```

- 支持 JSONPath + CSS 选择器两套规则（与 legado 语法子集兼容，可直接导入社区书源）。
- 源管理：导入 JSON / 导出 / 启停 / 单源测试（试搜一本书验证规则有效性）/ 失败自动禁用并提示。

### 8.2 下载流程

```
搜索（多源聚合，标注来源） → 书籍详情（作者/简介/最新章/状态）
  → 选择章节范围（最新50章 / 全本 / 自选区间）
  → 并发抓取正文（限速，2~4 线程，失败章节重试3次后可手动补）
  → 清洗：去广告行 / 统一空白 / 编码归一 UTF-8 / 章节正则识别
  → 生成 book.txt + meta.json（含 source 回溯信息）
  → 落本地 local_works/<id>/（默认，见 §8.3）
```

### 8.3 上传决策（用户自己决定）

| 选择 | 行为 |
|---|---|
| **仅本设备**（默认） | 存 App 私有目录 `local_works/<id>/{book.txt, meta.json, cover.avif}` + 本地 SQLite，`local_only: true`，不进桶；换设备/清缓存即丢失 |
| **上传归档** | 打包（可选附带 epub）上传 `library/小说/…/`，由「上传归档」流程写 works.jsonl，`origin: "source:sxj"`，全设备可见；上传成功后本地 local_works 副本可清（保留与否用户定） |
| **以后再说** | 先本地读着，书籍详情页常驻「上传到书架」按钮，一键补传 |

连载书的**追更**：

- 详情页「检查更新」→ 源拉最新目录 → 对比 meta.json 的 `last_synced_chapter` → 增量下载新章 → 追加 book.txt 尾部（offset 续排）→ 刷新字数/更新时间 → 已归档的书自动回传更新（走 §5.2 写路径），未归档的只更本地。
- 可选「Wi-Fi 下自动追更」开关，每天一次。

## 9. 检索

- **书架级**：标题/作者/别名/标签/状态（连载·完结）/类型，本地 FTS5（trigram）毫秒级。
  - 虚表：`works_fts USING fts5(title, title_jp, author, series, tags, tokenize='trigram')`，与 `works` 表外键关联，增删改时同步维护。
  - trigram 对中文按 UTF-8 三字节滑窗，1 个汉字即可匹配；SQLite ≥ 3.34 支持。
- **书内搜索**：选中书后对本地 txt 内存子串扫描（百万字几十毫秒），高亮结果列表点击跳转。
- **组合示例**：`type:novel + status:ongoing + tag:奇幻 + 作者:xx`（语法糖解析为 FTS 过滤器 + 列过滤的 AND 组合）。

## 10. 设置项汇总（本地 + 可选同步）

本地存 SQLite `settings` 表；标记 ☁ 的项随 events 同步到桶，多设备一致：

| 类别 | 项 |
|---|---|
| 阅读-漫画 | 默认翻页间隔☁、默认模式(横/竖)☁、双页开关☁、背景色 |
| 阅读-小说 | 护眼预设☁、自定义颜色☁、定时切换☁、字体/字号/行距☁、翻页方式☁ |
| 缓存 | 图片上限、文本上限、Wi-Fi 自动追更、缓存整卷默认行为 |
| 账户 | PIN / 生物识别、桶凭证、最小权限提示 |
| 书源 | 源列表、启停状态、并发线程数 |

settings 表结构：`key TEXT PK, value TEXT, scope TEXT('device'|'synced'), updated_at TEXT`。同步项变更时追加一条设置事件到 events.jsonl（§5.1 LWW 合并）。

## 11. 路线图

1. **M1 桶链路** ✅（2026-09-28 骨架完成）：凭证 + PIN、MinIO SDK 连通、_index 增量同步、本地 SQLite。详见下方细化验收。
2. **M2 阅读器骨架**：漫画竖滑（切片虚拟化）+ 小说文本渲染（字号/行距/翻页）。开工前 spike：flutter_avif 解码 10 张实际漫画验证内存/缩放。
3. **M3 漫画完整**：横翻/双页/自动翻页(可调时)/书签/进度。开工前 spike：InteractiveViewer 自建缩放层跟手度。
4. **M4 小说完整**：护眼预设/自定义/定时切换/字体导入(_fonts)/书内搜索。
5. **M5 书源引擎**：规则解析器、源管理、搜索聚合、章节下载清洗。
6. **M6 追更与归档**：增量更新、上传决策流、local_only 管理。
7. **M7 打磨**：FTS 调优、缓存清理策略、Android 打包、桌面端出包。

### M1 细化验收

1. 录入桶配置后 HEAD bucket 成功，可列出 `_index/` 前缀对象，显示往返延迟。
2. works.jsonl 全量拉取解析入库；坏行跳过且计数可见。
3. 二次启动增量同步：水位正确推进，重叠区合并幂等，不产生重复行。
4. PIN 设置/解锁流程闭环；SK 经 PIN 派生密钥 AES-256-GCM 加密落盘，解锁后可解密使用，错误 PIN 解不开。
5. `flutter analyze` 零告警、`flutter test` 全绿。

## 12. 风险与验收

| 风险 | 对策 |
|---|---|
| flutter_avif 解码性能 | M2 首周 spike：10 张实际漫画 AVIF 验证解码/内存/缩放 |
| 漫画缩放方案 | photo_view 已停止维护 → 自建 InteractiveViewer 缩放层，M3 spike 验证，必要时评估维护中的 fork |
| minio Dart 包能力缺口（copyObject / 预签名 GET / 分片） | M1 已验证基础读写；缺口出现时自补轻量 SigV4 请求层（设计已预留 `BucketClient` 封装） |
| 书源规则失效 | 单源测试 + 失败禁用 + 多源冗余搜索 |
| events.jsonl 膨胀 | 进度事件 30 天折叠（§5.1）；Versioning 兜底 |
| 源站反爬 | 内置限速与 UA 轮换；只抓正文不抓整站；失败退手动 |
| 坏行写入 | Content-MD5 + tmp key copy + 重放跳坏行（§5.2） |
| 多设备进度冲突 | LWW 按 ts + 确定性决胜键（§5.1） |

**验收标准**

1. 200 页 AVIF 漫画竖滑 60fps 无 OOM；横翻缩放流畅。
2. 自动翻页间隔 1–60s 可调，单作品记忆，操作自动暂停/恢复。
3. 漫画书签按页记录，目录内可跳转删除。
4. 小说护眼四预设 + 自定义 + 定时切换生效；字体导入后跨设备可用。
5. 导入 legado 书源可搜索、下载、清洗成规范 txt；可整本上传或仅留本地。
6. 连载书增量追更：新章追加不破坏既有 offset 与进度。

## 13. 测试策略

无 CI，本机 `flutter test` 为验收门槛；**纯逻辑必须与 IO 分离**（AGENTS.md 强制约定）。

| 层 | 内容 | 方式 |
|---|---|---|
| 纯函数 | jsonl 解析/坏行跳过、事件重放合并、path_helper 构造↔解析、章节 offset 计算、书源规则引擎 | 普通单测，无 binding |
| drift | works/bookmarks/progress/settings CRUD、FTS5 中文检索、同步水位推进 | 内存库测试 |
| 加密 | PIN 派生/加解密往返、错误 PIN 失败 | 普通单测 |
| S3 封装 | 以 fake 实现顶替 `BucketClient` 接口测同步流程 | 接口注入 |
| UI | 阅读器翻页、书签交互 | widget test（自 M2 起） |
