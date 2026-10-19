import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { loadPayload } from '../vendor/codex-dynamic-skin/scripts/injector.mjs';

const imageExtensions = new Set(['.jpg', '.jpeg', '.png', '.webp']);
const videoExtensions = new Set(['.mp4', '.webm']);

// Only declarative local media enters the upstream renderer. No user scripts or ZIPs.
export async function prepareTheme(source, stateRoot) {
  if (!path.isAbsolute(source) || source.startsWith('\\\\') || /^https?:/i.test(source)) {
    throw new Error('请选择本机磁盘上的壁纸文件。');
  }
  const extension = path.extname(source).toLowerCase();
  const video = videoExtensions.has(extension);
  if (!video && !imageExtensions.has(extension)) throw new Error('壁纸支持 PNG、JPEG、WebP、MP4、WebM。');
  const stat = await fs.stat(source);
  const limit = (video ? 128 : 10) * 1024 * 1024;
  if (!stat.isFile() || stat.size < 1 || stat.size > limit) {
    throw new Error(`壁纸文件须非空，图片最多 10 MB，视频最多 128 MB。`);
  }
  const sourceBytes = await fs.readFile(source);
  if (sourceBytes.length > limit) throw new Error('读取期间素材大小发生变化。');
  const hash = createHash('sha256').update(sourceBytes).digest('hex');
  const themesRoot = path.join(stateRoot, 'themes');
  await fs.mkdir(themesRoot, { recursive: true });
  const filename = `wallpaper${extension}`;
  const theme = {
    schemaVersion: 1, id: `conan-${hash.slice(0, 16)}`, name: '柯南 · 深蓝之夜',
    brandSubtitle: 'CONAN · NIGHT EDITION', tagline: '让灵感在夜色中浮现。',
    projectPrefix: '选择项目 · ', projectLabel: '选择项目', statusText: 'READY TO CREATE',
    quote: 'EVERY DETAIL COUNTS', image: filename, appearance: 'dark',
    art: { focusX: 0.76, focusY: 0.5, safeArea: 'left', taskMode: 'ambient' },
    media: { type: video ? 'video' : 'image', playbackRate: 1, opacity: 1 },
    palette: { accent: '#e54d61' },
    colors: {
      background: '#071225', panel: '#0b1b33', panelAlt: '#102541',
      accent: '#e54d61', accentAlt: '#ff8391', secondary: '#74c3ed',
      highlight: '#283b68', text: '#eff5ff', muted: '#aabbd1', line: 'rgba(116,195,237,.22)',
    },
  };
  const themeJson = JSON.stringify(theme, null, 2);
  const themeCss = '[data-ds-part="composer"] { border-color: rgba(116,195,237,.22); }\n';
  const cacheKey = createHash('sha256').update(sourceBytes).update(themeJson).update(themeCss).digest('hex');
  const themeDirectory = path.join(themesRoot, `conan-${cacheKey}`);
  try {
    const cached = await fs.lstat(themeDirectory);
    if (!cached.isDirectory() || cached.isSymbolicLink()) throw new Error('主题缓存路径异常，请检查本地缓存目录。');
    const [json, css, media] = await Promise.all([
      fs.readFile(path.join(themeDirectory, 'theme.json'), 'utf8'),
      fs.readFile(path.join(themeDirectory, 'theme.css'), 'utf8'),
      fs.readFile(path.join(themeDirectory, filename)),
    ]);
    if (json !== themeJson || css !== themeCss || !media.equals(sourceBytes)) throw new Error('主题缓存已改变，请检查本地缓存目录。');
    const loaded = await loadPayload(themeDirectory);
    return { themeDirectory, mediaType: loaded.mediaType, themeId: theme.id };
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    // An existing incomplete directory must not be silently overwritten.
    if (await fs.lstat(themeDirectory).then(() => true, () => false)) throw new Error('主题缓存不完整，请检查本地缓存目录。');
  }
  const staging = await fs.mkdtemp(path.join(themesRoot, '.staging-'));
  try {
    await fs.writeFile(path.join(staging, filename), sourceBytes, { flag: 'wx' });
    await fs.writeFile(path.join(staging, 'theme.json'), themeJson);
    await fs.writeFile(path.join(staging, 'theme.css'), themeCss);
    // Upstream checks media signatures, image dimensions, containment and Safe CSS.
    const loaded = await loadPayload(staging);
    await fs.rename(staging, themeDirectory);
    return { themeDirectory, mediaType: loaded.mediaType, themeId: theme.id };
  } catch (error) {
    // staging came directly from mkdtemp beneath our own themes directory.
    const relative = path.relative(path.resolve(themesRoot), path.resolve(staging));
    if (relative && !relative.startsWith('..') && !path.isAbsolute(relative)) {
      await fs.rm(staging, { recursive: true, force: true });
    }
    throw error;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [source, stateRoot] = process.argv.slice(2);
    if (!source || !stateRoot || !path.isAbsolute(stateRoot)) throw new Error('需要素材路径与本地状态目录。');
    console.log(JSON.stringify(await prepareTheme(source, stateRoot)));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
