#!/usr/bin/env node
// check-mermaid.mjs —— 用 mermaid.parse() 真解析校验 Markdown 里的所有 mermaid 代码块。
//
// 用法：
//   node check-mermaid.mjs <file.md> [file2.md ...]
//   # 未传参数时从 stdin 读入（配合 CI/管道）
//
// 行为：
//   - 提取每个 ```mermaid ... ``` 代码块，记录其在文件中的全局起止行号。
//   - 对每块调用 mermaid.detectType + mermaid.parse 做真实语法解析。
//   - 全部 OK 则以退出码 0 结束；任一失败打印 [MERMAID-ERROR] 并以非 0 退出码结束（不静默放过，类比引用定位失败的 [UNVERIFIED]）。
//
// 原理：mermaid 默认依赖 DOMPurify（需要 DOM）。此处注入最小 jsdom 垫片，
//       使 mermaid.parse() 能在纯 Node 下以真实解析器工作，而不必引入 puppeteer/Chromium。

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { stdin, stdout } from 'node:process';

import { JSDOM } from 'jsdom';

// —— DOM 垫片：让 mermaid 的 DOMPurify/安全层在 Node 下可运行 ——
// 注意：必须先在全局注入 window/document/navigator，再动态导入 mermaid，
//       否则 mermaid 顶层导入 DOMPurify 时拿不到 DOM，会在 parse 时报
//       「DOMPurify.sanitize is not a function」。
const dom = new JSDOM('', { pretendToBeVisual: true });
globalThis.window = dom.window;
globalThis.document = dom.window.document;
Object.defineProperty(globalThis, 'navigator', {
  value: dom.window.navigator,
  configurable: true,
  writable: true,
});

const mermaid = (await import('mermaid')).default;

mermaid.initialize({ startOnLoad: false, securityLevel: 'loose' });

// —— <br> 规范性 / 合法性 lint ——
// 目标：让长标签在预览下不挤成一长行（靠 <br> 在语义点断行），并统一换行写法。
// 判定为提示级 [MERMAID-WARN]，不计入失败 (exitCode)，避免误伤合法的图。
// 规范写法：换行一律用 `<br>`（无斜杠）——mermaid 官方文档与标准 HTML void element 的主流写法；
//   `<br/>` / `<br />` / `</br>` 虽也能解析渲染，但非主流，提示统一为 `<br>`。
// 规则：
//   ① 写法统一：检测 `<br/>` / `<br />` / `</br>` 等非规范形式，提示统一为 `<br>`。
//   ② 合法性：`<br>` 只应出现在引号包裹的节点标签内；edge/message 等裸文本行中的
//      `<br>` 不会被当作标签内换行处理，渲染行为不可预期，予以提示。
//   ③ 长标签拥挤预警：标签被 `<br>` 切开后，单段仍超过 40 字符（或整段无换行、
//      超过 40 字符）则提示在语义断点再补 `<br>`，以改善预览可读性。
function lintBr(block) {
  const warns = [];
  const lines = (block.text || '').split('\n');
  const gStart = block.globalStartLine;
  const push = (lineNo, msg) => {
    warns.push(`  → [MERMAID-WARN] 第 ${lineNo} 行（global ${gStart + lineNo - 1}）：${msg}`);
  };
  for (let i = 0; i < lines.length; i++) {
    const ln = lines[i];
    const brMatches = ln.match(/\s*<\/?\s*br(?:\s*\/?\s*)?>/gi);
    const hasLabelQuote = /"/.test(ln);
    // ① 写法统一 + ② 合法性：仅当本行确有 <br> 时才检查写法与合法位置
    if (brMatches) {
      // 非规范形式：带前导或尾随斜杠的 </br>、<br/>、<br />（含大小写变体）
      const nonstandard = ln.match(/(?:<\s*\/\s*br>|<\s*br\s*\/>)/gi);
      if (nonstandard) {
        push(i + 1, `检测到非规范写法 ${nonstandard.map((s) => s.trim()).join('、')}，请统一为 <br>（mermaid 官方文档与 HTML 主流写法，带斜杠形式虽可渲染但非主流）。`);
      }
      if (!hasLabelQuote) {
        push(i + 1, `${brMatches.join('、')} 出现在疑似非标签位置（该行无引号包裹的节点标签）。请只在引号包裹的节点标签内使用 <br>。`);
      }
    }
    // ③ 长标签拥挤预警：含 "<br>" 或未断行的长标签，按 <br> 切开后仍超过 40 字符，
    //   或整行标签未用 <br> 断行且过长 —— 均在语义断点提示再补 <br>
    const segments = ln
      .replace(/<\s*br(?:\s*\/?\s*)?>/gi, '\u0000')
      .split('\u0000')
      .map((s) => s.replace(/^.*?"/, '').replace(/".*$/, ''))
      .map((s) => s.trim())
      .filter((s) => s.length > 40);
    for (const seg of segments) {
      push(i + 1, `标签文本段「${seg.slice(0, 40)}…」超过 40 字符，预览下可能过宽，建议在语义断点补 <br> 换行。`);
    }
  }
  return warns;
}

