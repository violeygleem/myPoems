
# ---------------------------
# 进入项目根目录
# ---------------------------
Set-Location "D:\code_web\bookblog"

# ---------------------------
# 执行 obsidian_to_posts.py
# ---------------------------
Write-Host "Running obsidian_to_posts.py..."
try {
    & python .\obsidian_to_posts.py
    if ($LASTEXITCODE -ne 0) {
        throw "obsidian_to_posts.py failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "Error: $_"
    exit 1
}

# ---------------------------
# 执行 manage.py
# ---------------------------
Write-Host "Running manage.py..."
try {
    python .\manage.py
    if ($LASTEXITCODE -ne 0) {
        throw "manage.py failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "Error: $_"
    exit 1
}

# ---------------------------
# 执行 deploy.ps1
# ---------------------------
Write-Host "Running deploy.ps1..."
try {
    .\deploy.ps1
    if ($LASTEXITCODE -ne 0) {
        throw "deploy.ps1 failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "Error: $_"
    exit 1
}

Write-Host "All scripts executed successfully ✅"
