# ===================================================
# [1/4] Checking and closing application
# ===================================================
$processName = "UCServiceToolExport"
$runningProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue

if ($runningProcess) {
    Write-Host "$processName.exe is running. Closing the application..." -ForegroundColor Yellow
    Stop-Process -Name $processName -Force
    Start-Sleep -Seconds 2
} else {
    Write-Host "$processName.exe is not running. Proceeding..." -ForegroundColor Green
}

# ===================================================
# [2/4] Preparing destination directories
# ===================================================
$currentDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($currentDir)) { $currentDir = Get-Location }

$scriptDir = Join-Path $currentDir "Script"
if (-not (Test-Path $scriptDir)) {
    New-Item -ItemType Directory -Path $scriptDir | Out-Null
    Write-Host "Directory \Script\ created successfully." -ForegroundColor Green
} else {
    Write-Host "Directory \Script\ already exists." -ForegroundColor Green
}

# ===================================================
# [3/4] Downloading files (Progress shown on top bar)
# ===================================================
$file1_Url = "https://raw.githubusercontent.com/inforeportable/UCServiceToolExport/refs/heads/main/UCServiceToolExport/forms.xml"
$file1_Path = Join-Path $currentDir "forms.xml"

$file2_Url = "https://raw.githubusercontent.com/inforeportable/UCServiceToolExport/refs/heads/main/UCServiceToolExport/Script/script.dcu"
$file2_Path = Join-Path $scriptDir "script.dcu"

try {
    Write-Host "`nDownloading: forms.xml" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $file1_Url -OutFile $file1_Path -UserAgent "Mozilla/5.0"
    Write-Host "forms.xml downloaded and overwritten successfully." -ForegroundColor Green

    Write-Host "`nDownloading: script.dcu" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $file2_Url -OutFile $file2_Path -UserAgent "Mozilla/5.0"
    Write-Host "script.dcu downloaded and overwritten successfully." -ForegroundColor Green
}
catch {
    Write-Host "`nError: Failed to download files. $_" -ForegroundColor Red
    Pause
    Exit
}

# ===================================================
# [4/4] Task completed. Restarting application
# ===================================================
Write-Host "`nAll files updated successfully! Restarting app in 3 seconds..." -ForegroundColor Green
Start-Sleep -Seconds 3

$exePath = Join-Path $currentDir "UCServiceToolExport.exe"
if (Test-Path $exePath) {
    Start-Process -FilePath $exePath
} else {
    Write-Host "[Warning] Cannot find UCServiceToolExport.exe in this folder." -ForegroundColor Red
    Pause
}

Exit