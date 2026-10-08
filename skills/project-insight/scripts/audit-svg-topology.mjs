#!/usr/bin/env node
// audit-svg-topology.mjs —— SVG 架构图的「边拓扑」审计
//
// 用途：手绘或子代理生成的 SVG 有一个稳定失败模式——**看起来对、边连错了**
// （缺边/多边/分支挂到错的节点），而文字标签全都正确，缩略图看不出、渲染也不报错。
// 本脚本把节点与连线解析出来，逐条打印「起点节点 → 终点节点」，供与期望边清单比对。
// 这是目前唯一能程序化发现该类错误的手段。
//
// 用法：
//   node audit-svg-topology.mjs <a.svg> [b.svg ...]
//   node audit-svg-topology.mjs --expect <expected.txt> <a.svg>
//   node audit-svg-topology.mjs [--tolerance 6] [--strict] [--json] <a.svg> [...]
//
// 期望清单格式（每行一条，`#` 起头为注释，`->` 两侧为节点标签）：
//   客户端上传文档 -> 原文落对象存储
//
// 退出码：0 = 端点全部贴合且（若给了期望清单）完全一致；1 = 存在悬空端点或期望不符。
//
// 判定口径：
//   - 节点：class 含 `node` 的 rect / polygon / polyline / path / ellipse / circle；
//           其标签取盒内**最靠上**的文本（通常是主标签行），没有文本时记 `?`
//   - 锚点 = 节点盒 ∪ **独立文字锚点**（如「起点」「终点」「终态」这类标签式箭头端点）；
//     端点贴合任一锚点即算合法，所以标签式画法不会误报
//   - 连线：class 含 `edge` 的 path；起点 = 路径首个坐标，终点 = 末尾坐标
//   - 端点与最近锚点距离 > 阈值（默认 6px，可用 --tolerance 调整）视为悬空
//   - 无标签且与某个有标签形状重叠的形状（如圆柱体顶面椭圆）按装饰忽略
//
// 已知限制：不解析 `transform` 与嵌套坐标系；如存在 transform，节点盒与端点会落在不同
// 坐标系里，结果不可信（脚本会就此告警）。

import { readFileSync, existsSync } from 'node:fs';
import { basename } from 'node:path';

const TOL = 6;
const CMD_RE = /[MLHVAZmlhvaz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/g;

function attr(attrs, name) {
  const m = new RegExp(`\\b${name}\\s*=\\s*"([^"]*)"`).exec(attrs);
  return m ? m[1] : null;
}

// —— 路径点序列（只追踪端点，弧线取终点，够用于包围盒与端点判定）——
function walkPath(d) {
  const toks = d.match(CMD_RE) || [];
  let x = 0, y = 0, sx = 0, sy = 0, cmd = null, rel = false;
  const pts = [];
  let i = 0;
  while (i < toks.length) {
    const t = toks[i];
    if (/^[A-Za-z]$/.test(t)) { cmd = t.toUpperCase(); rel = t !== cmd; i++; continue; }
    const nums = [];
    while (i < toks.length && !/^[A-Za-z]$/.test(toks[i])) { nums.push(Number(toks[i])); i++; }
    if (cmd === 'M' || cmd === 'L') {
      for (let k = 0; k + 1 < nums.length; k += 2) {
        x = rel ? x + nums[k] : nums[k];
        y = rel ? y + nums[k + 1] : nums[k + 1];
        if (cmd === 'M' && k === 0) { sx = x; sy = y; }
        pts.push([x, y]);
      }
    } else if (cmd === 'H') {
      for (const v of nums) { x = rel ? x + v : v; pts.push([x, y]); }
    } else if (cmd === 'V') {
      for (const v of nums) { y = rel ? y + v : v; pts.push([x, y]); }
    } else if (cmd === 'A') {
      for (let k = 0; k + 6 < nums.length; k += 7) {
        x = rel ? x + nums[k + 5] : nums[k + 5];
        y = rel ? y + nums[k + 6] : nums[k + 6];
        pts.push([x, y]);
      }
    } else if (cmd === 'Z') {
      x = sx; y = sy; pts.push([x, y]);
    }
  }
  return pts;
}

function bboxOf(tag, attrs) {
  const num = (n) => { const v = attr(attrs, n); return v === null ? NaN : Number(v); };
  if (tag === 'rect') {
    const [x, y, w, h] = [num('x'), num('y'), num('width'), num('height')];
    return [x || 0, y || 0, w, h].some(Number.isNaN) ? null : [x, y, w, h];
  }
  if (tag === 'ellipse' || tag === 'circle') {
    const cx = num('cx'), cy = num('cy');
    const rx = tag === 'circle' ? num('r') : num('rx');
    const ry = tag === 'circle' ? num('r') : num('ry');
    if ([cx, cy, rx, ry].some(Number.isNaN)) return null;
    return [cx - rx, cy - ry, 2 * rx, 2 * ry];
  }
  if (tag === 'polygon' || tag === 'polyline') {
    const raw = attr(attrs, 'points');
    if (!raw) return null;
    const v = raw.match(/-?(?:\d+\.?\d*|\.\d+)/g)?.map(Number) || [];
    if (v.length < 4) return null;
    const xs = v.filter((_, i) => i % 2 === 0), ys = v.filter((_, i) => i % 2 === 1);
    return [Math.min(...xs), Math.min(...ys), Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys)];
  }
  if (tag === 'path') {
    const d = attr(attrs, 'd');
    if (!d) return null;
    const pts = walkPath(d);
    if (!pts.length) return null;
    const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
    return [Math.min(...xs), Math.min(...ys), Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys)];
  }
  return null;
}

