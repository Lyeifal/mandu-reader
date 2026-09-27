# AGENTS.md — 漫读项目代理指南

## 项目是什么

单人自用的漫画/小说阅读管理 Flutter 应用。无服务端，直连私有 S3 兼容桶；本地 SQLite（drift）优先检索与阅读。架构与设计见 [docs/design.md](docs/design.md)，先读它再动手。

## 硬约束

- 仓库根目录名含 `&`（`D:\Code\comics&book`），**Flutter 工程在 `app/` 子目录**。bash 命令中涉及该路径必须加引号；不要试图把工程放根目录。
- 本机无 Visual Studio / Android SDK：验证手段只有 `flutter analyze` 和 `flutter test`。不要声称跑过真机。
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

## 分层与依赖方向

`lib/` 下分 `core/`（纯工具、错误类型）、`data/db/`（drift）、`features/<域>/`（repository + Riverpod providers + 薄 UI）。
依赖方向：UI → providers → repository → db / bucket。**纯逻辑（解析、合并、路径）必须与 IO 分离**，放在可被普通单测直接调用的位置——这是本项目测试策略的根基。

## 验证清单（每次改动后）

```bash
cd app
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
