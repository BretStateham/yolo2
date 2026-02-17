<#
.SYNOPSIS
  Parses yolo2-copilot-chat-history.txt and generates chat-history.html
#>
param(
  [string]$InputFile = ".\yolo2-copilot-chat-history.txt",
  [string]$OutputFile = ".\chat-history.html"
)

$content = Get-Content $InputFile -Raw -Encoding UTF8

# Split into sections by the --- separator
$sections = $content -split '(?m)^---\s*$'

# Parse each section into typed blocks
$blocks = @()
$userIndex = 0

foreach ($section in $sections) {
  $s = $section.Trim()
  if (-not $s) { continue }

  if ($s -match '(?m)^### 👤 User') {
    $userIndex++
    $body = ($s -replace '(?m)^### 👤 User\s*', '').Trim()
    # Remove leading timestamp lines
    $body = ($body -replace '(?m)^<sub>.*?</sub>\s*', '').Trim()
    $blocks += @{ Type = 'user'; Body = $body; Index = $userIndex }
  }
  elseif ($s -match '(?m)^### 💬 Copilot') {
    $body = ($s -replace '(?m)^### 💬 Copilot\s*', '').Trim()
    $body = ($body -replace '(?m)^<sub>.*?</sub>\s*', '').Trim()
    $blocks += @{ Type = 'copilot'; Body = $body }
  }
  elseif ($s -match '(?m)^### [✅❌⚠️🔧] `(.+?)`') {
    $toolName = $Matches[1]
    $body = $s -replace '(?m)^### [✅❌⚠️🔧] `.+?`\s*', ''
    $body = ($body -replace '(?m)^<sub>.*?</sub>\s*', '').Trim()
    $blocks += @{ Type = 'tool'; Tool = $toolName; Body = $body }
  }
  elseif ($s -match '(?m)^# 🤖 Copilot CLI Session') {
    $blocks += @{ Type = 'header'; Body = $s }
  }
  else {
    # Timestamp-only or other content
    if ($s -match '<sub>') { continue }
    $blocks += @{ Type = 'other'; Body = $s }
  }
}

# HTML-escape helper
function HtmlEncode($text) {
  return [System.Net.WebUtility]::HtmlEncode($text)
}

