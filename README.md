# 漫读 · 漫画小说资源管理

单人自用的漫画 + 小说阅读与管理应用。无服务端，App 经 SigV4 直连私有 S3 兼容桶（OSS / COS / R2 / MinIO），本地 SQLite 优先检索与阅读。

- 设计文档：[docs/design.md](docs/design.md)
- Flutter 工程：[app/](app/)

## 本机工具链状态

| 工具 | 状态 |
|---|---|
| Flutter SDK | `D:/Code/opt/flutter`（stable 3.47.5，git clone） |
| Visual Studio（Windows 桌面构建） | ❌ 未安装，`flutter run -d windows` 不可用 |
| Android SDK | ❌ 未安装，`flutter run` 到真机/模拟器不可用 |

当前可执行的验证：`flutter analyze`、`flutter test`、`dart format`。
真机/桌面运行前需补装：Visual Studio（含「使用 C++ 的桌面开发」工作负载）和/或 Android Studio（SDK + 许可接受）。

## ⚠️ 目录名含 `&`，测试必须经 Z: 盘符跑

仓库路径 `D:\Code\comics&book` 中的 `&` 会撑爆 Flutter 原生资产钩子拼出的
cmd 命令行（`dart compile kernel --packages=D:\Code\comics&book\...` 在 `&` 处截断）。
**从真实路径直接跑 `flutter test` 必然失败**。解决：用 subst 映射后从 Z: 跑。

```bash
subst Z: "D:\Code\comics&book"     # 每个新登录会话执行一次
export PATH="/d/Code/opt/flutter/bin:$PATH"

cd /z/app
flutter analyze      # 零告警
flutter test         # 全绿（28 个用例）
```

`flutter analyze` 从 D: 路径跑没有问题，只有 test/run 涉及钩子构建。

## 常用命令

```bash
export PATH="/d/Code/opt/flutter/bin:$PATH"   # 每个新 shell 都需要
cd /z/app                                      # 测试/构建经 Z:
dart run build_runner build --delete-conflicting-outputs   # drift 代码生成
```

## 路线图

见设计文档 §11。当前进度：**M1 桶链路骨架 ✅**（凭证 + PIN、S3 封装、`_index` 增量同步、本地 drift 库）。

后续：M2 阅读器骨架 → M3 漫画完整 → M4 小说完整 → M5 书源引擎 → M6 追更与归档 → M7 打磨。
