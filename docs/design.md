# 漫读 · 漫画小说资源管理应用 设计文档

> 单人自用 / 无服务端 / S3 兼容桶直连 / Android + 桌面端
> 定稿日期：2026-09-28
> 修订记录：2026-09-28 初稿完善（技术选型落地、合并语义明确化、测试策略、错误处理一致性、仓库布局）
>           2026-09-30 增补 §14：JM 漫画下载 Dart 原生化、AVIF 压缩两条路径与重试语义
>           2026-10-02 明确 cover 前缀契约（§4.1）与 App 端索引写入范围（§3 单写入者约定的例外）
>           2026-10-02 事件同步落地（§5）、批量上传与任务队列（§8.3）、压缩人工审阅（§14.4）
>           2026-10-03 事件日志折叠落地（§5）；§6/§7/§8.3/§11 标注实现状态
>           2026-10-03 §14.6：JM 下载任务持久化与中断续跑；解码移出主 isolate；设置页目录选择器
>           2026-10-03 M3/M4 完成：双页对开、漫画书签 UI、护眼自定义+定时切换+图片背景、字体导入（_fonts/ 桶同步）、书内搜索（§6/§7/§11 状态刷新；reader_page.dart 拆为 part 文件）
>           2026-10-04 仓库根目录改名 mandu_reader（纯 ASCII，subst Z: workaround 退役；AGENTS/README 同步）
>           2026-10-04 M7 打磨完成：FTS 接通（写洞五处补齐/语法糖/3 字符下限）、启动缓存修剪、清扫去重、release 双端出包（§9/§11 状态刷新）
>           2026-10-04 M6 收尾：源追更不做（用户决策）；清本地入口确认已有；_novel_cache 失效落地（上传即清缓存）
>           2026-10-04 M5 书源引擎落地（so-novel 规则数据 + Dart 重写引擎 + 找书页签 + 源管理 + 巡检 harness，§8/§11 状态刷新；drift v4）
>           2026-10-18 JM 多章节页序、失败页复用与续跑入口修复；本地车号识别；阅读器页码与远页定位调整；补充实现限制和设备验收范围（§6.4、§13.1、§14.6、§14.9）
>           2026-10-20 漫画收藏夹落地（§8.4）：本机多对多归属、单本/批量整理、未归类筛选与 drift v5 迁移；全量 231 项测试通过

---

## 1. 定位与原则

| 原则 | 说明 |
|---|---|
| 无服务端 | App 经 SigV4 直连私有桶；凭证存 Android Keystore 加密 + 应用 PIN 锁 |
| 桶即真相 | 已归档的漫画 AVIF、小说 epub+txt+meta、全局索引和用户状态事件落桶；仅本设备作品及漫画收藏夹保存在本机 |
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
│  ├─ JM 下载器：API 直连 + AES 解密 + 条带还原 + AVIF 压缩      │
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
| 加密 | `crypto` + `encrypt` | 手写 PBKDF2-HMAC-SHA256 派生（RFC 2898，以已知向量单测）+ AES-256-CBC + HMAC-SHA256（Encrypt-then-MAC）。未选 GCM：`encrypt` 包 GCM 输出格式跨版本不稳定，CBC+EtM 语义明确可测 |
| 书源网络 | `http` | M5 源引擎用；minio 内部自带请求层 |
| 代码生成 | `build_runner` + `drift_dev` | 生成物 `*.g.dart` 提交入库 |

### 2.2 仓库布局

