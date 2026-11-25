# SolidCraft 中文版

SolidCraft 是一款用纯 Rust 编写的参数化三维 CAD 应用（桌面端 / 浏览器 / MCP 自动化）。
本仓库是 [tangency-labs/solidcraft](https://github.com/tangency-labs/solidcraft) 的中文定制分支，
在保留上游全部功能与英文原版资源的前提下，提供**默认简体中文界面、中文安装向导、中文文档和自动更新**。

> 上游许可：MIT OR Apache-2.0；品牌素材另见 `LICENSE-BRAND`。本分支沿用同一许可。

## 中文版做了什么

| 项目 | 说明 |
| --- | --- |
| 界面语言 | 默认 `zh`（简体中文）；共 8018 条界面文案，正式语言包 7764 条 + 共享语言包 254 条，中文覆盖率 100% |
| 双语资源 | `zh-cn/i18n/zh-CN.json`（中文）与 `en-US.json`（英文原版）成对保留，`对照表.csv` 可逐条比对 |
| 安装向导 | WiX v5 中文 MSI（欢迎、目录、进度、完成页中文），保留英文原版安装逻辑与升级码 |
| 自动更新 | 内置更新器指向 `wodeya163/solidcraft` 的 `releases/latest`；随包中文更新器负责已发布二进制的检查、校验与升级 |
| 中文文档 | 本文件、`zh-cn/docs/` 下的安装/构建/中文化说明 |
| 源码英文部分 | 源码注释沿用上游英文（便于同步上游）；界面文案、安装器、更新器、文档均已生成中文版 |

## 下载与安装（Windows x64）

| 文件 | 用途 | 稳定下载链接 |
| --- | --- | --- |
| `solidcraft-windows-x64.msi` | 本地安装版（推荐，中文向导） | https://github.com/wodeya163/solidcraft/releases/latest/download/solidcraft-windows-x64.msi |
| `solidcraft-windows-x64-portable.zip` | 绿色便携版（解压即用） | https://github.com/wodeya163/solidcraft/releases/latest/download/solidcraft-windows-x64-portable.zip |
| `SHA256SUMS.txt` | 发行校验表 | https://github.com/wodeya163/solidcraft/releases/latest/download/SHA256SUMS.txt |
| `latest.json` | 中文更新清单 | https://github.com/wodeya163/solidcraft/releases/latest/download/latest.json |

双击 MSI 安装；安装完成后开始菜单出现「SolidCraft 中文版」和「检查 SolidCraft 更新」。
详细说明见 [`zh-cn/docs/安装与自动更新.zh-CN.md`](zh-cn/docs/安装与自动更新.zh-CN.md)。

## 自动更新与远程关联

- 更新源固定为 `https://api.github.com/repos/wodeya163/solidcraft/releases/latest`（源码：`crates/ui-egui/src/update.rs` 的 `LATEST_API` / `RELEASE_PREFIXES`）。
- 发行版按稳定名附加安装包，使 `releases/latest/download/` 链接与内置更新器都能按名字找到文件。
- 每次从「SolidCraft 中文版」快捷方式启动都会后台检查；也可运行 `注册每日自动更新.ps1` 开启每日无人值守检查。
- 每次下载都会用同一发行版的 `SHA256SUMS.txt` 校验 SHA-256，校验失败即删除安装包、不改动现有安装。
- `SOLIDCRAFT_UPDATE_CHECK=0` 可关闭全部自动检查。

## 切换语言

「首选项 → 常规 → 语言」可切换为 `system`（跟随系统）、`en`（英文原版）或任意内置语言。
中文版只是把**默认值**改为 `zh`，不会覆盖用户已保存的语言选择。

## 从源码构建

```sh
# 上游原生构建（需要 Rust 1.99.1 与 MSVC）
cargo run --release -p solidcraft -- --sample
cargo xtask ci

# 中文安装版打包（可用官方便携版二进制，本机无需 Rust）
pwsh zh-cn/packaging/windows/package-zh-cn.ps1 -PortableZip <官方便携版.zip>
```

亦可用 `.github/workflows/release-zh-cn.yml` 在云端编译并发布。详见 [`zh-cn/docs/构建说明.zh-CN.md`](zh-cn/docs/构建说明.zh-CN.md)。

## 中文版文件索引

```
README.zh-CN.md                          本文件
zh-cn/
  README.md                             中文版交付说明
  i18n/                                 双语资源包 + 生成脚本 + 对照表
  docs/                                 安装 / 构建 / 中文化说明
  packaging/windows/                    中文 MSI 定义、wxl、打包脚本、更新器
.github/workflows/release-zh-cn.yml      云端编译 + 发布工作流
crates/ui-egui/src/update.rs             更新源改为本仓库
crates/ui-egui/src/prefs/fields/general.rs  默认语言 zh
assets/locales/zh.json                   补译 16 条残留英文文案
```

## 版本说明

`v0.48.2`（中文定制版第一版）基于上游 `v0.48.1` 的 Windows x64 二进制，加入中文增强层；
上游源码版本仍为 `0.48.0`，不改写 `Cargo.toml`，以便继续同步上游。