function distToBox(box, px, py) {
  const [x, y, w, h] = box;
  const dx = Math.max(x - px, 0, px - (x + w));
  const dy = Math.max(y - py, 0, py - (y + h));
  return Math.hypot(dx, dy);
}

function parseSvg(svg) {
  const nodes = [];
  const tagRe = /<(rect|polygon|polyline|path|ellipse|circle)\b([^>]*?)\/?>/g;
  let m;
  while ((m = tagRe.exec(svg))) {
    const cls = attr(m[2], 'class') || '';
    // 标准写法是 class 含 node；同时兼容历史写法——只写了填充语义类名
    // （如标记圆 class="neutral"、漏掉 node），否则起点/终态这类标记会被漏判为"端点悬空"
    const isNode = /(^|\s)node(\s|$)/.test(cls)
      || /(^|\s)(neutral|input|process|storage|external|risk)(\s|$)/.test(cls);
    if (!isNode) continue;
    const box = bboxOf(m[1], m[2]);
    if (box) nodes.push({ box, label: '?' });
  }
  const texts = [];
  const tRe = /<text\b([^>]*)>([\s\S]*?)<\/text>/g;
  while ((m = tRe.exec(svg))) {
    const x = Number(attr(m[1], 'x') ?? NaN), y = Number(attr(m[1], 'y') ?? NaN);
    const content = m[2].replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
    if (content && !Number.isNaN(x) && !Number.isNaN(y)) {
      texts.push({ x, y, text: content, cls: (attr(m[1], 'class') || '').split(/\s+/)[0], attrs: m[1] });
    }
  }
  const usedTexts = new Set();
  for (const n of nodes) {
    const [x, y, w, h] = n.box;
    const inside = texts.filter((t) => t.x >= x - 4 && t.x <= x + w + 4 && t.y > y + 8 && t.y < y + h + 4);
    if (inside.length) {
      inside.sort((a, b) => (a.y - b.y) || (b.text.length - a.text.length));
      n.label = inside[0].text;
      usedTexts.add(inside[0]);
    }
  }
  // 第二遍：盒内没有文字的锚点（起点圆、终态双圈这类标记），取紧邻的说明文字作标签。
  // 只排除"已被别的锚点占用"的那些文字对象本身，因此两个终态标记可以共用同一条「终态」说明。
  for (const n of nodes.filter((n) => n.label === '?')) {
    const [x, y, w, h] = n.box;
    const cands = texts
      .filter((t) => !usedTexts.has(t))
      .filter((t) => t.x >= x - 40 && t.x <= x + w + 40 && t.y >= y - 34 && t.y <= y + h + 34)
      .map((t) => {
        const dx = Math.max(x - t.x, 0, t.x - (x + w));
        const dy = Math.max(y - t.y, 0, t.y - (y + h));
        return { t, d: Math.hypot(dx, dy) };
      })
      .filter((c) => c.d <= 26)
      .sort((a, b) => a.d - b.d);
    if (cands.length) { n.label = cands[0].t.text; usedTexts.add(cands[0].t); }
  }
  // 独立文字锚点：不在任何节点盒内的文字（标签式箭头端点，如「起点」「终点」）
  const fontSizes = parseFontSizes(svg);
  const txtBoxes = texts.map((t) => {
    const styleFs = /font-size\s*:\s*([\d.]+)px/.exec(attr(t.attrs, 'style') || '');
    const fs = Number(styleFs ? styleFs[1] : NaN) || fontSizes.get(t.cls) || 14;
    const mode = attr(t.attrs, 'text-anchor') || 'start';
    const w = textWidth(t.text, fs), h = fs * 1.25;
    const x0 = mode === 'middle' ? t.x - w / 2 : mode === 'end' ? t.x - w : t.x;
    return { box: [x0, t.y - fs * 0.85, w, h], label: t.text, isNode: false };
  });
  const standalone = txtBoxes.filter((t) => !nodes.some((n) => contains(n.box, t.box)));
  const anchors = [
    ...nodes.map((n) => ({ box: n.box, label: n.label, isNode: true })),
    ...standalone,
  ];
  const edges = [];
  const pRe = /<path\b([^>]*?)\/?>/g;
  while ((m = pRe.exec(svg))) {
    const cls = attr(m[1], 'class') || '';
    if (!/(^|\s)edge[\w-]*(\s|$)/.test(cls)) continue;
    const d = attr(m[1], 'd');
    if (!d) continue;
    const pts = walkPath(d);
    if (pts.length < 2) continue;
    edges.push({ start: pts[0], end: pts[pts.length - 1], dashed: /dashed/.test(cls) });
  }
  const vb = /viewBox\s*=\s*"([^"]*)"/.exec(svg);
  return { nodes, anchors, edges, viewBox: vb ? vb[1] : '?', hasTransform: /transform\s*=/.test(svg) };
}