# Simple markdown to HTML (bold, code blocks, inline code, lists)
function MarkdownToHtml($text) {
  if (-not $text) { return '' }
  $t = $text

  # Fenced code blocks (```...```)
  $t = [regex]::Replace($t, '(?ms)```(\w*)\r?\n(.*?)```', {
    param($m)
    $lang = $m.Groups[1].Value
    $code = [System.Net.WebUtility]::HtmlEncode($m.Groups[2].Value.TrimEnd())
    "<pre><code class=`"language-$lang`">$code</code></pre>"
  })

  # <details> blocks - pass through as-is
  # Already HTML, leave them alone

  # Inline code
  $t = [regex]::Replace($t, '`([^`]+?)`', '<code>$1</code>')

  # Bold
  $t = [regex]::Replace($t, '\*\*(.+?)\*\*', '<strong>$1</strong>')

  # Line breaks for paragraphs (double newline)
  $t = [regex]::Replace($t, '(\r?\n){2,}', '</p><p>')

  # Single line breaks within paragraphs
  $t = [regex]::Replace($t, '(?<!</p>)\r?\n(?!<)', '<br/>')

  return "<p>$t</p>"
}

# Build the user message jump nav
$userMessages = $blocks | Where-Object { $_.Type -eq 'user' }

$navHtml = ""
$msgNum = 0
foreach ($um in $userMessages) {
  $msgNum++
  $preview = $um.Body
  if ($preview.Length -gt 60) { $preview = $preview.Substring(0, 60) + "..." }
  $preview = [System.Net.WebUtility]::HtmlEncode($preview)
  $navHtml += "      <a href=`"#user-$msgNum`" class=`"nav-link`">$msgNum. $preview</a>`n"
}

# Build body blocks
$bodyHtml = ""
$userCount = 0
$toolGroup = @()
$inToolGroup = $false

function FlushToolGroup {
  $script:toolGroupHtml = ""
  if ($script:toolGroup.Count -eq 0) { return "" }
  $html = "<div class=`"tool-group`"><details><summary>⚙️ $($script:toolGroup.Count) tool call(s)</summary>"
  foreach ($tg in $script:toolGroup) {
    $toolLabel = [System.Net.WebUtility]::HtmlEncode($tg.Tool)
    $toolBody = MarkdownToHtml $tg.Body
    $html += "<div class=`"tool-call`"><div class=`"tool-name`">$toolLabel</div><div class=`"tool-body`">$toolBody</div></div>"
  }
  $html += "</details></div>"
  $script:toolGroup = @()
  return $html
}

foreach ($block in $blocks) {
  if ($block.Type -eq 'tool') {
    $toolGroup += $block
    $inToolGroup = $true
    continue
  }

  # Flush any pending tool group
  if ($inToolGroup) {
    $bodyHtml += FlushToolGroup
    $inToolGroup = $false
  }

  switch ($block.Type) {
    'header' {
      $hBody = MarkdownToHtml $block.Body
      $bodyHtml += "<div class=`"block header-block`">$hBody</div>"
    }
    'user' {
      $userCount++
      $uBody = MarkdownToHtml $block.Body
      $bodyHtml += "<div class=`"block user-block`" id=`"user-$userCount`"><div class=`"block-label`">👤 User</div><div class=`"block-body`">$uBody</div></div>"
    }
    'copilot' {
      if ($block.Body) {
        $cBody = MarkdownToHtml $block.Body
        $bodyHtml += "<div class=`"block copilot-block`"><div class=`"block-label`">🤖 Copilot</div><div class=`"block-body`">$cBody</div></div>"
      }
    }
    'other' {
      if ($block.Body) {
        $oBody = MarkdownToHtml $block.Body
        $bodyHtml += "<div class=`"block other-block`">$oBody</div>"
      }
    }
  }
}
# Flush remaining tool group
if ($toolGroup.Count -gt 0) {
  $bodyHtml += FlushToolGroup
}

# Assemble final HTML
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Chat History — Quadratic Visualizer</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --bg: #f5f7fa; --surface: #ffffff; --text: #1a1a2e;
      --muted: #6b7280; --accent: #4f46e5; --border: #e5e7eb;
      --user-border: #3b82f6; --user-bg: #eff6ff;
      --copilot-bg: #f9fafb; --tool-bg: #f3f4f6;
      --radius: 8px;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #0f172a; --surface: #1e293b; --text: #e2e8f0;
        --muted: #94a3b8; --accent: #818cf8; --border: #334155;
        --user-border: #60a5fa; --user-bg: #1e3a5f;
        --copilot-bg: #1e293b; --tool-bg: #0f172a;
      }
    }
    body { font-family: system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; overflow: hidden; height: 100vh; }
    .layout { display: grid; grid-template-columns: 260px 1fr; height: 100vh; }
    .layout.collapsed { grid-template-columns: 0 1fr; }

    /* Sidebar */
    .sidebar {
      height: 100vh; overflow-y: auto;
      background: var(--surface); border-right: 1px solid var(--border); padding: 1rem;
      transition: width .2s, padding .2s, opacity .2s;
    }
    .layout.collapsed .sidebar { width: 0; padding: 0; overflow: hidden; opacity: 0; border: none; }
    .sidebar h2 { font-size: 1rem; margin-bottom: .75rem; color: var(--accent); }
    .nav-link {
      display: block; padding: .4rem .5rem; margin-bottom: .25rem;
      color: var(--text); text-decoration: none; font-size: .82rem;
      border-radius: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }
    .nav-link:hover { background: var(--border); }

    /* Toggle button */
    .sidebar-toggle {
      background: none; border: none;
      color: var(--muted); cursor: pointer;
      width: 28px; height: 28px;
      display: flex; align-items: center; justify-content: center;
      border-radius: 4px; flex-shrink: 0;
    }
    .sidebar-toggle:hover { color: var(--accent); background: var(--border); }
    .sidebar-toggle svg { width: 18px; height: 18px; }
    .sidebar-toggle .icon-closed { display: none; }
    .layout.collapsed .sidebar-toggle .icon-open { display: none; }
    .layout.collapsed .sidebar-toggle .icon-closed { display: block; }

    /* Main content */
    .main { padding: 1.5rem; overflow-y: auto; height: 100vh; }
    .main-header { display: flex; align-items: center; gap: .5rem; margin-bottom: 1rem; }
    .main-header h1 { font-size: 1.4rem; }

    /* Blocks */
    .block { border-radius: var(--radius); padding: 1rem 1.25rem; margin-bottom: 1rem; border: 1px solid var(--border); }
    .block-label { font-weight: 700; font-size: .85rem; margin-bottom: .5rem; text-transform: uppercase; letter-spacing: .03em; }

    .user-block { background: var(--user-bg); border-left: 4px solid var(--user-border); }
    .user-block .block-label { color: var(--user-border); }

    .copilot-block { background: var(--copilot-bg); }
    .copilot-block .block-label { color: var(--accent); }

    .header-block { background: var(--surface); text-align: center; }

    /* Tool groups */
    .tool-group { margin-bottom: 1rem; }
    .tool-group summary {
      cursor: pointer; padding: .5rem .75rem; background: var(--tool-bg);
      border: 1px solid var(--border); border-radius: var(--radius);
      font-size: .85rem; color: var(--muted); font-weight: 600;
    }
    .tool-group summary:hover { color: var(--text); }
    .tool-call { padding: .75rem 1rem; border-bottom: 1px solid var(--border); }
    .tool-call:last-child { border-bottom: none; }
    .tool-name { font-weight: 700; font-size: .8rem; color: var(--accent); margin-bottom: .25rem; }
    .tool-body { font-size: .85rem; color: var(--muted); }

    /* Typography */
    .block-body p { margin-bottom: .5rem; }
    .block-body p:last-child { margin-bottom: 0; }
    pre { background: var(--tool-bg); padding: .75rem; border-radius: 4px; overflow-x: auto; font-size: .82rem; margin: .5rem 0; }
    code { font-family: 'Cascadia Code', 'Fira Code', monospace; font-size: .88em; }
    p > code { background: var(--tool-bg); padding: .1rem .3rem; border-radius: 3px; }
    details { margin: .5rem 0; }
    details summary { cursor: pointer; }
    strong { font-weight: 700; }
  </style>
</head>
<body>
  <div class="layout" id="layout">
    <nav class="sidebar" id="sidebar">
      <h2>💬 Messages</h2>
$navHtml
    </nav>
    <div class="main">
      <div class="main-header">
        <button class="sidebar-toggle" id="sidebar-toggle" title="Toggle messages panel">
          <svg class="icon-open" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><rect x="3" y="3" width="6" height="18" rx="1" fill="currentColor" opacity="1"/><line x1="9" y1="3" x2="9" y2="21"/></svg>
          <svg class="icon-closed" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="3" x2="9" y2="21"/></svg>
        </button>
        <h1>🤖 Copilot CLI Chat History</h1>
      </div>
$bodyHtml
    </div>
  </div>
  <script>
    const toggle = document.getElementById('sidebar-toggle');
    const layout = document.getElementById('layout');
    toggle.addEventListener('click', () => {
      layout.classList.toggle('collapsed');
    });
    if (window.innerWidth <= 768) {
      layout.classList.add('collapsed');
    }
  </script>
</body>
</html>
"@

$html | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "✅ Generated $OutputFile"
