param(
    [string]$ConfigPath = "D:\code_web\bookblog\blog.conf"
)

$ErrorActionPreference = "Stop"
$ResolvedConf = (Resolve-Path $ConfigPath).Path
$ScriptDir = Split-Path -Parent $ResolvedConf

Set-Location $ScriptDir

Write-Host "Running obsidian_to_posts.py..."
python .\obsidian_to_posts.py --config "$ResolvedConf"
if ($LASTEXITCODE -ne 0) {
    throw "obsidian_to_posts.py failed with exit code $LASTEXITCODE"
}

Write-Host "Running manage.py..."
python .\manage.py --config "$ResolvedConf"
if ($LASTEXITCODE -ne 0) {
    throw "manage.py failed with exit code $LASTEXITCODE"
}

Write-Host "Running deploy.ps1..."
.\deploy.ps1 -ConfigPath "$ResolvedConf"
if ($LASTEXITCODE -ne 0) {
    throw "deploy.ps1 failed with exit code $LASTEXITCODE"
}

Write-Host "All scripts executed successfully ✅" -ForegroundColor Green