// —— 文字盒估算（CJK 按 1 个字宽，拉丁按 0.55，空格按 0.3）——
function parseFontSizes(svg) {
  const map = new Map();
  const style = /<style[^>]*>([\s\S]*?)<\/style>/.exec(svg);
  if (!style) return map;
  for (const m of style[1].matchAll(/\.([\w-]+)\s*\{([^}]*)\}/g)) {
    const fs = /font-size\s*:\s*([\d.]+)px/.exec(m[2]);
    if (fs) map.set(m[1], Number(fs[1]));
  }
  return map;
}

function textWidth(s, fs) {
  let w = 0;
  for (const ch of s) {
    if (/[\u2e80-\u9fff\uff00-\uffef\u3000-\u303f]/.test(ch)) w += fs;
    else if (/\s/.test(ch)) w += fs * 0.3;
    else w += fs * 0.55;
  }
  return w;
}

function contains(outer, inner) {
  const [ox, oy, ow, oh] = outer, [ix, iy, iw, ih] = inner;
  const w = Math.min(ox + ow, ix + iw) - Math.max(ox, ix);
  const h = Math.min(oy + oh, iy + ih) - Math.max(oy, iy);
  if (w <= 0 || h <= 0) return false;
  return (w * h) / (iw * ih) > 0.5;
}

function nearest(nodes, [px, py]) {
  let best = null, bestKey = null;
  for (const n of nodes) {
    const d = distToBox(n.box, px, py);
    // 同距离时优先「有标签」的形状，其次取面积更小的（内层形状比外层分区更具体）
    const key = [d, n.label === '?' ? 1 : 0, n.box[2] * n.box[3]];
    const better = !bestKey
      || key[0] < bestKey[0] - 0.001
      || (Math.abs(key[0] - bestKey[0]) <= 0.001
        && (key[1] < bestKey[1] || (key[1] === bestKey[1] && key[2] < bestKey[2])));
    if (better) { best = n; bestKey = key; }
  }
  return { node: best, dist: bestKey ? bestKey[0] : Infinity };
}

function overlap(a, b) {
  const [ax, ay, aw, ah] = a, [bx, by, bw, bh] = b;
  return Math.min(ax + aw, bx + bw) > Math.max(ax, bx) && Math.min(ay + ah, by + bh) > Math.max(ay, by);
}

function parseExpect(path) {
  const out = [];
  for (const raw of readFileSync(path, 'utf8').split('\n')) {
    const s = raw.trim();
    if (!s || s.startsWith('#')) continue;
    const m = /^(.*?)\s*->\s*(.*)$/.exec(s);
    if (m) out.push([m[1].trim(), m[2].trim()]);
  }
  return out;
}

