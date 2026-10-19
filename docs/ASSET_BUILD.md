# 素材构建记录

日期：2026-10-18。壁纸使用内置 Image Generation，非 CLI/API 模式。

完整生成提示：

```text
Use case: stylized-concept. Generate a polished wallpaper asset for a Windows coding workspace with a Detective Conan theme. Wide cinematic landscape 16:9. Conan Edogawa, recognizable boy detective with round glasses, blue suit jacket and bright red bow tie, stands on the rightmost quarter of the frame, waist-up, thoughtful confident expression, looking toward the left. Nighttime Tokyo rooftop and distant city lights, deep navy and midnight blue, delicate cool cyan rim lighting, a tiny sharp glint on glasses and red bow tie as the only warm focal accents. Elegant anime illustration, crisp clean linework, refined atmospheric background, restrained detail. Keep the left 65 percent very dark, calm, and low-contrast for readable real application text. Do not draw software UI, windows, frames, buttons, logos, letters, words, watermarks, or fake screenshot elements. Pure background artwork, not a UI mockup. No extra characters, no weapon. Composition must keep Conan's face fully visible with margin at top and right.
```

旧开场视频滤镜（已替换；旧视频备份随开发缓存清理，不再随项目保留）：

```text
scale=3344:1882,zoompan=z='1+0.018*on/119':x='iw-iw/zoom':y='(ih-ih/zoom)/2':d=120:s=1920x1080:fps=30,fade=t=in:st=0:d=0.4,fade=t=out:st=3.5:d=0.5
```

当前开场由 `scripts/Build-AtmosphereIntro.py` 逐帧合成：固定画面、不做 zoompan，144 帧、30fps、4.8 秒。薄雾独立流动，建筑实际亮点产生渐变明灭，蓝色微光缓慢漂移，两个镜片依次扫过一次反光。0–0.65 秒从深色出现，3.9–4.75 秒渐变至启动背景 `#060d18`。人物保持原画，没有生成肢体动画。

构建需要 Pillow、NumPy 和 FFmpeg，仅构建时使用；运行时不需要 Python 或 FFmpeg。运行 `python scripts/Build-AtmosphereIntro.py --ffmpeg <ffmpeg.exe 的绝对路径>`。固定随机种子 20261018；H.264、CRF19、yuv420p、faststart、无音轨。替换之前完整解码验证，并保留旧开场备份。构建报告和检查帧保存在 `.cache/atmosphere-intro/`。

循环壁纸滤镜（240 帧、30 fps、H.264、无音轨）：

```text
scale=3344:1882,zoompan=z='1+0.008*(1-cos(2*PI*on/239))/2':x='iw-iw/zoom':y='(ih-ih/zoom)/2':d=240:s=1920x1080:fps=30
```

FFmpeg 仅用于本机素材构建，不参与启动器运行或随项目分发。滤镜依据 [FFmpeg 官方文档](https://ffmpeg.org/ffmpeg-filters.html#zoompan)。编码选项为 `-pix_fmt yuv420p -movflags +faststart -an`。
