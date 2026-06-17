# Typora 公文排版样式 - 一键安装脚本
# 用法：在 PowerShell 中运行以下命令
#   irm https://raw.githubusercontent.com/kue0000/typora-govdoc-css/master/install.ps1 | iex

$ErrorActionPreference = "Stop"
$repoUrl = "https://raw.githubusercontent.com/kue0000/typora-govdoc-css/master/base.user.css"

# ==========================================================================
#  0. 环境检测
# ==========================================================================
if ($IsWindows -or $env:OS -match "Windows") {
    $os = "Windows"
    $themeDir = Join-Path $env:APPDATA "Typora\themes"
} elseif ($IsMacOS) {
    $os = "macOS"
    $themeDir = Join-Path $HOME "Library/Application Support/abnerworks.Typora/themes"
} elseif ($IsLinux) {
    $os = "Linux"
    $themeDir = Join-Path $HOME ".config/Typora/themes"
} else {
    Write-Host "[!] 无法识别操作系统，请手动安装。" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $themeDir)) {
    Write-Host "[!] Typora 主题目录不存在：$themeDir" -ForegroundColor Red
    Write-Host "    请确认 Typora 已安装并至少运行过一次。" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "  Typora 公文排版样式 — 安装程序" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor DarkGray
Write-Host "  系统: $os    主题目录: $themeDir" -ForegroundColor Gray
Write-Host ""

# ==========================================================================
#  1. 字体环境检测
# ==========================================================================
Write-Host "[1/5] 检查系统字体..." -ForegroundColor Cyan

$fontChecks = @(
    @{ Name = "仿宋 (FangSong)";   Keys = @("FangSong", "仿宋", "仿宋_GB2312", "STFangsong") },
    @{ Name = "黑体 (SimHei)";     Keys = @("SimHei", "黑体", "STHeiti", "Microsoft YaHei") },
    @{ Name = "楷体 (Kaiti)";      Keys = @("Kaiti", "楷体", "楷体_GB2312", "STKaiti", "KaiTi") }
)

$missingFonts = @()

if ($os -eq "Windows") {
    # 从注册表读取已安装字体
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )
    $installedFonts = @{}
    foreach ($rp in $regPaths) {
        if (Test-Path $rp) {
            Get-ItemProperty $rp | Get-Member -MemberType NoteProperty | ForEach-Object {
                $installedFonts[$_.Name.ToLower()] = $true
            }
        }
    }

    foreach ($fc in $fontChecks) {
        $found = $false
        foreach ($key in $fc.Keys) {
            foreach ($installed in $installedFonts.Keys) {
                if ($installed -match [regex]::Escape($key.ToLower())) {
                    $found = $true
                    break
                }
            }
            if ($found) { break }
        }
        if (-not $found) {
            $missingFonts += $fc.Name
        }
    }
} else {
    # macOS / Linux: 使用 fc-list 检测
    foreach ($fc in $fontChecks) {
        $found = $false
        foreach ($key in $fc.Keys) {
            $result = & fc-list ":family=$key" 2>$null
            if ($LASTEXITCODE -eq 0 -and $result) {
                $found = $true
                break
            }
        }
        if (-not $found) {
            $missingFonts += $fc.Name
        }
    }
}

