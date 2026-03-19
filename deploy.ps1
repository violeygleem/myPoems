# -----------------------------
# 一键 Hugo 部署脚本 (PowerShell 优化版)
# -----------------------------

$RepoPath   = "D:\code_web\bookblog"
$RemoteURL = "git@github.com:violeygleem/myPoems.git"  # 已更新为你的新 ID
$BranchName = "gh-pages"

Write-Host "===============================" -ForegroundColor Cyan
Write-Host "🚀 开始自动部署 Hugo 网站" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

# 开启全局 Git 中文路径支持
git config --global core.quotepath false

# === Step 1: 提交源文件到 main 分支 ===
Write-Host "==> Step 1: 同步并提交源文件到 main 分支" -ForegroundColor Cyan
Set-Location $RepoPath

# 1. 先把本地的新内容加入暂存区
git add -A

# 2. 检查是否有需要提交的内容
$status = git status --porcelain
if ($status) {
    Write-Host "📝 检测到本地修改，正在提交..." -ForegroundColor Gray
    git commit -m "Update content and theme: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
} else {
    Write-Host "ℹ️ 本地没有新变化，跳过提交。" -ForegroundColor Gray
}

# 3. 拉取远程更新 (因为本地已 commit，不再会有 unstaged changes 报错)
Write-Host "🔄 同步远程仓库..." -ForegroundColor Gray
git pull origin main --rebase

# 4. 推送源码到 main
Write-Host "📤 推送源码到 GitHub..." -ForegroundColor Gray
git push origin main

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ main 分支推送遇到问题，请检查是否存在冲突。" -ForegroundColor Yellow
}

# === Step 2: 深度清理并构建 ===
Write-Host "==> Step 2: 深度清理旧缓存并构建 Hugo" -ForegroundColor Cyan
$PublicPath = Join-Path $RepoPath "public"
$ResourcesPath = Join-Path $RepoPath "resources"

# 彻底删除旧产物，防止搜索索引缓存
if (Test-Path $PublicPath) { Remove-Item -Recurse -Force $PublicPath }
if (Test-Path $ResourcesPath) { Remove-Item -Recurse -Force $ResourcesPath }

# 执行构建
hugo --minify --buildFuture
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Hugo 构建失败。" -ForegroundColor Red
    exit 1
}

# === Step 3: 部署 gh-pages ===
Write-Host "==> Step 3: 推送到 gh-pages 分支" -ForegroundColor Cyan
Set-Location $PublicPath

# 创建 .nojekyll (必须在 git add 之前)
New-Item -Path . -Name ".nojekyll" -ItemType "file" -Force | Out-Null

# 重新初始化静态仓库
git init
git config core.quotepath false
git checkout -b $BranchName

# 关键：直接强制推送到远程的 gh-pages 分支根目录
git add .
git commit -m "Deploy site $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Write-Host "🚀 正在强制推送至 GitHub..." -ForegroundColor Cyan
# 使用强制推送覆盖远程分支
git push -f $RemoteURL "${BranchName}:${BranchName}"

Write-Host "`n✅ 部署完成！" -ForegroundColor Green
Set-Location $RepoPath