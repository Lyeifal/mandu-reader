# 漫读 (mandu_reader) · 漫画小说资源管理

漫画 + 小说阅读与管理应用（Flutter），无服务端：App 经 SigV4 直连私有 S3 兼容桶（OSS / COS / R2 / MinIO 均可），本地 SQLite 优先检索与阅读。

**本仓库仅供个人学习与技术研究使用，不作任何担保。** 上游参考仓库的许可边界见文末「上游致谢 / 参考仓库」。

## 功能

- **书架**：桶索引同步（按 id 幂等合并、etag 未变零流量）、筛选/翻页/封面/标签、关键词搜索（FTS5 trigram，短词自动回退 LIKE）
- **漫画阅读器**：分页/滚动、双页对开、书签、进度记忆、图片缓存 LRU 修剪
- **小说阅读器**：书源下载 + 本地排版、护眼主题（可定时自动切换）、自定义字体与 `_fonts/` 桶同步、书内搜索、章节目录
- **JM 下载**：移动端 API 纯 Dart 原生实现（直连 + AES 响应解密 + 图片条带还原），Windows / Android 均可下载；任务持久化，重启自动续跑
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
