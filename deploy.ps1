param(
    [string]$ConfigPath = ".\blog.conf"
)

$ErrorActionPreference = "Stop"

function Read-ConfFile {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path $Path)) {
        throw "配置文件不存在: $Path"
    }
    foreach ($line in Get-Content -Path $Path -Encoding UTF8) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#") -or $trimmed.StartsWith(";") -or $trimmed.StartsWith("[")) {
            continue
        }
        $idx = $trimmed.IndexOf("=")
        if ($idx -gt 0) {
            $k = $trimmed.Substring(0, $idx).Trim()
            $v = $trimmed.Substring($idx + 1).Trim()
            $map[$k] = $v
        }
    }
    return $map
}

$cfg = Read-ConfFile -Path $ConfigPath
$RepoPath     = $cfg["repo_path"]
$RemoteURL    = $cfg["remote_url"]
$SourceBranch = if ($cfg["source_branch"]) { $cfg["source_branch"] } else { "main" }
$BranchName   = if ($cfg["deploy_branch"]) { $cfg["deploy_branch"] } else { "gh-pages" }

Write-Host "===============================" -ForegroundColor Cyan
Write-Host "🚀 开始自动部署 Hugo 网站" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

git config --global core.quotepath false

Write-Host "==> Step 1: 同步并提交源文件到 $SourceBranch 分支" -ForegroundColor Cyan
Set-Location $RepoPath

git add -A
$status = git status --porcelain
if ($status) {
    Write-Host "📝 检测到本地修改，正在提交..." -ForegroundColor Gray
    git commit -m "Update content and theme: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
} else {
    Write-Host "ℹ️ 本地没有新变化，跳过提交。" -ForegroundColor Gray
}

Write-Host "🔄 同步远程仓库..." -ForegroundColor Gray
git pull origin $SourceBranch --no-rebase
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Git pull failed. Please resolve conflicts." -ForegroundColor Red
    exit 1
}

Write-Host "📤 推送源码到 GitHub..." -ForegroundColor Gray
git push origin $SourceBranch
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ $SourceBranch 分支推送遇到问题，请检查是否存在冲突。" -ForegroundColor Yellow
}

Write-Host "==> Step 2: 深度清理旧缓存并构建 Hugo" -ForegroundColor Cyan
$PublicPath    = Join-Path $RepoPath "public"
$ResourcesPath = Join-Path $RepoPath "resources"

if (Test-Path $PublicPath) { Remove-Item -Recurse -Force $PublicPath }
if (Test-Path $ResourcesPath) { Remove-Item -Recurse -Force $ResourcesPath }

hugo --minify --buildFuture
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Hugo 构建失败。" -ForegroundColor Red
    exit 1
}

Write-Host "==> Step 3: 推送到 $BranchName 分支" -ForegroundColor Cyan
Set-Location $PublicPath

New-Item -Path . -Name ".nojekyll" -ItemType "file" -Force | Out-Null

git init
git config core.quotepath false
git checkout -b $BranchName

git add .
git commit -m "Deploy site $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Write-Host "🚀 正在强制推送至 GitHub..." -ForegroundColor Cyan
git push -f $RemoteURL "${BranchName}:${BranchName}"

Write-Host "`n✅ 部署完成！" -ForegroundColor Green
Set-Location $RepoPath