```
mandu_reader/         # 2026-10-04 由 comics&book 改名（纯 ASCII，subst Z: 退役）
  app/                  # Flutter 工程
    lib/{core,data,features}/
    test/
  pkgs/mandu_core/      # 纯 Dart 核心：桶契约/索引合并/AVIF 策略/重试/works.jsonl 解析
                        #（App 与 CLI 共用；App 侧原路径已改为 re-export shim，
                        #  改动实现只动 pkgs/，零 hooks 可在裸 Linux 上 dart compile exe）
  tools/compress_worker/ # 压缩 Worker CLI（常驻轮询桶索引，自动把原图转 AVIF，见 §14.5）
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

**例外（2026-10-02 落地实现）**：App 的「上传归档」「删除云端」「压缩云端回写」三处会读-改-写 works.jsonl（过滤旧行 + 追加新行/墓碑行）。单人单设备下与桌面工具并行概率低、且重试安全（对象整写原子）；多设备场景若引入桌面工具写入方，需改为带 generation 头的乐观并发。

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
  "cover": "小说/…/cover.avif",            // 桶内 key：写入方统一带 library/ 前缀（如
                                        // library/小说/…/cover.avif）；不带前缀的历史行
                                        // App 读取侧自动归一，两种形式都合法
  "origin": "manual",                 // manual 手动上传 | source:<源ID> 源下载（JM 为 source:jmcomic）
  "local_only": false,                // true = 只存在于本设备（见 §8.3）
  "has_zh": true,                     // 是否有中文；缺省 true（App 手动添加入口默认有汉化）
  "zh_quality": "medium",             // 汉化质量 high | medium | low，缺省 medium
  "published_at": "2024-03",          // 发布时间，精确到月（YYYY-MM，可给完整日期，解析归一）
  "completed_at": "2026-01"           // 完结时间，精确到月（连载中为 null）
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

**落地状态（2026-10-02）**：App 端已实现事件追加与重放——阅读器退出写 `novel_progress`/`manga_progress`、书签增删写 `bookmark`/`bookmark_delete`（本地 drift 即时落库 + 桶事件尽力追加）；书架「同步」第二步重放 events.jsonl（progress LWW、书签 per-id 最新状态决胜，本地较新行不被旧事件回退）。**日志折叠已落地**：超过 256KB 时同步流程顺手压成「必胜者名单」（每 work 一条 snapshot 行 + 每书签 id 一条最新状态行，O(作品数+书签数) 恒定；实现取 §5.1 的广义版——不等 30 天，按体积触发）。压缩是多设备竞态安全的有损重写：输家被复活也赢不过 snapshot。设置项 LWW 同步（`synced` scope 落 events）未实现。

### 5.2 错误处理与一致性

- 统一异常层级：`StorageException` → `BucketConfigException` / `ConnectionException` / `ObjectNotFoundException` / `ChecksumMismatchException` / `RetryExhaustedException`。
- **S3 写路径**（索引、meta、归档）：PUT tmp key（带 Content-MD5）→ HEAD 校验 → COPY 到正式 key → DELETE tmp。任何一步失败不留下半成品正式 key。
- **读路径**：指数退避重试 3 次（基数 500ms，抖动 ±20%）；仍失败抛 `RetryExhaustedException`。
- **jsonl 解析**：逐行 `tryParse`，坏行跳过并记录行号 + 前 120 字符到日志；解析器本身无副作用、纯函数，可直接单测。

## 6. 漫画阅读器

> 落地状态（2026-10-03）：竖向连续滚动（双指缩放全局同步）与横/竖逐页模式、边缘点按翻页、自动翻页（1–3600s 自定义）、页码滑杆/数字跳转、页签记忆、进度自动保存/恢复（退出写事件，见 §5）均已实现。**双页对开已落地**：仅横翻模式生效，宽高比≥1.4 判横图独占一个 spread（探测经 ImageProvider 引擎编解码 + 顺序单发队列 + 「当前首 −2~+9」有界窗口，不全量解码），乐观两两配对、结果回流后锚定首页面码重映射不跳页；缩放控制器锚左页，分裂重建后仍对应同一页。**漫画书签 UI 已落地**：底栏「书签」+ 右上角计数药丸（与自动翻页药丸错位），缩略图取页面源同一缓存，loc=`{"page":N}`（1 基，与进度同坐标系），事件与重放链路复用小说侧。M3 完成。

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

### 6.4 页码定位、手势与退出保存（2026-10-19）

- 所有漫画进度和书签使用源页面的 1 基页码；滚动模式底栏显示 `_scrollProgress + 1`，分页模式显示当前源页，对开模式显示 spread 覆盖的源页范围。
- 方向/逐页切换保留当前源页锚点。连续滚动采用带 `center` 的双向 `CustomScrollView`：目标页设为零偏移起点，前页向负偏移延伸、后页向正偏移延伸；跳页不再依赖未知图片高度的估算或有限次数校正。布局完成后测量当前已构建页计算阅读页码，图片加载或窗口变化时刷新测量。
- 页码滑条全程使用源页坐标，拖动值独立预览，松手与数字输入共用 `_jumpToPage`。页码文字独占一行，避免拖动时文字宽度改变、轨道位置移动。对开模式提交后显示包含目标源页的 spread。1201 页、不等页高的本地夹具已覆盖实际目标图位置、末页、滑条手势及模式切换；实际平板长篇交互仍待验收。
- 读图区点按由包裹内容的 `GestureDetector.onTapUp` 判左右各 25% / 中间 50%，不再盖三块命中遮罩；`InteractiveViewer` 位于列表外层只负责变换呈现，关闭其内置手势；读图区 `Listener` 追踪所有指针，按双指初始距离与中心点计算缩放和平移，第二指加入时停止列表运动并暂停翻页，避免第一指先触发滚动后缩放失效。手指距离不设额外门槛，范围 1–4 倍；缩放时单指平移，点按复位。中间呼出菜单同时显示 20sp 操作区说明（`IgnorePointer`，不拦手势），说明区域在顶栏与设置栏之间分配，不被设置覆盖。
- 翻屏距离明确为阅读视口高度的 10–100%，仅影响侧边点按与自动翻屏，不改变手指拖动距离。菜单开启、手指接触、滑条预览、缩放和列表惯性运动期间暂停自动翻页，手动操作后至少等待 3 秒。图片首帧加载保留高度占位，避免零高度项目使整个列表暂时无法滚动。
- 书架本地页签与列表统一从 `shelfFilterProvider.type` 取状态；启动默认小说，取消单独恢复 `shelf.tab`。作品信息弹层内容固定为 560 逻辑像素，矮屏按可用高度收缩，不随竖屏比例拉高；元数据单独滚动，默认只显示 4 个标签，可展开/收起且不改变弹层高度，底部固定“阅读/上传”操作。漫画 id 符合 `jm_<数字>` 时明确显示“JM 车号”。
- 桶内页文件匹配从三位数字扩展到 3–5 位数字；仍按文件名字符串排序，目录列举仍是 `listKeys(max: 1000)`，完整超长漫画读取还需处理列举上限和页名排序契约。
- 漫画、小说阅读器在挂载期缓存数据库与桶客户端，退出保存向 `saveProgressSafely` 传依赖，禁止在 `dispose()` 里读取 `WidgetRef`；小说最终段落位置从缓存文本计算。

- 阅读设置按功能组横向 `Wrap` 排布，宽屏复用右侧空间，窄屏换行；面板最大 300 逻辑像素（且不超过屏高 45%），空间不足内部滚动。方向/浏览、自动间隔、自定秒数、翻屏百分比和书签功能保留。

## 7. 小说阅读器

> 落地状态（2026-10-03）：滚动/逐页两种翻页（真实折行分页，进度坐标=段落号）、进度自动保存/恢复、章节列表、书签增删（事件化）均已实现。**护眼已完整**：四预设（新增护眼绿 #C7EDCC/#3A4A3C）+ 自定义背景/文字色（色盘 + 十六进制，键 `reader.novel.customBg/customFg`，主题选「自定义」生效）+ 图片背景（桌面端选图复制进应用私有目录，缺失静默回退纯色）+ 定时切换（关/跟随系统深色/按时段含跨零点，阅读器内每分钟评估，生效主题=定时覆盖 ?? 手动预设）。**字体已落地（导入 + 桶同步档）**：`library/_fonts/` 为唯一字体库，拉缺/补缺双向幂等同步到 `localRoot/_font_cache/`，FontLoader 动态加载，family 名 `fontFamilyFor` 清洗生成；桌面端设置页导入 .ttf/.otf 自动推桶，Android 经同步获得（SAF 不可本地导入）；`paginateNovel` 以 widthFactor=0.95 给自定义字体留字宽安全边。内置 3 款 OFL 字体因网络受限未捆绑，后续补。**书内搜索已落地**：内存子串扫描（大小写不敏感、段内/总量双封顶），结果列表高亮命中词，点击 `_jumpToPara` 跳转（设计 §9 未要求正文内高亮，不做）。M4 完成。

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

> 落地状态（2026-10-04，M5）：引擎已落地——规则数据派生自 so-novel（25 源，AGPL 致谢见 assets/rules/NOTICE.md），Dart 引擎零 Flutter 依赖（`features/source/`），`@js:` 全量移植为 `@op:` 算子（不引 JS 运行时）；书架第四页签「找书」聚合搜索 → 详情 → 选章范围 → 下载到书架（staging 幂等补章 + novel_tasks 持久化续跑）；产物 = 本地三件套 + §4.2 meta.json（source 回溯块，M6 追更输入已备好）；`/sources` 源管理（启停/导入/单源测试）；`dart run tool/source_doctor.dart` 真实联网巡检。**巡检放行已做（2026-10-04 打磨）**：全量巡检 5/22 通过（梦书/鸟书网/笔尖中文/悠久/阅读库）；sources.json 固化结果——8 源启用（5 实测通过 + 3 无搜索源未实测）、17 源禁用并带原因（11 巡检实锤死源/失效 + 4 需代理本机未配置 + 3 CF），标注进 `tools/convert_rules.py` 的 DOCTOR_DISABLED 表（重跑转换器不丢）；修了一个真 bug：纯 `@op:` 链（@ 在位置 0，无选择器段）此前不会执行（全本搜索签名插件没跑），已修+回归测试。源管理页显示每源最近测试结果；详情弹层错误可重试、下载按钮识别「下载中/已在书架」。**未做**：legado 方言转换器、简繁转换（101看书繁体直存）。工作流与坑见 AGENTS.md「书源引擎（M5）速查」。

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

> 落地状态（2026-10-02）：三条路径中的「上传归档」已完整实现——作品详情「上传到云端」与书架长按多选批量上传（漫画页面 / 小说 book.txt+封面+章节表）共用任务队列（排队/进度/失败重试，面板与 JM 下载合并展示）；索引写入经 `mergeIndexLine` 滤同 id 旧行，重复上传幂等。「仅本设备」即 localOnly 行（下载与 epub 导入的默认），「以后再说」= 详情页按钮常驻。**上传后清本地**：作品信息弹层「删除本地」入口（localOnly 删文件+记录；云端书删本地副本与缓存、云端保留），2026-10-04 确认已覆盖 M6 需求。**未做**：epub 原件随传、源追更（用户决策不做）。

| 选择 | 行为 |
|---|---|
| **仅本设备**（默认） | 存 App 私有目录 `local_works/<id>/{book.txt, meta.json, cover.avif}` + 本地 SQLite，`local_only: true`，不进桶；换设备/清缓存即丢失 |
| **上传归档** | 打包（可选附带 epub）上传 `library/小说/…/`，由「上传归档」流程写 works.jsonl，`origin: "source:sxj"`，全设备可见；上传成功后本地 local_works 副本可清（保留与否用户定） |
| **以后再说** | 先本地读着，书籍详情页常驻「上传到书架」按钮，一键补传 |

连载书的**追更**：

- 详情页「检查更新」→ 源拉最新目录 → 对比 meta.json 的 `last_synced_chapter` → 增量下载新章 → 追加 book.txt 尾部（offset 续排）→ 刷新字数/更新时间 → 已归档的书自动回传更新（走 §5.2 写路径），未归档的只更本地。
- 可选「Wi-Fi 下自动追更」开关，每天一次。

### 8.4 漫画收藏夹（2026-10-20）

漫画书架支持多个自定义收藏夹，同一漫画可以加入多个夹；“全部漫画”和“未归类”提供总览与整理入口。收藏夹可新建、重命名、删除，作品详情支持单本加入，书架长按多选支持批量加入和从当前夹移出。收藏夹与原有关键词、标签、排序和分页共同生效，仅作用于漫画。

收藏夹栏位于漫画页搜索框下方，左侧筛选栏收起时仍可操作；窄屏横向滚动，管理入口位于收藏夹栏末尾。选中夹删除后回到全部漫画；移出最后一本后显示空状态，仍可切回“全部漫画”。切换页码或筛选会清空多选，批量操作范围为当前选择。

收藏夹保存在本设备 SQLite，不写入桶索引或事件日志，不移动作品文件。drift v5 新增 `manga_collections`（名称唯一）和 `manga_collection_entries`（收藏夹 id / 作品 id 联合主键）；从 v4 升级保留现有数据。成员关联书架作品 id，上传后仍保留归属。删除收藏夹只删除归属关系；删除作品记录时由 SQLite 触发器清理成员关系，覆盖手动删除、清扫和索引同步等入口。

验证：收藏夹仓储 8 项回归覆盖迁移、重开、批量回滚、多夹关系、流计数、组合检索与分页；390px 界面测试覆盖管理、单本/批量加入移出、末本移出后的空状态、内联创建及小说隔离。`dart format` 检查 113 文件无变化，`flutter analyze` 零问题，`flutter test` 全量 231 项通过。本次未打包、未做真机验收。

## 9. 检索

> 落地状态（2026-10-04，M7）：FTS5 查询端已接通——关键词先查 works_fts（trigram 子串，≥3 字符，覆盖**含标签**全五列）再 ∪ LIKE 并集兜底（旧数据无 fts 行也搜得到）；查询词不足 3 字符自动回退 LIKE。写侧统一 [upsertWorkFts]（fts_helper.dart）：云端同步/本地登记/书源下载/epub 导入/手动加标签 全路径不漏写。组合语法糖落地：搜索框 `type:novel tag:奇幻 status:ongoing 作者:xx` 前缀自动映射过滤列（parseFilterTokens）。书架级：标题/作者/别名/标签/状态（连载·完结）/类型，本地 FTS5（trigram）毫秒级。
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

1. **M1 桶链路** ✅（2026-09-28 完成）：凭证 + PIN、MinIO SDK 连通、_index 同步、本地 SQLite。同步策略：HEAD 取 etag → 未变零流量；变了**整文件拉取 + 按 id 幂等合并**（字节区间增量曾实现后回退——水位无法感知已消费区段的同长度改写；字节级增量留 M7，届时由写入者加 generation 头）。详见下方细化验收。
2. **M2 阅读器骨架** ✅（2026-10）：漫画竖滑（缩放同步）+ 横/竖逐页、自动翻页、页码跳转；小说滚动/逐页真实分页、主题预设、章节、书签。
3. **M3 漫画完整** ✅（2026-10-03）：横翻 / 自动翻页(可调时) / 进度事件化 / 双页对开（横图探测 + spread 乐观配对）/ 漫画书签 UI 全部落地。InteractiveViewer 自建缩放层已随 M2 落地（缩放全局同步、panEnabled 绑缩放态）。详见 §6 落地状态。
4. **M4 小说完整** ✅（2026-10-03）：护眼四预设 / 章节 / 书签 / 进度 / 自定义颜色 / 定时切换 / 图片背景 / 字体导入（_fonts/ 同步，内置字体捆绑因网络受限推迟）/ 书内搜索 全部落地。详见 §7 落地状态。
5. **M5 书源引擎** ✅（2026-10-04 落地并巡检放行，8 源启用/17 禁用带因）：规则体系派生自 so-novel（AGPL-3.0，25 源规则数据进 assets/rules/ + NOTICE.md 致谢，`tools/convert_rules.py` 一次性转换）；Dart 引擎零 Flutter 依赖（`features/source/`：source_models/loader/selector/xpath/css/ops/http/search/book/toc/chapter/cleaner/assembly/pipeline/probe），so-novel 的 18 处 `@js:` 全部移植为 `@op:` 具名算子（replace/regexReplace/prefix/absUrl/base64Lines/qsbs 系/jsonpField/ddSortByDataId/filterHiddenLis/quanbenSearchUrl），不引 JS 运行时；自写迷你 CSS 引擎（package:html 缺 `:nth-of-type`/`~` 支持）+ 最小 XPath 子集（真 XPath 仅 4 处）。下载管线：staging tmp 幂等补章 + 有界并发 + 每章 withRetry，缺章清单续跑；产物 = 本地三件套 + §4.2 meta.json（source 回溯块供 M6 追更）。任务体系对齐 JmTasks（drift v4 novel_tasks 持久化/续跑/面板第三段/角标三源求和）；UI = 书架第四页签「找书」+ `/sources` 源管理（启停/导入 JSON/单源测试）。CF 三源默认禁用（运行时标题检测自动禁用）；101看书繁体直存不转换。**巡检**：`dart run tool/source_doctor.dart [--source slug]`（真实联网四步，不进 flutter test）；试跑 yeudusk 全链路通过。**未做**：全量 25 源巡检放行（需逐个跑 source_doctor 并按结果启停，源站存活率随时间变化）、legado 方言转换器、单源探针书按需扩充。
6. **M6 追更与归档** ✅（2026-10-04 收尾）：上传归档（详情页 + 长按批量、漫画/小说、任务队列与重试）✅（§8.3）；「上传后清本地」**入口早已存在**（作品信息弹层「删除本地」：localOnly 连记录删、云端书只删本地文件与阅读缓存，shelf_page `_deleteLocal`），无需重复建设；`_novel_cache` 失效已落地——`uploadNovel` 成功即删 `<root>/_novel_cache/<id>/`（该缓存只写不更新，清后下次打开重拉新内容，有单测）。**源追更（源站增量更新）经用户决策不做**（2026-10-04）：M5 下载已带 source 回溯块（meta.json），将来若反悔可直接基于它实现，无需返工。
7. **M7 打磨** ✅（2026-10-04）：FTS 调优（查询端接通 + 五处写洞补齐 + 语法糖，见 §9 落地状态）；缓存清理策略（启动修剪：图片缓存按 `cache.imageLimitMb` LRU 淘汰、`_novel_cache` 512MB LRU、审阅残留整删，cache_prune.dart；`_font_cache` 不淘汰）；启动清扫去重（JM/书源两个恢复入口会话级只跑一次）；封面解码 cacheWidth 340；图片下载共享 HttpClient；release 双端出包验证（Android debug 签名自用、Windows release 走 ATL 已验证路径）。

计划外已落地：**JM 漫画下载 + AVIF 压缩管线**（2026-09-29/30，§14）、**阅读进度/书签事件同步与日志折叠**（2026-10-02，§5）、**批量上传与任务队列**（§8.3）、**压缩人工审阅**（2026-10-02，§14.4）。

### M1 细化验收

1. 录入桶配置后 HEAD bucket 成功，可列出 `_index/` 前缀对象，显示往返延迟。
2. works.jsonl 全量拉取解析入库；坏行跳过且计数可见。
3. 二次启动同步：etag 未变零流量；有变化整文件拉取按 id 幂等合并，无重复行，`local_only` 行不受影响。
4. PIN 设置/解锁流程闭环；SK 经 PIN 派生密钥 AES-256-CBC + HMAC-SHA256 加密落盘，解锁后可解密使用，错误 PIN 解不开（PBKDF2 以 RFC 7914 向量单测验证）。
5. `flutter analyze` 零告警、`flutter test` 全绿（直接在真实路径运行；根目录已改纯 ASCII，历史上的 `subst Z:` 盘符 workaround 已退役，见 README）。

## 12. 风险与验收

| 风险 | 对策 |
|---|---|
| flutter_avif 解码性能 | M2 首周 spike：10 张实际漫画 AVIF 验证解码/内存/缩放 |
| 漫画缩放方案 | photo_view 已停止维护 → 自建 InteractiveViewer 缩放层，M3 spike 验证，必要时评估维护中的 fork |
| minio Dart 包能力核对（M1 实测结论） | `copyObject`/`presignedGetObject` 可用 ✅；`getObject` 无 range 参数 → 区间读走「预签名 URL + 自加 Range 头」（该 SDK 预签名只签 host，SigV4 合法）；`putObject` 无 headers 参数 → Content-MD5 待 M6 自补 SigV4 请求层时带上 |
| FTS5 虚表建表 | drift_dev 不识别 `USING fts5` 模块（需额外注册）→ 改为运行时 `customStatement` 建表（MigrationStrategy.onCreate），查询统一走 customSelect |
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
| 纯函数 | jsonl 解析/坏行跳过、事件重放合并、path_helper 构造↔解析、章节 offset 计算、书源规则引擎、withRetry 退避编排、worthReplacing 判定、pageKeysOf 选页 | 普通单测，无 binding |
| drift | works/bookmarks/progress/settings CRUD、FTS5 中文检索、同步水位推进 | 内存库测试 |
| 加密 | PIN 派生/加解密往返、错误 PIN 失败 | 普通单测 |
| S3 封装 | 以 fake 实现顶替 `BucketClient` 接口测同步流程 | 接口注入 |
| UI | 阅读器翻页、书签交互 | widget test（自 M2 起） |

### 13.1 本次验证记录（2026-10-18–19）

- 最新格式检查：`dart format --output=none --set-exit-if-changed .`，109 个文件无需修改；`flutter analyze` 零问题。
- `flutter test` 全量 217 项通过。`test/features/jm/jm_downloader_test.dart` 使用假 API 和临时目录验证：不同章节相同页名不会覆盖、返回顺序符合章节顺序、单页失败后再次调用只请求缺失页，以及多本多章共享图片处理上限。
- `jm_tasks_test.dart` 通过内存库和阻塞假管线实际触发恢复入口，验证 queued/downloading/compressing 混合的 39 个任务恢复后仅执行两本、其余持久化排队、失败释放名额、同车号防重；`jm_work_queue_test.dart` 验证 FIFO 与失败释放。它们不替代真实网络和进程重启验收，假 API 测试也不验证实际 CDN 切换和网络超时。
- `flutter build apk --debug` 成功；已在 Android 13 / arm64 平板上经 USB 覆盖安装并启动，短时日志未发现 `FATAL EXCEPTION` 或 Flutter 未处理异常。本机设备与命令记录在不发布的 `README.local.md`。
- **待设备验收**：真实网络下下载进度停滞/单页失败、下载中杀进程后补页、JM 本地入口交互、不同页高与千页漫画跳转、连续翻页/模式切换后的稳定性。启动检查不能替代这些场景，也未据此确认原始闪退原因全部消除。
- 本次卡顿排查已在设备上捕获后台过载证据（§14.7），资源限流修复版已重新覆盖安装。用户解锁后确认两本执行、其余排队；读取本地 `localOnly`、153 页作品时完成 24 次往返滑动，采样 UI 帧 `Animator::BeginFrame` P95 21.23ms、最大 30.71ms，GPU 绘制 P95 3.68ms；另一次 8 次滑动采样 UI 帧 P95 19.07ms、最大 34.35ms。两次采样均无超过 100ms 的 UI 帧；同时两本后台任务分别从 97/237、128/233 页推进到 197/237、184/233 页，证明下载并未被暂停。运行时仅一个图片还原 isolate 活跃；修复后的这些短时采样未重现原先秒级停顿。数据来自 Android debug 构建和有限时间采样，不等同于全程 60fps 或长时压力验收；小说书架为空，未实测本地小说。设备还有 1 个任务因图片下载失败而失败，限流不解决源站缺页问题。

- 2026-10-19 新增 7 项真实组件 widget 回归：两侧拖动、按视口百分比翻屏与操作提示、1201 页滑条/数字跳转、横向翻页、双指缩放复位、对开与方向/逐页切换、菜单及滑条期间自动暂停；书架测试覆盖遗留 `shelf.tab=manga` 时默认小说、立即切换漫画，以及大量标签情况下固定阅读按钮和导航。格式检查 109 文件零改动，analyze 零问题，全量 217 项通过，Android debug 构建成功。新 APK 已经 USB 保留数据覆盖安装并启动，进程存在；平板目前锁屏，这批交互尚未重新实机验收。

- 2026-10-19 二次交互维护：提示放大并与菜单分区，设置横向重排，详情固定紧凑高度、标签展开与车号展示；原始指针驱动缩放。新增横/竖方向首指先滑动、两指分处两端的缩放回归，以及 1280×800、800×1280、400×800 布局检查；详情测试验证 40 标签展开/收起、车号、屏高从 800 改到 1200 后内容仍为 560、阅读按钮固定。格式检查 109 文件零修改、analyze 零问题、全量 222 项通过，debug APK 构建成功。本批仍需解锁平板后验收手感。

## 14. JM 漫画下载与 AVIF 压缩管线（2026-09-30 增补）

计划外落地：JM 下载先于书源引擎（M5）完成，2026-09-29 起 Dart 原生化，不依赖 Python / jmcomic 外部源码，Windows / Android 均可直接下载。

### 14.1 分层

| 目录 | 职责 |
|---|---|
| `features/jm/` | 站方 API 层：jm_crypto（AES 响应解密）、jm_api（协议常量与请求）、jm_scramble（图片条带还原）、jm_account / jm_browse / jm_downloader（账号、浏览、并发下载编排） |
| `features/downloader/` | 本地管线：jm_models（纯函数与驱动行模型：pageKeysOf 选页、worthReplacing 判定）、jm_pipeline（下载后逐页 AVIF 转码）、avif_transcoder（AvifTranscoder：ffmpeg 封装、libaom crf 档位、ssim）、cloud_compress（桶内对象重压缩）、jm_tasks（任务状态与 startJmDownload）、jm_download_dialog（下载 UI） |

加解密要点：响应解密密钥是 `md5(ts+密钥)` 的 **ASCII hex 串本身（32 字节，AES-256）**，不是原始摘要。协议常量写死在 jm_crypto.dart / jm_api.dart，服务端轮换时需同步更新。

### 14.2 AVIF 压缩两条路径

**本地路径（下载时压缩，`JmPipeline`）**：逐页 ffmpeg 转码 → ssim/体积判定（worthReplacing）→ 就地替换原图。ffmpeg 可空，缺失时自动跳过保留原图。

**云端路径（已有对象重压缩，`compressCloudMangas`）**：pageKeysOf 只挑三位数字页（封面/章节表剔除）→ 对象「下载 → 转码 → 判定 → PUT → DELETE 原 key」，每轮重试重新下载 → `_rewriteIndex` 重写索引 → 书架页 SnackBar 报告（replaced / keptOriginal / failed），`failed > 0` 时带「重试」按钮重跑整批。

### 14.3 重试语义

统一入口 `core/retry.dart` 的 `withRetry`：指数退避 1×/2×/4×（baseDelay 默认 1s，封顶 8s），`attempts` **含首次尝试**（默认 3），耗尽抛最后一次异常；`shouldRetry` 返回 false 的确定性失败立即抛出；`onRetry` 在每次重试前回调（进度提示用）。

- 两条压缩路径的转码与桶 IO 均包 withRetry，**重试耗尽才计入 failed**；
- 进程级错误（ProcessException / FileSystemException / 缺 ffmpeg，见 jm_pipeline.dart 顶层 `isProcessLevelError`）不重试，直接跳过剩余页；
- 转码成功但 worthReplacing 判定「不值得替换」按失败处理：走重试，耗尽后归入 kept（保留原图）统计——重试不改变判定结论，只是把瞬时故障和真正的「不值得」分开。

### 14.4 压缩人工审阅（2026-10-02 增补）

`compress_review.dart` + `review_models.dart`：对桶里非 AVIF 页面逐页「原图 vs 本地转码 AVIF 候选」人工对比拍板，弥补 `worthReplacing` 自动判定与主观画质接受度的差距。仅桌面端（需 ffmpeg，Android 无法执行外部二进制）。

- **两段式**：先选书列表（每本显示 x/y 页原图待审、原图总体积、已压进度条，`BucketClient.listObjects` 带大小列举，按待审页数降序），点选后逐页审阅，审完回写索引/派生封面回到列表；
- **两种对比模式**：并排（图底半透明横条标体积）/ 竖线滑动（鼠标移动分割线，左原图右 AVIF，下方显示双方体积与节省比例）；
- **决定立即生效**：用 AVIF → put + delete 原图；保留原图 → 丢弃候选；跳过 → 下次再审；提供「本作品剩余全保留原图」批量逃生口；
- 索引回写与云端压缩共用 `rewriteWorkIndex`；决定应用失败留在当前页可重试，中途关闭不丢已生效决定。

### 14.5 压缩 Worker（2026-10-03 增补）

`tools/compress_worker/`：常驻 CLI，把「云端兜底压缩」从 PC 手动任务升级为独立服务。与 §14.2 云端路径**同参数同判定**（crf 45 + worthReplacing），区别只在选目标：读桶里的 works.jsonl 筛 `type=manga && !local_only && !compressed`（桶即真相，不依赖任何设备的 SQLite），逐本下载→转码→判定→替换→回写 `compressed` 标记与派生封面；全 AVIF 的历史作品首轮自动补标。轮询间隔可配（默认 10 分钟），`ONESHOT=1` 可单轮退出。

共享代码在 `pkgs/mandu_core/`（纯 Dart，零 Flutter 依赖与 build hooks）：App 侧对应路径是 re-export shim，实现改动只发生在 pkgs/。部署形态：Linux 单二进制 + systemd（推荐）或 Windows 任务计划；凭证走环境变量，与 App 凭证同一最小权限集。手机/PC 传完原图即可关 App，压缩由常开机器完成——「无服务端」指数据面不经中转，Worker 不存数据不当权威，与设计 §2 的桌面整理工具同角色。

### 14.6 下载任务持久化与中断恢复（2026-10-03 增补）

任务队列此前是纯内存 Riverpod 态，应用被杀/闪退即丢。落地：

- drift v3 新增 `jm_tasks` 表（albumId PK + 状态/阶段/错误/结果/配置快照/updatedAt）；`jmTasksProvider` 每次 upsert/patch/remove 同步落库（进度文案节流 2s，终态必落）。
- 启动时（书架角标监听触发 provider `build()`）恢复任务列表；状态为 queued/downloading/compressing 的任务自动调用 `startJmDownload(resume: true)`；续跑入口用 `main()` 显式创建并赋值的全局 `rootContainer`（无 context 场景读写 providers）。2026-10-18 修复：数据库遗留的“下载中”不能被当成当前进程已有任务而直接返回；`_activeDownloads` 记录本进程已入队或执行中的车号，防止同车号重复入队。所有入口共享 2 本并发的 FIFO 队列，等待任务持久化为 queued 并显示“排队中”，恢复后重新排队；排队任务也纳入清扫排除集和角标。进度按车号分别节流 2s，状态切换和终态立即落库。
- 恢复时顺手**清扫半成品记录**：下载中断留下的「行还在、文件没了」的 localOnly 作品直接删行（点开必报错，见 `local_sweep.dart` 的 `classifyLocalWork` 纯判定 + 单测）；文件健在但行是早期元数据回调登记的半成品（pages=0/无封面）时补齐字段。进行中任务的 id 传入排除集，防止误删。
- 下载临时目录使用 `jm_download/jm_<车号>/photo_<章节顺序>_<章节id>/` 隔离章节，返回列表按相册章节顺序展开，不能把所有章节的 `001` 混排或写在同一目录。
- 每页先写 `.part` 并 flush，成功 rename 才视为完成。再次执行时复用非空完整页；失败时保留临时目录，仅管线成功后删除。临时目录若被系统清理则重新下载；这不是字节范围续传，也没有对复用页重新做内容校验。
- 图片最多请求 5 次，失败时轮换 CDN；响应头等待和响应体连续无数据等待均设超时，API 文本响应也设置响应体空闲超时。单页耗尽后错误带章节和页码，任务仍为 failed；重试从保留页面补起，不会将缺页作品标记为完成。
- 全部图片下载后先复制到 `<workId>.staging`，旧目录暂存为 `<workId>.backup`，再切换为正式目录；替换失败时尽力恢复旧目录。`onMeta`、`onLocalReady` 支持并等待异步登记，避免回调与后续阶段并发写库。这是管线内保护，不代表任意杀进程时刻的目录恢复均已通过验收。

### 14.7 解码移出主 isolate（2026-10-03 增补）

JM 图片「解码 → 条带还原 → JPEG 重编码」（image 包，纯 Dart 逐像素）经 `Isolate.run` 在独立 isolate 执行（`jm_downloader._decodeInIsolate`），但 isolate 本身不限制资源。2026-10-18 Lenovo 平板排查发现大量任务同时运行时，多个 DartWorker 占用约 550% CPU、应用 PSS 约 858MB，Choreographer 连续记录 8–15 秒停顿；抓取时系统没有 ANR 记录。原来的“每章 8 张”会与 4 章及多本任务相乘，不能视为全局并发上限。

修复后所有下载器实例共享图片处理闸门（网络请求至落盘整体最多 8 页）和 CPU 解码闸门（最多 1 页）；旧图无需还原时直接复用原字节。整本任务再由 §14.6 的 2 本队列限制，避免启动时批量恢复挤满 CPU/内存。回归覆盖多本多章的全局图片上限、FIFO 名额交接与失败释放，以及 39 个持久化任务恢复后仅执行两本；持续下载时的真机短时阅读采样见 §13.1，长时压力与小说阅读仍待验收。jm_scramble 保持纯函数零 Flutter 依赖。

### 14.8 设置页目录选择器（2026-10-03 增补）

本地下载目录不再手输：应用内目录选择器（`settings/directory_picker.dart`）。Android 硬约束下只列应用私有目录（SAF 的 content:// 路径无法被 dart:io 使用，公共目录 Android 10+ 禁直接文件 IO）；桌面端从 home/盘符根自由浏览，支持新建文件夹。保存后 `localRootProvider` 即失效刷新。

### 14.9 JM 本地作品识别（2026-10-18）

本地作品以 `jm_<车号>` 为唯一 id。JM 详情弹层查询同 id 的书架行，满足 `localOnly == true && pages > 0` 时将“下载到书架”替换为“打开本地漫画”，直接进入该作品阅读器；页数为 0 的下载占位行不视为可读。当前判断基于数据库行，未检查页面文件是否仍存在；上传后 `localOnly == false` 的云端行即使保留本地副本，也不在此判断范围内。弹层关闭前抓取 `ProviderContainer` 和 `ScaffoldMessenger`，避免使用失效 context。