// —— 从多行文本提取 mermaid 块，返回 [{ globalStartLine, text, rawBlockLine }] ——
// 支持两种围栏形态：普通 ```mermaid，以及块引用缩进的 > ```mermaid（围栏与内容行
// 都可带 > 前缀），内容行会去掉前导的 "> " 前缀再交给 mermaid 解析。
function extractMermaidBlocks(text) {
  const blocks = [];
  // 围栏行：可带可选缩进 + 可选 ">" 块引用前缀；内容在开栏与关栏之间贪婪捕获
  const re =
    /^[ \t]*>?[ \t]*```mermaid[ \t]*\r?\n([\s\S]*?)\r?\n[ \t]*>?[ \t]*```[ \t]*$/gm;
  let m;
  while ((m = re.exec(text)) !== null) {
    const raw = m[0];
    const startOffset = m.index;
    const globalStartLine = text.slice(0, startOffset).split('\n').length;
    const content = m[1]
      .split('\n')
      .map((ln) => ln.replace(/^\s*>?\s*/, '')) // 统一去掉 "> " 块引用前缀
      .join('\n');
    blocks.push({
      globalStartLine,
      text: content.replace(/\r?\n$/, ''),
      rawLineCount: raw.split('\n').length,
    });
  }
  return blocks;
}

// —— 读取输入：优先命令行文件，否则 stdin ——
async function readSources(filePaths) {
  if (filePaths.length > 0) {
    const out = [];
    for (const p of filePaths) {
      const abs = resolve(p);
      let text;
      try {
        text = readFileSync(abs, 'utf8');
      } catch (err) {
        throw new Error(`无法读取文件 ${p}: ${err.message}`);
      }
      out.push({ name: abs, text });
    }
    return out;
  }
  const chunks = [];
  stdin.on('data', (c) => chunks.push(c));
  await new Promise((res) => stdin.once('end', res));
  return [{ name: '<stdin>', text: chunks.join('') }];
}

async function main() {
  const files = process.argv.slice(2).filter((a) => a !== '--');
  const sources = await readSources(files);

  let failCount = 0;
  let warnCount = 0;
  let blockIndex = 0;

  for (const src of sources) {
    const blocks = extractMermaidBlocks(src.text);
    if (blocks.length === 0) {
      console.log(`[${src.name}] 未发现 mermaid 代码块`);
      continue;
    }
    for (const b of blocks) {
      blockIndex += 1;
      const startGlobal = b.globalStartLine;
      const endGlobal = startGlobal + b.rawLineCount - 1;
      let type = '?';
      try {
        type = mermaid.detectType(b.text);
      } catch {
        type = '?';
      }
      try {
        await mermaid.parse(b.text);
        console.log(
          `OK   [${src.name}:${startGlobal}-${endGlobal}] type=${type} #${blockIndex}`
        );
        // <br> 规范性 lint（提示级，不导致失败）
        const warns = lintBr(b);
        warnCount += warns.length;
        for (const w of warns) console.log(w);
      } catch (err) {
        failCount += 1;
        const msg = String((err && err.message) || err).trim();
        // mermaid 错误信息里的内部行号通常是「相对该块第 1 行」，换算为全局行号
        const lineMatch = msg.match(/line\s*(\d+)/i);
        const inner = lineMatch ? parseInt(lineMatch[1], 10) : null;
        const globalErrLine = inner ? startGlobal + inner - 1 : startGlobal;
        console.log(
          `[MERMAID-ERROR] [${src.name}:${startGlobal}-${endGlobal}] type=${type} #${blockIndex}`
        );
        console.log(`  → 报错位置（全局第 ${globalErrLine} 行）：${msg}`);
      }
    }
  }

  if (failCount > 0) {
    console.log(
      `\n校验结果：${failCount} 个 mermaid 块存在语法错误，请修复后重新运行；不保留渲染报错的图。${warnCount ? `（另有 ${warnCount} 条 [MERMAID-WARN] <br> 规范提示，见上）` : ''}`
    );
    process.exitCode = 1;
  } else {
    console.log(
      `\n校验结果：全部 mermaid 块语法通过。${warnCount ? `（含 ${warnCount} 条 [MERMAID-WARN] <br> 规范提示，见上）` : ''}`
    );
    process.exitCode = 0;
  }
  stdout.write('', () => process.exit());
}

main().catch((err) => {
  console.error(err.message);
  process.exit(2);
});
