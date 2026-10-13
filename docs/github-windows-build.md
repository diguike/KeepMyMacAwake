# GitHub Windows 打包与界面报告

2026-10-14 用户选择先用 GitHub 完成 Windows 测试、打包和界面报告，本地 Windows 环境以后再调研。本流程使用 GitHub 托管主机，无需在 Mac 安装虚拟机。

## 操作入口

进入仓库 → Actions → CI → Run workflow：

1. 选择要构建的分支，通常是 main。
2. scope 选 windows，仅执行 Windows x64 / ARM64 两个任务；all 会同时执行 Mac 与 Linux 回归。
3. 等待本次运行完成，在底部 Artifacts 下载结果。推送和 PR 也会自动执行完整检查。

每个架构有两个附件：

| 附件 | 内容 |
| --- | --- |
| keepmymacawake-win-x64-unsigned-preview / win-arm64-unsigned-preview | 自包含 ZIP、中文 EXE 安装器、SHA256SUMS.txt、build-info.json |
| keepmymacawake-win-x64-ui-and-test-report / win-arm64-ui-and-test-report | 核心 TRX、WPF 检查与图片、静默安装器检查报告 |

附件保留 14 天；它们是 CI 开发预览，不自动创建公开 Release。下载通常需要登录 GitHub。面向普通用户的长期下载应另行安排 Release 与签名。

## 在 Mac 看界面

解压 ui-and-test-report，打开 ui/index.html。报告包含：

- 14 项真实 ViewModel / WPF 注入检查的通过/失败结果。
- 首用、日常、夜间、运行中、上次结果、未开放合盖、设置七个界面状态。
- 浅色、深色、高对比资源预览，100%、125%、200% 三种图片输出比例，每个架构 63 张 PNG。
- 原始 report.json、源码提交、App 版本、运行器架构。

图片是 Windows 上真实 WPF 控件的离屏渲染，使用固定模拟数据，不是图片模型或 HTML 重画；不含系统标题栏。它们能帮助检查布局与主题，不能代替真实 DPI 切换、键盘/读屏、托盘、通知或交互验收。高对比项复用应用资源，未切换系统高对比设置。

## 自动检查

每个 Windows 架构使用原生主机（x64: windows-2025，ARM64: windows-11-arm），固定 .NET SDK 10.0.401 和 NSIS 3.13.0：

1. 完整构建、39 项核心测试、27 项协议/ABI/请求模拟检查。
2. 14 项 WPF 注入检查与界面渲染；绑定/渲染错误导致任务失败。
3. publish 自包含 ZIP，并用 PowerShell 调用同一 NSIS 源码生成 EXE。
4. 核对 ZIP 中每个文件、运行时/说明/许可证、PE 架构/GUI/asInvoker、服务排除及 EXE/ZIP SHA-256。
5. 在任务临时目录实际静默安装、运行无会话的打包更新入口、升级、卸载，核对属于本安装的登录项被移除、其他文件/其他安装的启动项保留。
6. 上传包、界面和测试报告；失败时仍上传已经生成的报告。

安装器检查只允许在一次性 GitHub Actions 环境执行，不用于本地用户系统。云端 Windows 以管理员运行且关闭 UAC，因此通过静默测试也不能作为普通用户权限/交互安装验收。App 未开放的合盖服务始终不进入包，不启动真实保活、不更改真实合盖策略。

workflow 只有 contents: read 权限；普通构建不会发布 Release、安装本地组件或读取签名凭据。使用官方 checkout / setup-dotnet / upload-artifact action。[运行器与权限说明](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)。

## 后续边界

真实锁屏、拔电、休眠/恢复、持续运行及物理合盖仍由 Windows 设备验收。用户已决定本地 Windows 方案后续再调研，本轮不安装虚拟机、不租云桌面。实际 CI 结果与下载运行链接记录在 status.md，失败日志不能当作已验收证据。