function main() {
  const argv = process.argv.slice(2);
  let expectFile = null, asJson = false, tol = TOL, strict = false;
  const files = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--expect') { expectFile = argv[++i]; continue; }
    if (argv[i] === '--json') { asJson = true; continue; }
    if (argv[i] === '--tolerance') { tol = Number(argv[++i]); continue; }
    if (argv[i] === '--strict') { strict = true; continue; }
    files.push(argv[i]);
  }
  if (!files.length) {
    console.error('用法: node audit-svg-topology.mjs [--expect <expected.txt>] [--tolerance 6] [--strict] [--json] <a.svg> [...]');
    process.exit(2);
  }
  const gapMax = Math.max(tol, 40);

  let failed = false;
  let hasIssue = false;
  const report = [];
  for (const f of files) {
    if (!existsSync(f)) { console.error(`[SVG-MISSING] ${f} 不存在`); failed = true; continue; }
    const svg = readFileSync(f, 'utf8');
    const { nodes, anchors, edges, viewBox, hasTransform } = parseSvg(svg);
    if (hasTransform) console.error(`[AUDIT-UNSUPPORTED] ${basename(f)} 含 transform：节点盒与端点不在同一坐标系，本文件结果不可信`);
    // 无标签且与某个有标签形状重叠的（如圆柱体的顶面椭圆、纯装饰底纹）不计入节点清单
    const decor = nodes.filter((n) => n.label === '?'
      && nodes.some((m) => m !== n && m.label !== '?' && overlap(n.box, m.box)));
    const display = nodes.filter((n) => !decor.includes(n));
    const pairs = [];
    const dangling = [];
    edges.forEach((e, idx) => {
      const s = nearest(anchors, e.start), t = nearest(anchors, e.end);
      const nm = (a) => (a.node ? (a.node.isNode ? a.node.label : `${a.node.label}（文字锚点）`) : '?');
      pairs.push([nm(s), nm(t), e.dashed]);
      const issue = (which, a, pt) => (a.dist <= tol ? null : {
        level: a.dist > gapMax ? 'error' : 'warn',
        msg: `${which} (${pt[0]},${pt[1]}) 距最近锚点「${nm(a)}」${a.dist.toFixed(1)}px`,
      });
      const issues = [issue('起点', s, e.start), issue('终点', t, e.end)].filter(Boolean);
      if (issues.length) dangling.push({ idx: idx + 1, from: nm(s), to: nm(t), issues });
      if (issues.some((i) => i.level === 'error' || strict)) hasIssue = true;
    });
    const item = { file: f, viewBox, nodes: display, decor: decor.length, edges: pairs, dangling };
    if (expectFile) {
      const exp = parseExpect(expectFile);
      const key = (p) => `${p[0]} -> ${p[1]}`;
      const got = pairs.map(key);
      item.expected = exp.map(key);
      item.missing = item.expected.filter((k) => {
        const i = got.indexOf(k);
        if (i === -1) return true;
        got.splice(i, 1);
        return false;
      });
      item.unexpected = got;
      if (item.missing.length || item.unexpected.length) failed = true;
    }
    if (dangling.length) item.gapCount = dangling.length;
    report.push(item);
  }

  if (asJson) { console.log(JSON.stringify(report, null, 2)); process.exit(failed || hasIssue ? 1 : 0); }

  for (const r of report) {
    console.log(`\n=== ${basename(r.file)}  viewBox="${r.viewBox}"  节点 ${r.nodes.length} 个 / 连线 ${r.edges.length} 条${r.decor ? `（另有 ${r.decor} 个无标签装饰形状已忽略）` : ''}`);
    console.log('节点: ' + r.nodes.map((n) => n.label).join(' | '));
    r.edges.forEach((p, i) => console.log(`  ${String(i + 1).padStart(3)}. ${p[0]} -> ${p[1]}${p[2] ? '  [虚线]' : ''}`));
    if (r.dangling.length) {
      console.log(`端点间隙（贴合阈值 ${tol}px；>${gapMax}px 记 [EDGE-DANGLING] 错误，其余记 [EDGE-GAP] 提示——标签式箭头可能是有意留白）：`);
      for (const d of r.dangling) {
        const tag = d.issues.some((i) => i.level === 'error') ? 'EDGE-DANGLING' : 'EDGE-GAP';
        console.log(`  - [${tag}] 第 ${d.idx} 条 ${d.from} -> ${d.to}`);
        for (const i of d.issues) console.log(`      ${i.msg}`);
      }
    }
    if (r.expected) {
      if (r.missing.length) console.log('缺少期望连线:\n' + r.missing.map((k) => '  - ' + k).join('\n'));
      if (r.unexpected.length) console.log('多出未列出的连线:\n' + r.unexpected.map((k) => '  - ' + k).join('\n'));
      if (!r.missing.length && !r.unexpected.length) console.log('与期望清单完全一致 ✓');
    }
  }
  console.log('');
  if (failed || hasIssue) {
    console.log('审计结果：存在 [EDGE-DANGLING] 端点未贴合，或与期望清单不符'
      + (strict ? '（--strict：提示级间隙也算失败）' : '')
      + '，请先修图再接入文档。');
    process.exit(1);
  }
  console.log('审计结果：端点全部贴合' + (expectFile ? '，且与期望清单一致' : '') + '。');
  process.exit(0);
}

main();
