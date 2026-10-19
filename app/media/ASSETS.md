# 默认素材

2026-10-18，使用内置 Image Generation 工具生成壁纸，再用本地 FFmpeg 编码为视频。

- `wallpaper.png`：1672×941，深蓝夜景、右侧柯南人物、红色蝴蝶结，左侧保留阅读留白。
- `startup.mp4`：1920×1080，H.264，30 fps，4.8 秒，静音；固定镜头、夜雾流动、城市灯光明灭、蓝色微光与镜片依次扫光，结尾渐变至 `#060d18`。
- `wallpaper-loop.mp4`：1920×1080，H.264，30 fps，8 秒，静音；往返微推进，可循环。

开场保留插画人物，并在固定画面上合成独立环境与光效，人物没有逐帧肢体动画。可在设置中替换成自己的视频或 GIF。可选循环壁纸仍使用原有微推进效果。

默认使用静态壁纸。需要动态背景时，在界面壁纸选择器中选择 `wallpaper-loop.mp4`。

生成提示词：

> Wide cinematic Detective Conan wallpaper. Conan Edogawa on the rightmost quarter, round glasses, blue jacket and red bow tie, nighttime Tokyo rooftop, deep navy and midnight blue, cool cyan rim light, delicate glint on glasses. Left 65% calm, dark, low contrast for readable application text. Refined anime illustration. No software UI, text, logos, watermark, extra characters or weapons.

完整提示与构建滤镜保存在 `docs/ASSET_BUILD.md`。素材保留为项目资源；不表述为官方素材或官方合作。
