#!/usr/bin/env node
// verify-references.mjs —— 真源引用程序化校验（Grounding，防幻觉核心配套）。
//
// 用法：
//   node verify-references.mjs <kb_repo> <解读.md> [file2.md ...]
//     <kb_repo>  源码仓库根，作为所有 `文件:行号` 引用验证的锚点。
//     其余参数  解读文档（本 skill 本次产出的全部 md）。
//
// 行为：
//   - 提取每个展示引用 `[仓库相对路径/文件.ext:start-end]()`，并匹配其紧邻的指纹注释
//     `<!-- snippet-base64:<base64> -->` 或 `<!-- snippet:<原文> -->`。
//   - snippet 是模型从源码上下文逐字复制的可信指纹：base64 解码后整段在真实文件里搜索，
//     算出真实行号，与文档标注的 start-end 比对。
//   - 无指纹注释时降级为弱校验：路径存在、文件可读、行号区间未越界即通过（标记 WEAK），
//     提示补充指纹以获得精确行号验证。
//   - 路径一律 realpath + commonpath 防穿越，越出 kb_repo 直接标记 TRAVERSAL。
//
// 输出状态（TRAVERSAL / MISMATCH / UNVERIFIED 任一即非 0 退出码，不静默放过）：
//   [GROUNDER-OK]          指纹定位成功且行号吻合
//   [GROUNDER-MISMATCH]    指纹定位成功但行号有偏差，打印真实行号供覆盖
//   [GROUNDER-WEAK]        无指纹，弱校验通过（文件可读、行号未越界），建议补指纹
//   [GROUNDER-UNVERIFIED]  路径不存在 / 文件不可读 / 指纹定位失败（等价 [UNVERIFIED]）
//   [GROUNDER-TRAVERSAL]   路径越出 kb_repo，已阻止
//
// 与 check-mermaid.mjs 同理：本脚本是校验工具，只读不改解读文档。

import { readFileSync, realpathSync } from 'node:fs';
import { resolve, join, sep } from 'node:path';
import { stdin, stdout } from 'node:process';

// commonPath 等价实现：判断 target 是否等于或位于 repo 目录之下（纯字符串前缀，已 realpath）
function isWithinRoot(repo, target) {
  if (target === repo) return true;
  return target.startsWith(repo + sep);
}

// —— 展示引用：`[仓库相对路径/文件.ext:start-end]()` ——
// 路径部分可含字母数字 / . _ -；行号区间 start-end 为数字。
const CITATION_RE = /\[([^\][]+?\.\w+):(\d+)-(\d+)\]\(\)/g;

// —— 指纹注释：`<!-- snippet-base64:<b64> -->` 或 `<!-- snippet:<原文> -->` ——
const FINGERPRINT_RE = /<!--\s*snippet-base64:([A-Za-z0-9+/=]+)\s*-->|<!--\s*snippet:([\s\S]*?)-->/g;

// 引用行之后允许出现指纹注释的最大间隔（行数）
const FINGERPRINT_PROXIMITY = 2;

// —— snippet 在真实源码里定位真实行号（1-based），复用 SKILL.md 的 locate_snippet 思路 ——
function locateSnippet(text, snippet) {
  snippet = snippet.replace(/\n+$/, '');
  if (!snippet) return null;
  // ① 精确整段搜索
  const pos = text.indexOf(snippet);
  if (pos !== -1) {
    const start = text.slice(0, pos).split('\n').length;
    const end = start + snippet.split('\n').length - 1;
    return { start, end };
  }
  // ② 退化策略：以 snippet 首非空行为锚点
  const first = snippet.split('\n').map((l) => l.trim()).find((l) => l.length > 0);
  if (first) {
    const idx = text.indexOf(first);
    if (idx !== -1) {
      const start = text.slice(0, idx).split('\n').length;
      const end = start + snippet.split('\n').length - 1;
      return { start, end };
    }
  }
  return null;
}

// —— 路径校验：返回 { status: 'ok'|'traversal'|'missing', path, reason } ——
// 先 resolve 处理 `..` 并判断是否越出根（捕获明显穿越）；
// 再 realpath 处理符号链接；realpath 成功但越界 → traversal；文件不存在 → missing。
function safeResolve(repoRoot, relPath) {
  const repo = realpathSync(repoRoot);
  const resolved = resolve(join(repo, relPath));
  if (!isWithinRoot(repo, resolved)) {
    return { status: 'traversal', path: null, reason: '路径经 resolve 后越出 kb_repo 根' };
  }
  let real;
  try {
    real = realpathSync(resolved);
  } catch {
    return { status: 'missing', path: null, reason: '目标不存在或不可解析' };
  }
  if (!isWithinRoot(repo, real)) {
    return { status: 'traversal', path: null, reason: '路径经 realpath 解析后越出 kb_repo 根（符号链接逃逸）' };
  }
  return { status: 'ok', path: real, reason: null };
}

