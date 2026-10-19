# Codex · 柯南之夜

为 Windows Codex 添加视频开场、深蓝夜景壁纸和配色。启用一次，之后继续点击原来的 Codex 图标；运行恢复脚本即可撤下主题。

这是社区主题工具，与 OpenAI、《名侦探柯南》权利方无隶属或合作关系。不会修改 Codex 安装包。

<img width="2420" height="1489" alt="b3b6362cda2c9fdbbab6790d9ffad680" src="https://github.com/user-attachments/assets/20d863af-8f79-40ff-b6b8-270ce131ae53" />


## 使用

需要 Windows 10/11 x64、Microsoft Store 版 Codex、Node.js 22 或更新版本。启用器会优先寻找本机已有的 Node；缺少时请从 [Node.js 官网](https://nodejs.org/) 安装受支持版本。不需要管理员权限、Python、FFmpeg 或 npm install。

1. 下载 Windows 使用包，**完整解压**到准备长期保留的目录，不要直接在压缩包内运行。
2. 等 Codex 的任务结束，通过“文件 → 退出”完全退出应用。
3. 双击 `启用主题.cmd`。之后从桌面或开始菜单的 Codex 图标打开。

首次使用独立界面配置可能需要重新登录。推荐在 Codex 外观设置里选择深色，以匹配原生标题栏与主题。主题运行需要本地调试端口，该端口只监听本机。

**恢复：**双击 `恢复默认.cmd`。它会停止主题注入，恢复启用前的快捷方式，保留账号、聊天、项目、插件和个人设置。后台任务不会被强制结束；任务完成后通过“文件 → 退出”，再正常打开 Codex，完成恢复。恢复是撤销本项目的变更，不是重置或删除 Codex 数据。

## 启动效果

视频开场 → 暗色过渡与原生加载标志 → 壁纸由模糊变清晰 → 进入应用。

关闭窗口会保留 Codex 后台任务；再次打开恢复原窗口，不重播开场。Codex 完全退出后的冷启动才播放视频。启用和恢复均可重复执行。

仅接管当前用户的桌面及开始菜单入口。从商店、官方安装目录、未更新的任务栏固定图标或其他协议打开，可能绕过主题。官方应用更新也可能影响主题接入，见 [常见问题](docs/FAQ.md)。

## 自定义

Windows 使用包中运行 `app/ConanLauncher.exe --settings`，或双击该文件的快捷方式并添加 `--settings` 参数，可选择开场视频、壁纸和最长播放时间。源码目录中对应文件位于根目录。

- 开场：MP4 / GIF，默认静音，Esc 跳过。
- 壁纸：PNG / JPG / WebP，或 MP4 / WebM 动态壁纸。
- **网络兼容默认关闭。**仅在使用本机代理且首次聊天反复重连时，在设置窗口勾选“网络兼容”。它只向本次 Codex 子进程传递已启用的本机代理，不更改系统代理、证书或账号配置。完全退出后重启生效。

设置关闭窗口时自动保存。旧安装会保留已验证的网络兼容行为。更换壁纸后完全退出再打开。停止使用前先恢复默认，再移动或删除安装目录。

## 发布包与源码

Windows 使用包的顶层只有两个操作入口、说明和许可证，内部文件集中在 `app/`：

```text
Codex-Conan-Theme-v1.0.0-Windows/
├─ 启用主题.cmd
├─ 恢复默认.cmd
├─ README.md / LICENSE / THIRD_PARTY_NOTICES.md
├─ SHA256SUMS.txt
├─ docs/FAQ.md
└─ app/                 # 启动程序、脚本、主题引擎与素材
```

GitHub 源码目录保留 `src/`、`scripts/`、`tests/`、`vendor/`、`media/` 和开发文档；没有第三方 npm 依赖。源码版运行启用脚本时会在缺少 EXE 的情况下自动使用 Windows 自带 .NET Framework 编译器构建。

```powershell
# 基础验证
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts/Verify.ps1
# 在装有 Codex 的 Windows 上验证启用/恢复，不改真实快捷方式
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests/Test-Manage.ps1
# 构建 Windows 使用包及 GitHub 源码包
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts/Build-Release.ps1
```

构建结果在 `dist/`，不会被提交到 Git。`.github/workflows/check.yml` 提供基础自动检查；真实 Codex 集成检查需要本机安装应用。[架构](docs/ARCHITECTURE.md) · [验证记录](docs/TESTING.md) · [发布流程](docs/RELEASING.md)

## 配置与授权

本地配置、主题缓存、登录所需的界面配置、日志及快捷方式备份保存在 `%LOCALAPPDATA%/CodexConanLauncher/`，不会进入发布包。恢复不会删除这些用户数据，以便保留登录和后续重新启用。

项目自有代码采用 [MIT 许可证](LICENSE)。第三方代码保留各自许可证，见 [第三方说明](THIRD_PARTY_NOTICES.md)。MIT 授权不包含 OpenAI 品牌、官方图标或《名侦探柯南》角色权利。随附素材为生成的同人插画及其衍生视频，不能据此宣称获得角色或品牌授权；对外发布前请确认素材分发范围，也可换成自己的素材。
