# 发布到 GitHub

## 准备

仓库建议命名 `codex-conan-theme`。源码和运行包均不包含个人配置、账号、日志、缓存、官方应用或 Node 运行时。生成的同人素材与项目代码授权不同；发布前确认素材可分发，或者换成自有素材并重新检查。

## 构建

1. 更新 `package.json`、`src/Launcher.cs` 的版本及 CHANGELOG.md。
2. 运行 `scripts/Verify.ps1`；装有 Codex 的本机另跑 `tests/Test-Manage.ps1`、`tests/Test-GatedStartup.ps1`、`tests/Test-WarmResume.ps1`。
3. 运行 `scripts/Build-Release.ps1`。默认输出 `dist/`；为避免误覆盖，已有同名 ZIP 时会停止。可传 `-OutputDirectory` 指定新输出目录。
4. 运行 `tests/Test-Release.ps1 -Directory dist`，检查清单、文件哈希、包内路径、公开文件和入口。

输出：Windows 使用包、Source 源码包、SHA256SUMS.txt 和不含本机路径的 release-manifest.json。压缩包内部也附逐文件 SHA256SUMS.txt。使用包不带测试、编译工具或开发诊断；源码包带完整开发文件和 CI。

## 上传

在 GitHub 创建空仓库，将 **Source ZIP 解压后的内容**作为仓库根目录上传或提交。不要把整个本机工作目录、ZIP 自身或 dist 目录提交进去。Source 包按公开文件清单生成，排除了本机历史诊断与旧修复工具。

创建与版本一致的 Release，将 Windows ZIP 和 SHA256SUMS.txt 作为附件；可同时附 Source ZIP 和 release-manifest.json。发布说明写明已验证的 Codex 版本、运行环境和已知限制。GitHub Actions 只做基础验证，不能代替真实应用启动检查。

本脚本只在本机构建，不会自动创建 GitHub 仓库、推送代码或发布 Release。