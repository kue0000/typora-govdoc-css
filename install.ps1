# Typora 公文排版样式 - 一键安装脚本
# 用法：在 PowerShell 中运行以下命令
#   irm https://raw.githubusercontent.com/kue0000/typora-govdoc-css/master/install.ps1 | iex

$ErrorActionPreference = "Stop"
$repoUrl = "https://raw.githubusercontent.com/kue0000/typora-govdoc-css/master/base.user.css"

# 检测 Typora 主题目录
if ($IsWindows -or $env:OS -match "Windows") {
    $themeDir = Join-Path $env:APPDATA "Typora\themes"
} elseif ($IsMacOS) {
    $themeDir = Join-Path $HOME "Library/Application Support/abnerworks.Typora/themes"
} elseif ($IsLinux) {
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

Write-Host "Typora 主题目录：$themeDir" -ForegroundColor Cyan

# 下载 CSS 文件
Write-Host "正在下载公文排版样式..." -ForegroundColor Cyan
$tempFile = Join-Path $env:TEMP "typora-govdoc-base.user.css"
try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $tempFile -UseBasicParsing
} catch {
    Write-Host "[!] 下载失败：$_" -ForegroundColor Red
    exit 1
}

# 安装为 base.user.css（全局生效）
$baseTarget = Join-Path $themeDir "base.user.css"
if (Test-Path $baseTarget) {
    $backup = "$baseTarget.bak"
    Copy-Item $baseTarget $backup -Force
    Write-Host "已备份旧文件：$backup" -ForegroundColor Yellow
}
Copy-Item $tempFile $baseTarget -Force
Write-Host "[OK] 已安装 base.user.css" -ForegroundColor Green

# 检测当前主题并安装对应的 user.css
$themes = @("github", "whitey", "newsprint", "night", "pixyll")
foreach ($theme in $themes) {
    $themeCss = Join-Path $themeDir "$theme.css"
    if (Test-Path $themeCss) {
        $userCss = Join-Path $themeDir "$theme.user.css"
        if (Test-Path $userCss) {
            Copy-Item $userCss "$userCss.bak" -Force
        }
        Copy-Item $tempFile $userCss -Force
        Write-Host "[OK] 已安装 $theme.user.css" -ForegroundColor Green
    }
}

# 清理
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "安装完成！请重启 Typora 后导出 PDF 查看效果。" -ForegroundColor Green
Write-Host "仓库地址：https://github.com/kue0000/typora-govdoc-css" -ForegroundColor Cyan