if ($missingFonts.Count -gt 0) {
    Write-Host ""
    Write-Host "  [!] 以下字体未检测到：" -ForegroundColor Yellow
    foreach ($mf in $missingFonts) {
        Write-Host "      - $mf" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  缺少字体可能导致导出 PDF 排版异常。" -ForegroundColor Yellow
    if ($os -eq "Windows") {
        Write-Host "  Windows 通常已内置这些字体。如确实缺失，可从以下地址下载：" -ForegroundColor Gray
        Write-Host "  https://www.fonts.net.cn/commercial-free/font-download.html" -ForegroundColor Gray
    } else {
        Write-Host "  请手动安装对应字体文件 (.ttf / .otf)。" -ForegroundColor Gray
    }
    Write-Host ""

    # 询问是否继续
    $continue = $null
    if (-not $env:QODERWORK_AUTORUN) {
        $continue = Read-Host "  是否继续安装？(Y/n)"
    }
    if ($continue -and $continue.ToLower() -eq "n") {
        Write-Host "  已取消安装。" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "  [OK] 仿宋、黑体、楷体均已安装。" -ForegroundColor Green
}

# ==========================================================================
#  2. 下载 CSS
# ==========================================================================
Write-Host ""
Write-Host "[2/5] 下载公文排版样式..." -ForegroundColor Cyan

$tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "typora-govdoc-base.user.css"
try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $tempFile -UseBasicParsing
} catch {
    Write-Host "  [!] 下载失败：$_" -ForegroundColor Red
    Write-Host "  请检查网络连接或尝试手动下载：" -ForegroundColor Yellow
    Write-Host "  $repoUrl" -ForegroundColor Gray
    exit 1
}

Write-Host "  [OK] 下载完成。" -ForegroundColor Green

# ==========================================================================
#  3. 备份已有 .user.css 并生成卸载脚本
# ==========================================================================
Write-Host ""
Write-Host "[3/5] 备份现有样式..." -ForegroundColor Cyan

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $themeDir "_govdoc-backup-$timestamp"
$backedUpFiles = @()

# 扫描所有将被覆盖的 .user.css 文件
$filesToCheck = @("base.user.css")
$knownThemes = @("github", "whitey", "newsprint", "night", "pixyll", "cobalt", "vue")
foreach ($t in $knownThemes) {
    $tCss = Join-Path $themeDir "$t.css"
    if (Test-Path $tCss) {
        $filesToCheck += "$t.user.css"
    }
}

foreach ($f in $filesToCheck) {
    $fullPath = Join-Path $themeDir $f
    if (Test-Path $fullPath) {
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        Copy-Item $fullPath (Join-Path $backupDir $f) -Force
        $backedUpFiles += $f
    }
}

if ($backedUpFiles.Count -gt 0) {
    Write-Host "  [OK] 已备份 $($backedUpFiles.Count) 个文件到：" -ForegroundColor Green
    Write-Host "       $backupDir" -ForegroundColor Gray
} else {
    Write-Host "  [i] 无旧文件需要备份（首次安装）。" -ForegroundColor Gray
}

# 生成 uninstall.ps1
$uninstallScript = @"
# Typora 公文排版样式 - 卸载脚本
# 用法：在 PowerShell 中运行  .\uninstall.ps1
# 生成时间：$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

`$ErrorActionPreference = "Stop"
`$themeDir = "$themeDir"
`$backupDir = "$backupDir"
`$installedFiles = @()

Write-Host ""
Write-Host "  Typora 公文排版样式 - 卸载" -ForegroundColor Cyan
Write-Host "  ============================" -ForegroundColor DarkGray
Write-Host ""

# 删除当前安装的 .user.css 文件
`$cssFiles = @("base.user.css")
$( ($knownThemes | ForEach-Object { "`$cssFiles += `"$_`.user.css`"" }) -join "`n" )

foreach (`$f in `$cssFiles) {
    `$fullPath = Join-Path `$themeDir `$f
    if (Test-Path `$fullPath) {
        Remove-Item `$fullPath -Force
        `$installedFiles += `$f
    }
}

if (`$installedFiles.Count -gt 0) {
    Write-Host "  [OK] 已删除 `$(`$installedFiles.Count) 个公文样式文件：" -ForegroundColor Green
    foreach (`$f in `$installedFiles) {
        Write-Host "       - `$f" -ForegroundColor Gray
    }
}

# 还原备份
if (Test-Path `$backupDir) {
    `$backups = Get-ChildItem `$backupDir -Filter "*.css"
    if (`$backups.Count -gt 0) {
        Write-Host ""
        Write-Host "  [OK] 正在从备份还原旧样式..." -ForegroundColor Cyan
        foreach (`$b in `$backups) {
            Copy-Item `$b.FullName (Join-Path `$themeDir `$b.Name) -Force
            Write-Host "       已还原 `$(`$b.Name)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host ""
    Write-Host "  [i] 未找到备份目录，跳过还原（首次安装前无旧文件）。" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  卸载完成！请重启 Typora 使更改生效。" -ForegroundColor Green
Write-Host ""
"@

$uninstallPath = Join-Path $themeDir "uninstall.ps1"
Set-Content -Path $uninstallPath -Value $uninstallScript -Encoding UTF8
Write-Host "  [OK] 已生成卸载脚本：$uninstallPath" -ForegroundColor Green
Write-Host "       卸载命令：powershell -File `"$uninstallPath`"" -ForegroundColor Gray

# ==========================================================================
#  4. 安装 CSS 文件
# ==========================================================================
Write-Host ""
Write-Host "[4/5] 安装样式文件..." -ForegroundColor Cyan

# base.user.css（全局生效）
$baseTarget = Join-Path $themeDir "base.user.css"
Copy-Item $tempFile $baseTarget -Force
Write-Host "  [OK] base.user.css" -ForegroundColor Green

# 为已安装的主题安装对应的 user.css
$installedThemes = @()
foreach ($t in $knownThemes) {
    $tCss = Join-Path $themeDir "$t.css"
    if (Test-Path $tCss) {
        $userCss = Join-Path $themeDir "$t.user.css"
        Copy-Item $tempFile $userCss -Force
        Write-Host "  [OK] $t.user.css" -ForegroundColor Green
        $installedThemes += $t
    }
}

# 清理临时文件
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

# ==========================================================================
#  5. 安装后自动验证 — 生成预览 HTML 并在浏览器中打开
# ==========================================================================
Write-Host ""
Write-Host "[5/5] 生成预览验证..." -ForegroundColor Cyan

$cssContent = Get-Content $baseTarget -Raw -Encoding UTF8
$verifyHtml = @"
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Typora 公文样式验证</title>
<style>
body { margin: 0; padding: 0; background: #e8e8e8; font-family: sans-serif; }
.notice { max-width: 780px; margin: 20px auto 10px; padding: 12px 20px; background: #fffbe6; border: 1px solid #ffe58f; border-radius: 6px; font-size: 13px; color: #614700; }
.page { background: #fff; max-width: 794px; margin: 10px auto; padding: 50px 40px; box-shadow: 0 1px 4px rgba(0,0,0,0.15); }
</style>
<style>
$cssContent
</style>
</head>
<body>
<div class="notice">
  <strong>排版验证：</strong>如果下方文档呈现仿宋字体、黑体标题、首行缩进、表格边框等效果，说明样式安装成功。
  <br>若显示为普通网页样式，请重启 Typora 后再试。
</div>
<div class="page typora-export typora-print os-windows" id="write">
<h1>公文排版样式验证</h1>
<h2>一、标题与正文</h2>
<h3>（一）三级标题示例</h3>
<p>正文采用仿宋三号字体，首行缩进两个字符，两端对齐。此段用于验证正文段落的基本排版效果。</p>
<h4>四级标题示例</h4>
<p>四级标题使用仿宋加粗，左对齐。此段用于验证次级标题与正文的视觉区分度。</p>
<h2>二、表格</h2>
<table>
<tr><th>序号</th><th>项目</th><th>状态</th></tr>
<tr><td>1</td><td>样式安装</td><td>已完成</td></tr>
<tr><td>2</td><td>字体检测</td><td>已通过</td></tr>
<tr><td>3</td><td>PDF 导出</td><td>待验证</td></tr>
</table>
<h2>三、列表</h2>
<ol>
<li>第一项：检查标题字体是否为黑体。</li>
<li>第二项：检查正文是否为仿宋且有首行缩进。</li>
<li>第三项：检查表格是否有闭合黑色边框。</li>
</ol>
<ul>
<li>无序列表项一</li>
<li>无序列表项二</li>
<li>无序列表项三</li>
</ul>
<blockquote><p>此段为引用样式，左侧应有黑色竖线标识。</p></blockquote>
<hr>
<p><em>验证完毕后可关闭此页面。在 Typora 中导出任意文件为 PDF 即可看到完整效果。</em></p>
</div>
</body></html>
"@

$verifyPath = Join-Path ([System.IO.Path]::GetTempPath()) "typora-govdoc-verify.html"
Set-Content -Path $verifyPath -Value $verifyHtml -Encoding UTF8
Write-Host "  [OK] 验证页面已生成。" -ForegroundColor Green

# 在默认浏览器中打开
try {
    if ($os -eq "Windows") {
        Start-Process $verifyPath
    } elseif ($os -eq "macOS") {
        Start-Process "open" -ArgumentList $verifyPath
    } else {
        Start-Process "xdg-open" -ArgumentList $verifyPath
    }
    Write-Host "  [OK] 已在浏览器中打开验证页面。" -ForegroundColor Green
} catch {
    Write-Host "  [i] 无法自动打开浏览器，请手动打开：" -ForegroundColor Yellow
    Write-Host "      $verifyPath" -ForegroundColor Gray
}

# ==========================================================================
#  完成
# ==========================================================================
Write-Host ""
Write-Host "  ============================================" -ForegroundColor DarkGray
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host ""
Write-Host "  下一步：重启 Typora → 导出任意文件为 PDF → 查看排版效果" -ForegroundColor White
Write-Host ""
Write-Host "  卸载方法：powershell -File `"$uninstallPath`"" -ForegroundColor Gray
Write-Host "  仓库地址：https://github.com/kue0000/typora-govdoc-css" -ForegroundColor Gray
Write-Host "  ============================================" -ForegroundColor DarkGray
Write-Host ""
