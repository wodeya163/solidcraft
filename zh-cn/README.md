# 中文定制版交付目录

本目录集中存放中文版新增内容，**不改动上游同名文件**，方便以后同步 `tangency-labs/solidcraft`。

```
zh-cn/
├── README.md                         本文件
├── i18n/
│   ├── build_zh_cn.py                双语资源生成脚本（幂等）
│   ├── zh-CN.json                    完整简体中文语言包（8018 条）
│   ├── en-US.json                    对应英文原版（8018 条）
│   └── 对照表.csv                    id / 英文 / 中文
├── docs/
│   ├── 安装与自动更新.zh-CN.md      安装、中文界面、自动更新、验证清单
│   ├── 构建说明.zh-CN.md            本地打包 / 源码编译 / 云端发布
│   └── 源码中文化说明.zh-CN.md      中英对照范围与补译规则
└── packaging/windows/
    ├── package-zh-cn.ps1             中文 MSI 打包脚本
    ├── solidcraft.zh-cn.wxs          WiX v5 中文安装定义
    ├── solidcraft.zh-cn.wxl          中文安装向导字符串
    └── updater/
        ├── 检查更新.ps1              远程最新版检查 / 校验 / 升级
        ├── 写入中文配置.ps1          预置简体中文界面偏好
        ├── 启动中文版.ps1            中文启动器（启动 + 后台检查）
        └── 注册每日自动更新.ps1      每日计划任务
```

## 关键约定

- 更新源：`https://api.github.com/repos/wodeya163/solidcraft/releases/latest`
- 稳定资产名：`solidcraft-windows-x64.msi`、`solidcraft-windows-x64-portable.zip`、`SHA256SUMS.txt`、`latest.json`
- 发布标签必须是稳定三段版本（如 `v0.48.2`），内置更新器才会把它当作可升级目标
- 所有 `.ps1` 以 UTF-8 with BOM 保存，兼容 PowerShell 5.1 与 7.x
- 中文语言包随安装版附带 `中文语言包.json`（仅作交付存档；程序实际读取编译进二进制的 locale）

## 快速开始

```powershell
# 打包（本机无需 Rust）
pwsh zh-cn/packaging/windows/package-zh-cn.ps1 -PortableZip <官方便携版.zip>

# 云端编译并发布
gh workflow run release-zh-cn.yml -f version=0.48.2 -f publish=true
```

根目录的 `README.zh-CN.md` 是面向使用者的中文说明。
