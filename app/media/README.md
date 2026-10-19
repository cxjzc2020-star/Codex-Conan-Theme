# 放入你的柯南素材

默认附带 `startup.mp4`、`wallpaper.png`。源码包另含可选的 `wallpaper-loop.mp4`；精简的 Windows 使用包只带默认素材。可运行本目录上一级的 `ConanLauncher.exe --settings` 选择电脑任意位置的素材，不必改文件名。

若直接放在本目录，启动器会自动识别：

- `startup.mp4` 或 `startup.gif`：启动时播放一次，默认静音，最长 6 秒，可调整为 1–30 秒。
- `wallpaper.jpg`、`wallpaper.png`、`wallpaper.webp`：静态界面壁纸。
- `wallpaper.mp4` 或 `wallpaper.webm`：界面内静音循环的动态壁纸。

同时存在时按上述启动器代码中的格式优先级选取；推荐只保留每类一份。

开场视频建议 3–6 秒、横屏 16:9、H.264 编码 MP4、1080p。GIF 建议控制尺寸和帧数。
壁纸建议 1920×1080，人物放右侧，为左侧栏和文字留空间。
壁纸图片最大 10 MB，壁纸视频最大 128 MB；开场视频和 GIF 最大 150 MB。

内置素材的说明见 [ASSETS.md](ASSETS.md)。清空素材会记住选择，不会在下次打开时自动恢复；“恢复内置素材”可以重新启用默认资源。
除内置文件外，本目录的个人素材默认被 Git 忽略。
