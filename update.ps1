# =============================================================
#  НАСТРОЙКИ
$Owner  = 'ChesterX'
$Repo   = 'client'
$Branch = 'main'
$Dest   = $PSScriptRoot   # папка где лежит этот файл
# =============================================================

function Get-GitBlobSHA([string]$path) {
    $bytes  = [System.IO.File]::ReadAllBytes($path)
    $header = [System.Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
    $sha1   = [System.Security.Cryptography.SHA1]::Create()
    return ([BitConverter]::ToString($sha1.ComputeHash($header + $bytes))).Replace('-','').ToLower()
}

function Get-EncodedUrl([string]$rawPath) {
    return ($rawPath.Split('/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
}

$BAR = 25
$Host.UI.RawUI.WindowTitle = 'MU Online Updater'

Write-Host ''
Write-Host '  ========================================' -ForegroundColor Cyan
Write-Host '         MU Online Updater via GitHub'      -ForegroundColor Cyan
Write-Host '  ========================================' -ForegroundColor Cyan
Write-Host "  Репозиторий : github.com/$Owner/$Repo"    -ForegroundColor Gray
Write-Host "  Ветка       : $Branch"                    -ForegroundColor Gray
Write-Host "  Назначение  : $Dest"                      -ForegroundColor Gray
Write-Host ''

Write-Host '  Подключение к GitHub...' -ForegroundColor Yellow
$treeUrl = "https://api.github.com/repos/$Owner/$Repo/git/trees/${Branch}?recursive=1"
try {
    $resp = Invoke-RestMethod -Uri $treeUrl `
        -Headers @{ 'User-Agent' = 'MuOnlineUpdater' } `
        -ErrorAction Stop
} catch {
    Write-Host ''
    Write-Host "  ОШИБКА: Не удалось подключиться к GitHub." -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    Write-Host ''
    Read-Host '  Нажмите Enter для выхода'
    exit 1
}

if ($resp.truncated) {
    Write-Host '  ПРЕДУПРЕЖДЕНИЕ: Список файлов обрезан (слишком большой репозиторий).' -ForegroundColor Yellow
}

$remoteFiles = $resp.tree | Where-Object { $_.type -eq 'blob' }
$total       = $remoteFiles.Count
Write-Host "  Файлов в репозитории: $total" -ForegroundColor Gray
Write-Host ''

if (-not (Test-Path $Dest)) {
    New-Item $Dest -ItemType Directory -Force | Out-Null
}

Write-Host '  --- Синхронизация файлов ---' -ForegroundColor Cyan
Write-Host ''

$done    = 0
$updated = 0
$newf    = 0
$skipped = 0
$errors  = 0

foreach ($rf in $remoteFiles) {
    $done++
    $pct    = [int]($done * 100 / $total)
    $filled = [int]($pct * $BAR / 100)
    $bar    = '[' + ('#' * $filled) + ('-' * ($BAR - $filled)) + ']'

    $relPath   = $rf.path.Replace('/', '\')
    $localPath = Join-Path $Dest $relPath
    $status    = 'OK'
    $color     = 'DarkGray'
    $nameColor = 'DarkGray'
    $needsDl   = $false

    try {
        if (Test-Path $localPath) {
            $localSHA = Get-GitBlobSHA $localPath
            if ($localSHA -ne $rf.sha) {
                $needsDl   = $true
                $status    = 'ОБНОВЛЕН '
                $color     = 'Yellow'
                $nameColor = 'White'
                $updated++
            } else {
                $skipped++
            }
        } else {
            $needsDl   = $true
            $status    = 'НОВЫЙ    '
            $color     = 'Green'
            $nameColor = 'White'
            $newf++
        }

        if ($needsDl) {
            $dir = Split-Path $localPath -Parent
            if (-not (Test-Path $dir)) {
                New-Item $dir -ItemType Directory -Force | Out-Null
            }
            $encodedPath = Get-EncodedUrl $rf.path
            $rawUrl = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/$encodedPath"
            Invoke-WebRequest -Uri $rawUrl -OutFile $localPath -UseBasicParsing -ErrorAction Stop
        }
    } catch {
        $status    = 'ОШИБКА   '
        $color     = 'Red'
        $nameColor = 'Red'
        $errors++
    }

    Write-Host "  $bar $($pct.ToString().PadLeft(3))%  " -NoNewline
    Write-Host $status -ForegroundColor $color -NoNewline
    Write-Host "  $relPath" -ForegroundColor $nameColor
}

Write-Host ''
Write-Host '  ========================================' -ForegroundColor Cyan
Write-Host '  Готово!' -ForegroundColor Green
Write-Host "    Обновлено : $updated" -ForegroundColor Yellow
Write-Host "    Новых     : $newf"    -ForegroundColor Green
Write-Host "    Пропущено : $skipped" -ForegroundColor DarkGray
Write-Host "    Ошибок    : $errors"  -ForegroundColor $(if ($errors -gt 0) { 'Red' } else { 'DarkGray' })
Write-Host '  ========================================' -ForegroundColor Cyan
Write-Host ''
Read-Host '  Нажмите Enter для выхода'
