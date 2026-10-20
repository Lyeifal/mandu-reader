# 漫读 (mandu_reader) · 漫画小说资源管理

漫画 + 小说阅读与管理应用（Flutter），无服务端：App 经 SigV4 直连私有 S3 兼容桶（OSS / COS / R2 / MinIO 均可），本地 SQLite 优先检索与阅读。

**本仓库仅供个人学习与技术研究使用，不作任何担保。** 上游参考仓库的许可边界见文末「上游致谢 / 参考仓库」。

## 功能

- **书架**：桶索引同步（按 id 幂等合并、etag 未变零流量）、筛选/翻页/封面/标签、关键词搜索（FTS5 trigram，短词自动回退 LIKE）
- **漫画收藏夹**：自定义多个收藏夹，同本漫画可加入多个夹；支持单本和批量整理、“未归类”筛选，与原有搜索、排序和分页配合使用；归属关系保存在本机
- **漫画阅读器**：分页/滚动、双页对开、书签、进度记忆、图片缓存 LRU 修剪
- **小说阅读器**：书源下载 + 本地排版、护眼主题（可定时自动切换）、自定义字体与 `_fonts/` 桶同步、书内搜索、章节目录
- **JM 下载**：移动端 API 纯 Dart 原生实现（直连 + AES 响应解密 + 图片条带还原），Windows / Android 均可下载；任务持久化，中断后复用已完成页面补下载；多章节按章顺序整理，图片请求支持 CDN 切换与超时
- **JM 本地识别**：以 `jm_<车号>` 标识作品；详情页发现本设备的 `localOnly` 作品且页数大于 0 时，显示“打开本地漫画”
- **AVIF 管线**：下载后本地转码 / 桶内 Worker 自动重压缩 / 人工审阅，失败统一指数退避重试（缺 ffmpeg 等进程级错误直接跳过）
- **书源引擎**：25 个小说源规则（数据派生自 so-novel）+ Dart 重写引擎（迷你 CSS/XPath 选择器、`@op:` 算子、staging 幂等补章、meta.json 追更回溯）、源管理与自定义源导入
- **多端同步**：进度/书签事件日志（jsonl 追加 + 进度 LWW / 书签按 id 决胜合并 + 超量折叠），批量上传走任务队列（漫画页面 / 小说整本）
- **压缩 Worker（可选）**：常驻单二进制轮询桶索引，把未压缩页面自动转 AVIF，与 App 生命周期无关

## 技术栈

| 层 | 选型 |
|---|---|
| 框架 | Flutter stable；Riverpod 状态管理、go_router 路由 |
| 本地库 | drift（SQLite）+ FTS5 trigram |
| 网络 / S3 | minio 包 + 自封装 BucketClient（SigV4）；重试统一走 `withRetry` 指数退避 |
| 密钥 | flutter_secure_storage；SK 经 PIN 派生密钥 AES-256-CBC + HMAC-SHA256 加密落盘 |
| 纯核心包 | `pkgs/mandu_core`：零 Flutter 依赖，App 与 compress_worker 共用 |

## 目录结构

```
app/             Flutter 工程（lib/features/ 按域划分：bucket / library /
                 jm / downloader / reader / source / settings / auth）
pkgs/mandu_core  纯 Dart 核心（重试、路径契约、索引合并、S3 客户端、AVIF 策略）
tools/           compress_worker（独立部署的压缩守护进程）、convert_rules.py（书源规则转换器）
docs/design.md   架构与设计文档
```

## 快速开始

```bash
cd app
flutter pub get
flutter run -d windows        # 或连接设备后 flutter run / flutter build apk --debug
```

质量门槛（任何改动后应保持）：

```bash
cd app
dart format --output=none --set-exit-if-changed .
flutter analyze   # 零告警
flutter test      # 全绿
```

drift 改表结构后重新生成：`dart run build_runner build --delete-conflicting-outputs`（生成的 `*.g.dart` 入库）。

## 漫画收藏夹怎么用

1. 在“漫画”页上方点“管理”，新建、重命名或删除收藏夹。收藏夹较多时可横向滑动上方列表。
2. 点开漫画详情，选择“加入收藏夹”；也可长按漫画后多选，批量加入已有夹或直接新建夹。
3. 进入某个收藏夹后，长按选择漫画，再点“从当前收藏夹移出”。“未归类”显示尚未加入任何收藏夹的漫画，“全部漫画”返回总览。切换页码或筛选会清空多选。

同一本漫画可以属于多个收藏夹，上传归档后仍保留归属。删除收藏夹或移出漫画会保留漫画文件。收藏夹仅在本机保存，不参与桶同步；数据库会自动升级至 v5 并保留原有作品数据。

## 最近更新（2026-10-20）

- 新增漫画收藏夹管理、详情单本加入、长按批量加入和移出，以及“未归类”筛选。
- 格式检查通过（113 文件无变化）、`flutter analyze` 零问题、`flutter test` 全量 231 项通过；覆盖数据库迁移、关闭重开后的持久化、批量失败回滚、组合检索与分页，以及 390px 窄屏完整管理流程。
- 本次收藏夹版本未打包、未做真机验收；此前版本的构建与设备记录见下方维护记录。

