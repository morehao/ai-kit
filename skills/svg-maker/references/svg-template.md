# SVG Template

Copy this to a `.svg` file and replace `<!-- SVG -->`.

交付前自查（下游 `project-insight` 会程序化校验）：

- 根元素**只写 `viewBox`**，不写 `width`/`height`。
- **`<title>` 与 `<desc>` 必写，且都不带属性**（写 `<title>`，不要写 `<title id="...">`）。
- 自包含：无 `<image>` / `<script>` / 远程字体 / 渐变；样式内联在 `<style>`。
- 固定 `viewBox`、可离线双击打开；浅深色都能读（`:root` 变量 + `prefers-color-scheme`）。

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 800" font-family="ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif">
  <!-- title/desc 必写，且不要加 id 等属性（下游按标签名匹配，带属性容易被判缺失） -->
  <title>图的主标题：一句话说清这张图在讲什么</title>
  <desc>中文描述（150-200 字）：这张图表达了什么、有哪些分组与流向、读者该从中看出什么。</desc>
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" />
    </marker>
  </defs>
  <style>
    :root {
      color-scheme: light dark;
      --bg: #f8fafc;
      --fg: #172033;
      --muted: #5b6475;
      --line: #64748b;
      --neutral: #e2e8f0;
      --input: #bfdbfe;
      --process: #c7d2fe;
      --storage: #99f6e4;
      --external: #fde68a;
      --risk: #fecaca;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #0f172a;
        --fg: #e5e7eb;
        --muted: #a3adbd;
        --line: #94a3b8;
        --neutral: #334155;
        --input: #1d4ed8;
        --process: #4338ca;
        --storage: #0f766e;
        --external: #92400e;
        --risk: #991b1b;
      }
    }
    svg {
      background: var(--bg);
    }
    .title {
      font-size: 20px;
      font-weight: 650;
      fill: var(--fg);
    }
    .label {
      font-size: 14px;
      font-weight: 600;
      fill: var(--fg);
    }
    .small {
      font-size: 12px;
      fill: var(--muted);
    }
    .node {
      stroke: var(--line);
      stroke-width: 1;
    }
    .neutral {
      fill: var(--neutral);
    }
    .input {
      fill: var(--input);
    }
    .process {
      fill: var(--process);
    }
    .storage {
      fill: var(--storage);
    }
    .external {
      fill: var(--external);
    }
    .risk {
      fill: var(--risk);
    }
    .edge {
      stroke: var(--line);
      stroke-width: 1.5;
      fill: none;
    }
    .edge-arrow {
      marker-end: url(#arrow);
    }
    .zone {
      fill: none;
      stroke: var(--line);
      stroke-width: 1;
      stroke-dasharray: 6 5;
      opacity: 0.8;
    }
  </style>

  <!-- 背景（可选，覆盖整图） -->
  <rect x="0" y="0" width="1200" height="800" fill="var(--bg)" />

  <!-- connectors：先画，再画 node 以覆盖 -->
  <!-- SVG -->
</svg>
```