// —— 解析文档：返回 [{ path, docStart, docEnd, lineNo, fingerprint }] ——
function parseCitations(text) {
  const citations = [];
  let m;
  CITATION_RE.lastIndex = 0;
  while ((m = CITATION_RE.exec(text)) !== null) {
    citations.push({
      path: m[1],
      docStart: parseInt(m[2], 10),
      docEnd: parseInt(m[3], 10),
      lineNo: text.slice(0, m.index).split('\n').length,
      fingerprint: null,
    });
  }
  // 指纹注释列表
  const fingerprints = [];
  FINGERPRINT_RE.lastIndex = 0;
  while ((m = FINGERPRINT_RE.exec(text)) !== null) {
    const b64 = m[1];
    const raw = m[2];
    let snippet = null;
    if (b64) {
      try { snippet = Buffer.from(b64, 'base64').toString('utf8'); } catch { snippet = null; }
    } else if (raw !== undefined && !raw.includes('--')) {
      snippet = raw.trim();
    }
    if (snippet) {
      fingerprints.push({ lineNo: text.slice(0, m.index).split('\n').length, snippet });
    }
  }
  // 引用 ↔ 指纹配对：取"注释行号 ∈ [引用行, 引用行 + PROXIMITY]"的最先一个；已用即消耗。
  let fi = 0;
  for (const cit of citations) {
    while (fi < fingerprints.length && fingerprints[fi].lineNo < cit.lineNo) fi += 1;
    if (fi < fingerprints.length && fingerprints[fi].lineNo <= cit.lineNo + FINGERPRINT_PROXIMITY) {
      cit.fingerprint = fingerprints[fi].snippet;
      fi += 1;
    }
  }
  return citations;
}

function readSources(filePaths) {
  if (filePaths.length > 0) {
    return filePaths.map((p) => {
      const abs = resolve(p);
      try {
        return { name: abs, text: readFileSync(abs, 'utf8') };
      } catch (err) {
        throw new Error(`无法读取文件 ${p}: ${err.message}`);
      }
    });
  }
  return null;
}

async function main() {
  const args = process.argv.slice(2).filter((a) => a !== '--');
  if (args.length < 1) {
    console.error('用法：node verify-references.mjs <kb_repo> [解读.md ...]（解读.md 省略时从 stdin 读）');
    process.exit(2);
  }
  const repoRoot = resolve(args[0]);
  let repoReal;
  try { repoReal = realpathSync(repoRoot); } catch {
    console.error(`[verify-references] kb_repo 路径不存在或不可读：${repoRoot}`);
    process.exit(2);
  }

  const files = args.slice(1);
  let sources = readSources(files);
  if (!sources) {
    const chunks = [];
    stdin.on('data', (c) => chunks.push(c));
    await new Promise((res) => stdin.once('end', res));
    sources = [{ name: '<stdin>', text: chunks.join('') }];
  }
  let okCount = 0;
  let weakCount = 0;
  let mismatchCount = 0;
  let unverifiedCount = 0;
  let traversalCount = 0;

  for (const src of sources) {
    const citations = parseCitations(src.text);
    if (citations.length === 0) {
      console.log(`[${src.name}] 未发现 [path:start-end]() 引用`);
      continue;
    }
    console.log(`[${src.name}] 共 ${citations.length} 条引用`);
    for (const cit of citations) {
      const display = `${cit.path}:${cit.docStart}-${cit.docEnd}（文档第 ${cit.lineNo} 行）`;
      // 1) 路径校验（穿越 / 缺失 / 正常）
      const resolved = safeResolve(repoReal, cit.path);
      if (resolved.status === 'traversal') {
        traversalCount += 1;
        console.log(`[GROUNDER-TRAVERSAL] ${display} —— ${resolved.reason}`);
        continue;
      }
      if (resolved.status === 'missing') {
        unverifiedCount += 1;
        console.log(`[GROUNDER-UNVERIFIED] ${display} —— 文件不存在或不可读`);
        continue;
      }
      // 2) 读源文件
      let fileText;
      try { fileText = readFileSync(resolved.path, 'utf8'); } catch {
        unverifiedCount += 1;
        console.log(`[GROUNDER-UNVERIFIED] ${display} —— 文件存在但读取失败`);
        continue;
      }
      // 3) 定位：有指纹 → 精确验证；无指纹 → 弱校验
      if (cit.fingerprint) {
        const loc = locateSnippet(fileText, cit.fingerprint);
        if (!loc) {
          unverifiedCount += 1;
          console.log(`[GROUNDER-UNVERIFIED] ${display} —— snippet 在源码中定位失败，请人工复核（保留原样并标 [UNVERIFIED]）`);
          continue;
        }
        if (loc.start === cit.docStart && loc.end === cit.docEnd) {
          okCount += 1;
          console.log(`[GROUNDER-OK] ${display} —— 行号吻合`);
        } else {
          mismatchCount += 1;
          console.log(`[GROUNDER-MISMATCH] ${display} → 真实行号 ${loc.start}-${loc.end}，请用真实行号覆盖文档标注`);
        }
      } else {
        // 弱校验：文件可读 + 行号区间未越界
        const lineCount = fileText.split('\n').length;
        if (cit.docStart >= 1 && cit.docEnd <= lineCount) {
          weakCount += 1;
          console.log(`[GROUNDER-WEAK] ${display} —— 无指纹注释，仅弱校验通过（文件可读、行号未越界）；建议为该引用补充指纹以获得精确行号验证`);
        } else {
          unverifiedCount += 1;
          console.log(`[GROUNDER-UNVERIFIED] ${display} —— 无指纹注释且行号区间越界文件行数（${lineCount} 行），请人工复核`);
        }
      }
    }
  }

  console.log(`\n校验结果：OK=${okCount} WEAK=${weakCount} MISMATCH=${mismatchCount} UNVERIFIED=${unverifiedCount} TRAVERSAL=${traversalCount}`);
  if (traversalCount > 0) {
    console.log('存在路径穿越，请立即修复（可能是幻觉路径或漏了防穿越）。');
    process.exitCode = 2;
  } else if (mismatchCount > 0 || unverifiedCount > 0) {
    console.log('存在需人工复核的引用：MISMATCH 用真实行号覆盖；UNVERIFIED 保留原样并标 [UNVERIFIED] 供复核。');
    process.exitCode = 1;
  } else {
    console.log('全部引用经程序校验通过。');
    process.exitCode = 0;
  }
  stdout.write('', () => process.exit());
}

main().catch((err) => {
  console.error(err.message);
  process.exit(2);
});
