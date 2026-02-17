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

  # HTML-encode everything first so raw HTML in source can't break DOM
  $t = [System.Net.WebUtility]::HtmlEncode($text)

  # Fenced code blocks (```...```) — content is already encoded
  $t = [regex]::Replace($t, '(?ms)```(\w*)\r?\n(.*?)```', {
    param($m)
    $lang = $m.Groups[1].Value
    $code = $m.Groups[2].Value.TrimEnd()
    "`n<pre><code class=`"language-$lang`">$code</code></pre>`n"
  })

  # Inline code
  $t = [regex]::Replace($t, '`([^`]+?)`', '<code>$1</code>')

  # Bold
  $t = [regex]::Replace($t, '\*\*(.+?)\*\*', '<strong>$1</strong>')

  # Process line-by-line
  $lines = $t -split '\r?\n'
  $result = ""
  $paraLines = [System.Collections.ArrayList]@()

  foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if (-not $trimmed) {
      if ($paraLines.Count -gt 0) {
        $content = ($paraLines -join '<br/>').Trim()
        if ($content) { $result += "<p>$content</p>" }
        $paraLines.Clear()
      }
      continue
    }
    # <pre> blocks we created above should not be inside <p>
    if ($trimmed -match '^<pre>|^</pre>|^<pre><code|^</code></pre>') {
      if ($paraLines.Count -gt 0) {
        $content = ($paraLines -join '<br/>').Trim()
        if ($content) { $result += "<p>$content</p>" }
        $paraLines.Clear()
      }
      $result += $trimmed
      continue
    }
    [void]$paraLines.Add($trimmed)
  }
  if ($paraLines.Count -gt 0) {
    $content = ($paraLines -join '<br/>').Trim()
    if ($content) { $result += "<p>$content</p>" }
  }

  $result = $result -replace '<p>\s*</p>', ''
  return $result
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

# Fix any unclosed <details> tags in the body
$openDetails = ([regex]::Matches($bodyHtml, '<details>')).Count
$closeDetails = ([regex]::Matches($bodyHtml, '</details>')).Count
if ($openDetails -gt $closeDetails) {
  $bodyHtml += '</details>' * ($openDetails - $closeDetails)
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
      --sidebar-w: 260px; --radius: 8px;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #0f172a; --surface: #1e293b; --text: #e2e8f0;
        --muted: #94a3b8; --accent: #818cf8; --border: #334155;
        --user-border: #60a5fa; --user-bg: #1e3a5f;
        --copilot-bg: #1e293b; --tool-bg: #0f172a;
      }
    }
    body { font-family: system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; margin: 0; }

    /* Sidebar: fixed to left */
    .sidebar {
      position: fixed; top: 0; left: 0; bottom: 0; width: var(--sidebar-w);
      background: var(--surface); border-right: 1px solid var(--border);
      overflow-y: auto; padding: 1rem; z-index: 10;
      transition: transform .2s;
    }
    .sidebar.hidden { transform: translateX(-100%); }
    .sidebar h2 { font-size: 1rem; margin-bottom: .75rem; color: var(--accent); }
    .nav-link {
      display: block; padding: .4rem .5rem; margin-bottom: .25rem;
      color: var(--text); text-decoration: none; font-size: .82rem;
      border-radius: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }
    .nav-link:hover { background: var(--border); }

    /* Main: offset by sidebar width */
    .main { margin-left: var(--sidebar-w); padding: 1.5rem; transition: margin-left .2s; }
    .main.full { margin-left: 0; }
    .main-header { display: flex; align-items: center; gap: .5rem; margin-bottom: 1rem; }
    .main-header h1 { font-size: 1.4rem; }

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
    .sidebar.hidden ~ .main .sidebar-toggle .icon-open { display: none; }
    .sidebar.hidden ~ .main .sidebar-toggle .icon-closed { display: block; }

    /* Blocks */
    .block { border-radius: var(--radius); padding: 1rem 1.25rem; margin-bottom: 1rem; border: 1px solid var(--border); overflow-wrap: break-word; word-wrap: break-word; }
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
    .tool-body { font-size: .85rem; color: var(--muted); overflow: hidden; word-break: break-all; overflow-wrap: break-word; }

    /* Typography */
    .block-body p { margin-bottom: .5rem; }
    .block-body p:last-child { margin-bottom: 0; }
    pre { background: var(--tool-bg); padding: .75rem; border-radius: 4px; overflow-x: auto; font-size: .82rem; margin: .5rem 0; max-height: 400px; overflow-y: auto; word-break: normal; }
    code { font-family: 'Cascadia Code', 'Fira Code', monospace; font-size: .88em; }
    p > code { background: var(--tool-bg); padding: .1rem .3rem; border-radius: 3px; }
    details { margin: .5rem 0; }
    details summary { cursor: pointer; }
    strong { font-weight: 700; }
  </style>
</head>
<body>
  <nav class="sidebar" id="sidebar">
    <h2>💬 Messages</h2>
$navHtml
  </nav>
  <div class="main" id="main">
    <div class="main-header">
      <button class="sidebar-toggle" id="sidebar-toggle" title="Toggle messages panel">
        <svg class="icon-open" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><rect x="3" y="3" width="6" height="18" rx="1" fill="currentColor" opacity="1"/><line x1="9" y1="3" x2="9" y2="21"/></svg>
        <svg class="icon-closed" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="3" x2="9" y2="21"/></svg>
      </button>
      <h1>🤖 Copilot CLI Chat History</h1>
    </div>
$bodyHtml
  </div>
  <script>
    const sidebar = document.getElementById('sidebar');
    const main = document.getElementById('main');
    document.getElementById('sidebar-toggle').addEventListener('click', () => {
      sidebar.classList.toggle('hidden');
      main.classList.toggle('full');
    });
    if (window.innerWidth <= 768) {
      sidebar.classList.add('hidden');
      main.classList.add('full');
    }
  </script>
</body>
</html>
"@

$html | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "✅ Generated $OutputFile"
