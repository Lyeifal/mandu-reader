# AGENTS.md — 漫读项目代理指南

## 项目是什么

单人自用的漫画/小说阅读管理 Flutter 应用。无服务端，直连私有 S3 兼容桶；本地 SQLite（drift）优先检索与阅读。架构与设计见 [docs/design.md](docs/design.md)，先读它再动手。

## 硬约束

- 仓库根目录名含 `&`（`D:\Code\comics&book`），**Flutter 工程在 `app/` 子目录**。bash 命令中涉及该路径必须加引号；不要试图把工程放根目录。
- **跑 `flutter test` / `flutter run` 必须先 `subst Z: "D:\Code\comics&book"` 并 `cd /z/app`**：`&` 会截断原生资产钩子拼出的 cmd 命令行，从真实路径跑必败。`flutter analyze` 不受限。
- 包名是 **`mandu_reader`**（漫读拼音 man-du），注意不是 `mundu`。import 写错时 CFE 只报 "Couldn't resolve the package"，不提示拼写——2026-09-30 真踩过：症状是**同包只有部分文件**报 `uri_does_not_exist`、其余文件正常，且 analyze 伴随 `depend_on_referenced_packages` info。看到这种「部分文件解析失败」先查拼写，别怀疑 SDK。**2026-10-03 二踩**：CLI 的 `package:` import 写成了 `mindu_reader`（i/a 不分），50 个连锁报错。写 import 时默念 man-du。
- 本机已装 Visual Studio Build Tools 2022（Windows 桌面构建可用，桌面构建依赖 **开发人员模式** 已开启）与 Android SDK（`%LOCALAPPDATA%\Android\Sdk`，含 cmdline-tools / platform-tools / android-36 / build-tools / cmake；`flutter config --android-sdk` 已指向它）。`flutter build apk --debug`、`flutter build windows --debug` 均已验证可出包。Android 真机调试已验证：USB 连接 Redmi K60 Pro（代号 socrates），`adb install -r` 安装 `dev.mandu.mandu_reader`，日志用 `adb logcat | grep flutter`。没跑过的环境（模拟器等）不要声称跑过。
- **JM 下载已 Dart 原生化**（`app/lib/features/jm/`：jm_crypto / jm_api / jm_scramble / jm_downloader 等，2026-09-29）：移动端 API 直连 + AES 响应解密 + 图片条带还原 + 并发编排，**不再需要 Python / jmcomic 外部源码**；Windows 和 Android 都能直接下载。移植要点：响应解密密钥是 `md5(ts+密钥)` 的 **ASCII hex 串本身（32 字节，AES-256）**，不是原始摘要——易错。协议常量（密钥/域名/UA）写死在 jm_crypto.dart / jm_api.dart，服务端轮换时需同步更新。AVIF 压缩管线在 `app/lib/features/downloader/`（jm_pipeline 本地转码 / cloud_compress 桶内重压缩 / compress_review 人工审阅），压缩失败经 `lib/core/retry.dart` 的 `withRetry` 指数退避重试，缺 ffmpeg 是进程级错误不重试、直接跳过；详见设计文档 §14。
- **状态同步已事件化**（`app/lib/features/library/events_log.dart`，2026-10-02）：进度/书签追加到 `_state/events.jsonl`，同步 = 索引合并 + 事件重放两步（progress LWW、书签 per-id 最新状态决胜）；日志超 256KB 由 `compactEvents` 顺手折叠成「必胜者名单」（每 work 一条 snapshot + 每书签 id 一条最新状态，竞态安全，往返不变性有单测）。
- **上传走任务队列**（`app/lib/features/library/upload_tasks.dart`，2026-10-02）：书架长按多选 → 批量上传（漫画页面 / 小说 book.txt+封面+章节表走 `JmPipeline.uploadNovel`）；任务面板与 JM 下载合并展示（排队/进度/失败重试）。队列用 `ProviderContainer` 而非 WidgetRef——弹窗关闭后任务仍在跑。索引写入统一走 `mergeIndexLine`（滤同 id 旧行再追加，重复上传不叠行）。
- **纯核心已拆包**（`pkgs/mandu_core/`，2026-10-03）：重试/异常/桶路径契约/索引合并/AVIF 策略/S3 客户端/works.jsonl 解析的实现都在这个零 Flutter 依赖、零 build hooks 的包里；**App 侧原路径（lib/core/*、features/bucket/*、avif_transcoder、works_index）只是一行 re-export shim——改实现只动 pkgs/，不要往 shim 里加代码**。动机：`tools/compress_worker/`（常驻压缩 Worker，轮询桶索引自动把原图转 AVIF，部署见 README 的 systemd 章节）需要在裸 Linux 上 `dart pub get && dart compile exe`，而 App 包的 sqlite3/objective_c build hooks 会让 `dart compile exe` 直接拒绝。
- **三个 UI 坑（2026-10-02 真踩过，别再犯）**：① 底部弹层（showModalBottomSheet）里先 `Navigator.pop` 再用其 context 弹 SnackBar/Dialog——context 已死，提示被静默吞掉（上传失败看不见的元凶）；必须先抓 `ScaffoldMessenger`/`ProviderScope.containerOf` 再 pop。② Material 3 `SegmentedButton` 各段等宽且选中段默认带对勾图标，最长标签+对勾会撑爆顶栏（黑黄条纹溢出）——紧凑场景一律 `showSelectedIcon: false`。③ 手机端没有也无法执行外部二进制（SELinux）：ffmpeg 相关功能（AVIF 转码、云端压缩、审阅）只在桌面端出入口，`Platform.isWindows || isLinux || isMacOS` 判定。
- Windows 桌面构建注意：flutter_secure_storage_windows 插件需要 ATL，本机 14.44 工具集的 `atls.lib` 是从 14.42 复制的（`VC/Tools/MSVC/14.44.35207/atlmfc/lib/{x64,x86}/atls.lib`，v143 MFC 普通版当时装不上）；若将来重装/补齐 "适用于 v143 生成工具的 C++ MFC/ATL" 组件，直接覆盖即可。VS Installer 里 "(2)" 结尾的 Build Tools 条目是残影（指向坏路径 `C:\Program`），可在"更多 → 卸载"清理。
- 本机网络对国际出口限速（maven.google.com 直接 TLS 握手失败，GitHub/gradle.org 低速至不可用），已配镜像，构建前确认各环节可用：
  - Gradle 依赖：项目 `app/android/settings.gradle.kts`、`app/android/build.gradle.kts` 里阿里源（`maven.aliyun.com`）优先，官方源兜底；全局兜底在 `~/.gradle/init.d/cn-mirrors.gradle`（只注入主构建，includeBuild 禁止项目级仓库）。
  - Flutter 引擎产物：`FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter`（用户级环境变量，已 setx；新 shell 生效）。
  - sqlite3 预编译库：hook 走 `gh-proxy.com` 代理，配置在 `app/pubspec.yaml` 的 `hooks.user_defines.sqlite3.url_pattern`；代理失效时换代理地址。
  - Flutter SDK 的 `packages/flutter_tools/gradle/settings.gradle.kts` 也被加了镜像（**SDK 升级后需重改**，否则插件解析会卡死在 plugins.gradle.org）。
  - `flutter doctor` 的 maven.google.com 网络告警是已知残留，不影响构建。
- Android 出包的两个本地补丁（`flutter pub add` 重下或升级 flutter_avif 后需重打）：
  - pub 缓存 `flutter_avif_android-3.1.0/android/build.gradle`：`compileSdkVersion 31 → 36`；同目录 `FlutterAvifPlugin.java` 已改名 `.bak`（与 .kt 同包同类会 Redeclaration）。
  - `app/android/gradle.properties`：`kotlin.jvm.target.validation.mode=warning`（插件 Java 11/Kotlin 17 不一致）、`kotlin.incremental=false`、`kotlin.compiler.execution.strategy=in-process`（增量缓存的 mmap 文件在 Z: 盘上关不掉）。JVM 17 统一钉在 `app/android/build.gradle.kts` 的 subprojects 块。
- 桶凭证、PIN 等秘密绝不入库；不要在代码里写死任何 endpoint / AK / SK。
- 提交信息用英文、祈使句：`feat: ...` / `fix: ...` / `chore: ...`。

## 技术栈与约定

- Flutter stable，SDK 在 `D:/Code/opt/flutter`（不在系统 PATH，每个新 shell 需 `export PATH="/d/Code/opt/flutter/bin:$PATH"`）。
- 状态管理：**Riverpod**（`flutter_riverpod`，不引入 codegen，保持简单）。
- 本地库：**drift**。改表结构后必须跑：
  `cd app && dart run build_runner build --delete-conflicting-outputs`
  生成的 `*.g.dart` **提交入库**（单人项目不跑 CI）。
- 网络/S3：`minio` pub 包 + 自封装 `BucketClient`（见 `app/lib/features/bucket/`）。若 minio 包缺能力，在设计文档 §12 记录后自补 SigV4 请求层。
- 路由：`go_router`。
- 密钥存储：`flutter_secure_storage`；SK 用 PIN 派生密钥 AES-256-CBC + HMAC-SHA256 加密后落盘（`features/auth/pin_crypto.dart`）。
- 重试统一走 `lib/core/retry.dart` 的 `withRetry`（指数退避，`attempts` 含首次尝试；确定性失败用 `shouldRetry` 短路、不做无谓重试），不要各自手写重试循环。

## 分层与依赖方向

`lib/` 下分 `core/`（纯工具、错误类型）、`data/db/`（drift）、`features/<域>/`（repository + Riverpod providers + 薄 UI）。
依赖方向：UI → providers → repository → db / bucket。**纯逻辑（解析、合并、路径）必须与 IO 分离**，放在可被普通单测直接调用的位置——这是本项目测试策略的根基。
当前主要模块：`bucket/`（BucketClient 接口 + minio 实现 + 路径契约）、`library/`（索引同步 index_sync、事件日志 events_log、上传队列 upload_tasks、筛选查询 shelf_query、epub 导入）、`jm/`（站方 API 层）、`downloader/`（AVIF 管线、任务面板、人工审阅）、`reader/`（漫画/小说阅读器）、`auth/` + `settings/`。

## 验证清单（每次改动后）

```bash
subst Z: "D:\Code\comics&book"   # 新登录会话先映射
export PATH="/d/Code/opt/flutter/bin:$PATH"
cd /z/app
dart format --output=none --set-exit-if-changed .
flutter analyze            # 必须零告警
flutter test               # 必须全绿
```

全过才算完成；没过就修，不要把红灯留给用户。

## 常用命令

```bash
export PATH="/d/Code/opt/flutter/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs   # drift 代码生成
flutter test test/<file>                                   # 跑单个测试文件
```
