# repo-sync.ps1
# PowerShell 7+
# Repository and .env files synchronization

# PowerShell colors
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Cyan = "Cyan"

function Sep { Write-Host ("=" * 40) -ForegroundColor $Cyan }

# Check Git repository
try { git rev-parse --is-inside-work-tree > $null 2>&1 } catch {
    Write-Host "Error: current folder is not a Git repository." -ForegroundColor $Red
    exit 1
}

$RepoDir = git rev-parse --show-toplevel
$ProjectName = Split-Path $RepoDir -Leaf

# Find mapped network drive
$NetworkDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" }
if ($NetworkDrives.Count -eq 0) { 
    Write-Host "No mapped network drive found." -ForegroundColor $Red
    exit 1 
}
$SambaDir = Join-Path $NetworkDrives[0].Root "Env\$ProjectName"

Write-Host "Repository: $RepoDir" -ForegroundColor $Cyan
Write-Host "Windows share: $SambaDir" -ForegroundColor $Cyan

$Confirm = Read-Host "Do you want to sync .env files and install dependencies? [y/N]"
if ($Confirm.ToLower() -notin @("y","yes")) { Write-Host "Cancelled."; exit 0 }

Sep
Write-Host "Running git pull..." -ForegroundColor $Yellow
git -C $RepoDir pull
Sep

# Install dependencies
Write-Host "Checking dependencies..." -ForegroundColor $Yellow

$excludeDirs = @("node_modules",".git",".next","dist","build","out","tmp","coverage",".svelte-kit",".turbo")

Get-ChildItem -Path $RepoDir -Recurse -Filter "package.json" -ErrorAction SilentlyContinue |
Where-Object { 
    $exclude = $false
    foreach ($d in $excludeDirs) { if ($_.FullName -like "*\$d*") { $exclude = $true; break } }
    -not $exclude
} | ForEach-Object {
    $Dir = $_.Directory.FullName
    Write-Host "[$Dir] checking dependencies..." -ForegroundColor $Cyan
    Push-Location $Dir

    if ((Test-Path "pnpm-lock.yaml") -or (Test-Path "pnpm-lock.yml")) { pnpm install }
    elseif (Test-Path "yarn.lock") { yarn install }
    else { npm install }

    Pop-Location
}
Sep

# Sync .env files
Write-Host "Synchronizing .env files..." -ForegroundColor $Yellow
if (-not (Test-Path $SambaDir)) { New-Item -ItemType Directory -Path $SambaDir -Force | Out-Null }

Get-ChildItem -Path $RepoDir -Recurse -File -Include ".env*" -ErrorAction SilentlyContinue |
Where-Object { 
    $exclude = $false
    foreach ($d in $excludeDirs) { if ($_.FullName -like "*\$d*") { $exclude = $true; break } }
    -not $exclude
} | ForEach-Object {
    $RelPath = $_.DirectoryName.Substring($RepoDir.Length).TrimStart('\','/')
    $Prefix = if ([string]::IsNullOrEmpty($RelPath)) { "root" } else { $RelPath -replace '[\\/]','_' }
    $SambaFilePath = Join-Path $SambaDir "$Prefix.$($_.Name.TrimStart('.'))"

    $DestDir = Split-Path $SambaFilePath
    if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir -Force | Out-Null }

    if (Test-Path $SambaFilePath) {
        $LocalMod = (Get-Item $_.FullName).LastWriteTimeUtc
        $SambaMod = (Get-Item $SambaFilePath).LastWriteTimeUtc
        if ($LocalMod -gt $SambaMod) { Copy-Item $_.FullName $SambaFilePath -Force; Write-Host "Updated Windows: $Prefix.$($_.Name)" -ForegroundColor $Green }
        elseif ($SambaMod -gt $LocalMod) { Copy-Item $SambaFilePath $_.FullName -Force; Write-Host "Updated locally: $($_.Name)" -ForegroundColor $Green }
        else { Write-Host "File $($_.Name) is up to date" -ForegroundColor $Cyan }
    } else {
        Copy-Item $_.FullName $SambaFilePath
        Write-Host "Created $Prefix.$($_.Name) on Windows" -ForegroundColor $Green
    }
}
Sep
Write-Host "Done." -ForegroundColor $Green