## 最近维护（2026-10-18–19）

- 修复下载恢复被重复任务检查拦截、多章节同名页面覆盖；失败重试保留完整页面，错误包含章节与页码；单页重试耗尽时任务仍显示失败，不会将缺页作品标记完成。
- 修复批量后台下载挤占阅读资源：所有任务共用 2 本并发队列，其余显示“排队中”；跨章节、跨相册共享最多 8 页处理和 1 页 CPU 解码名额，避免仅移到 isolate 后仍占满 CPU。
- 修复侧边点按区遮挡滑动与缩放组件抢手势；双指缩放改由读图区指针直接驱动，支持两指分处两端、首指先滑动后加入第二指。中心操作说明放大到 20sp，与横向排布的紧凑设置菜单分区，翻屏距离注明为视口百分比，自动翻页避让手动操作。
- 页码滑条独立预览、松手提交，文字不再挤动轨道；连续滚动以目标页为列表锚点精确定位，取代页高估算。1201 页不等高度夹具通过跳转、实际图位置和模式切换测试，实机长篇仍待验收。
- 书架默认小说，页签和列表共用筛选状态；详情弹层固定紧凑高度（560 逻辑像素、矮屏自适应），阅读按钮固定在底部，标签默认展示 4 个并支持展开；JM 漫画明确显示车号。
- 阅读器桶内页面匹配扩展到 3–5 位数字文件名；当前仍受单次最多列举 1000 个 key 的限制，不代表任意超长漫画已完整支持。
- 已通过格式检查、`flutter analyze`、全量 `flutter test`（222 项）和 Android debug 构建。此前 USB 平板已覆盖安装资源限流修复版，实测两本后台下载持续推进时本地漫画连续滚动，短时采样未重现秒级停顿（UI 帧 P95 约 19–21ms）。2026-10-19 交互修复版已构建并经 USB 保留数据覆盖安装，启动进程正常；平板当前锁屏，尚未重新进行交互验收；真实下载中断续跑、长期压力、本地小说及长篇跳转仍需设备验收。实现细节见 [设计文档 §6.4、§13.1、§14.6–14.7](docs/design.md)。

## 压缩 Worker（可选，独立部署）

桶里未压成 AVIF 的漫画页面由常驻 Worker 兜底。纯 Dart 单二进制（复用 `pkgs/mandu_core`，无 Flutter、无 build hooks），宿主只需装 ffmpeg；dart2native 不跨平台，在目标机器上编译：

```bash
cd tools/compress_worker
dart pub get
dart compile exe bin/compress_worker.dart -o compress_worker
```

环境变量（前四个必填；模板见 `tools/compress_worker/env.example`）：

```
BUCKET_ENDPOINT  BUCKET_NAME  BUCKET_AK  BUCKET_SK
BUCKET_REGION（可空）  BUCKET_PORT（可空）  BUCKET_SSL（默认 true）
FFMPEG（默认从 PATH 找）
SCHEDULE_AT（默认 02:00）：每日定时，进程睡到点干活；当天已过点排到明天
INTERVAL_MINUTES（设置后退回轮询模式，每 N 分钟一轮）
ONESHOT=1（只跑一轮即退，适合 cron / 手动测试）
```

Linux 用 systemd 常驻：

```ini
[Unit]
Description=mandu compress worker
After=network-online.target

[Service]
EnvironmentFile=/etc/mandu/worker.env    # 环境变量写这里，chmod 600
ExecStart=/opt/mandu/compress_worker
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Windows 配任务计划程序「登录时启动」即可（进程自己等到点，无需每日触发）。Worker 选目标靠索引行的 `compressed` 标记，首次运行会把全 AVIF 的历史作品补标并跳过。

## 书源规则维护

规则资产链路：so-novel 仓库 `bundle/rules/*.json` → `tools/convert_rules.py`（`@js:` → `@op:` 映射）→ `app/assets/rules/sources.json` + `NOTICE.md`。**不要手写 sources.json**。改完跑：

```bash
python tools/convert_rules.py
flutter test test/features/source/    # 选择器全量回归
dart run tool/source_doctor.dart      # 真实联网巡检（搜索→详情→目录→正文）
```

## 上游致谢 / 参考仓库

| 功能 | 参考仓库 | 关系与许可说明 |
|---|---|---|
| JM 漫画下载 | [hect0x7/JMComic-Crawler-Python](https://github.com/hect0x7/JMComic-Crawler-Python) | 移动端 API 协议、加解密、图片条带还原逻辑的移植蓝本（原 Python 库 `jmcomic`；本工程为其纯 Dart 重写，见 `app/lib/features/jm/`）。**该仓库未标注开源许可证**（原 README 声明仅供学习研究），此处仅作实现出处说明，相关权利义务由使用者自负。 |
| 小说书源引擎 | [pcdd/sonovel](https://github.com/pcdd/sonovel) | 25 个书源规则数据派生自其 `bundle/rules/*.json`（AGPL-3.0）；署名与逐源对照见 [app/assets/rules/NOTICE.md](app/assets/rules/NOTICE.md)。引擎本身为独立 Dart 实现。 |
