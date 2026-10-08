#!/usr/bin/env node
// render-svg-preview.mjs —— 把自包含 SVG 渲染成 PNG 预览，供人/模型目视核验
//
// 为什么需要：本知识库的 SVG 统一用 `:root` CSS 变量 + `prefers-color-scheme` 做浅深色
// 适配，而 librsvg（rsvg-convert）**不解析 CSS 自定义属性** —— 直接渲染会得到全黑或
// 缺色的图，容易被误判为"图坏了"。本脚本先把 `var(--x)` 展平成字面色值，再交给
// rsvg-convert 渲染，从而得到可读的浅色（及可选深色）预览。
//
// 用法：
//   node render-svg-preview.mjs <a.svg> [b.svg ...]
//   node render-svg-preview.mjs --out <dir> --width 1200 [--dark] [--keep-svg] <a.svg> [...]
//
// 输出：<out>/<name>.preview.png（--dark 时额外输出 <name>.preview.dark.png）
// 退出码：0 = 全部渲染成功；1 = 有渲染失败或缺少 rsvg-convert。

import { readFileSync, writeFileSync, mkdirSync, existsSync, unlinkSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { basename, join, resolve } from 'node:path';

function parseVars(block) {
  const out = new Map();
  for (const m of block.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) out.set(m[1], m[2].trim());
  return out;
}

function flatten(svg, dark) {
  const lightBlock = /:root\s*\{([^}]*)\}/.exec(svg);
  if (!lightBlock) return { svg, missing: ['(未找到 :root 变量定义)'] };
  const darkBlock = /@media\s*\(prefers-color-scheme:\s*dark\)\s*\{\s*:root\s*\{([^}]*)\}\s*\}/.exec(svg);
  const vars = parseVars(lightBlock[1]);
  if (dark && darkBlock) for (const [k, v] of parseVars(darkBlock[1])) vars.set(k, v);
  let out = darkBlock ? svg.replace(darkBlock[0], '') : svg;
  const missing = [];
  out = out.replace(/var\((--[\w-]+)(?:\s*,\s*([^)]+))?\)/g, (full, name, fallback) => {
    if (vars.has(name)) return vars.get(name);
    if (fallback) return fallback.trim();
    missing.push(name);
    return '#000000';
  });
  return { svg: out, missing: [...new Set(missing)] };
}

function main() {
  const argv = process.argv.slice(2);
  let outDir = '.', width = 1200, dark = false, keepSvg = false;
  const files = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--out') { outDir = argv[++i]; continue; }
    if (argv[i] === '--width') { width = Number(argv[++i]); continue; }
    if (argv[i] === '--dark') { dark = true; continue; }
    if (argv[i] === '--keep-svg') { keepSvg = true; continue; }
    files.push(argv[i]);
  }
  if (!files.length) {
    console.error('用法: node render-svg-preview.mjs [--out <dir>] [--width 1200] [--dark] [--keep-svg] <a.svg> [...]');
    process.exit(2);
  }
  const probe = spawnSync('rsvg-convert', ['--version'], { encoding: 'utf8' });
  if (probe.error || probe.status !== 0) {
    console.error('[PREVIEW-NO-RENDERER] 找不到 rsvg-convert。macOS 可用 `brew install librsvg` 安装；');
    console.error('  或改用任何支持 CSS 变量的浏览器打开 SVG 目视核验。');
    process.exit(1);
  }

  mkdirSync(resolve(outDir), { recursive: true });
  let failed = false;
  for (const f of files) {
    if (!existsSync(f)) { console.error(`[SVG-MISSING] ${f} 不存在`); failed = true; continue; }
    const raw = readFileSync(f, 'utf8');
    const variants = dark ? [['', false], ['.dark', true]] : [['', false]];
    for (const [suffix, isDark] of variants) {
      const { svg, missing } = flatten(raw, isDark);
      if (missing.length) console.error(`[PREVIEW-WARN] ${basename(f)} 缺少变量定义: ${missing.join(', ')}（已用黑色兜底）`);
      const name = basename(f).replace(/\.svg$/i, '');
      const tmpSvg = join(resolve(outDir), `${name}.preview${suffix}.svg`);
      const png = join(resolve(outDir), `${name}.preview${suffix}.png`);
      writeFileSync(tmpSvg, svg);
      const r = spawnSync('rsvg-convert', ['-w', String(width), tmpSvg, '-o', png], { encoding: 'utf8' });
      if (!keepSvg) unlinkSync(tmpSvg);
      if (r.status !== 0 || !existsSync(png)) {
        console.error(`[PREVIEW-FAIL] ${basename(f)}${suffix} 渲染失败: ${(r.stderr || '').trim()}`);
        failed = true;
        continue;
      }
      console.log(`${png}  (${isDark ? 'dark' : 'light'}, width=${width})`);
    }
  }
  process.exit(failed ? 1 : 0);
}

main();
