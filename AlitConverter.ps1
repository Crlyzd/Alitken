# Alit Converter by Curlyzed (Universal Edition) - Modular Orchestrator
$Header = @"
============================================
          Alit Converter by Curlyzed
              Version 0.2 Alpha
============================================
"@

Clear-Host
Write-Host $Header -ForegroundColor Cyan

# 1. Load Modules (Dot-source all files inside src/ recursively)
$srcPath = Join-Path $PSScriptRoot "src"
if (Test-Path $srcPath) {
    Get-ChildItem -Path $srcPath -Filter *.ps1 -Recurse | ForEach-Object {
        . $_.FullName
    }
} else {
    Write-Host "ERROR: Source folder not found at $srcPath" -ForegroundColor Red
    exit
}

# 2. Dependency Check
Write-Host "[SYSTEM CHECK] Checking dependencies..." -ForegroundColor Gray
$deps = Get-SystemDependencies

if (!$deps.FfmpegExists -or !$deps.FfprobeExists) {
    Write-Host "ERROR: ffmpeg and/or ffprobe could not be found in your system PATH." -ForegroundColor Red
    Write-Host "Please install FFmpeg and make sure it is added to your environment variables." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

if (!$deps.MagickExists) {
    Write-Host "[WARNING] ImageMagick ('magick') was not found in your system PATH." -ForegroundColor Yellow
    Write-Host "          Image conversion options will be disabled." -ForegroundColor Yellow
}

# 3. Input Processing & Auto-Detection
if ($args.Count -eq 0) {
    Write-Host "No files or folders were provided." -ForegroundColor Red
    Write-Host "Please select files, right-click, and choose 'Send to' -> 'Alitken Converter'." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

$imageExtensions = @('.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff', '.tif', '.gif', '.heic')
$videoExtensions = @('.mp4', '.mkv', '.mov', '.avi', '.m4v', '.webm', '.flv', '.3gp')

$imageFiles = @()
$videoFiles = @()

foreach ($arg in $args) {
    if (Test-Path $arg) {
        $item = Get-Item $arg
        if ($item.PSIsContainer) {
            # It's a directory. Gather all supported files inside it.
            $filesInDir = Get-ChildItem -Path $item.FullName -File
            foreach ($file in $filesInDir) {
                $ext = $file.Extension.ToLower()
                if ($imageExtensions -contains $ext) {
                    $imageFiles += $file
                } elseif ($videoExtensions -contains $ext) {
                    $videoFiles += $file
                }
            }
        } else {
            # It's a single file.
            $ext = $item.Extension.ToLower()
            if ($imageExtensions -contains $ext) {
                $imageFiles += $item
            } elseif ($videoExtensions -contains $ext) {
                $videoFiles += $item
            } else {
                Write-Host "Warning: Extension '$ext' of file '$($item.Name)' is not recognized as a supported image or video." -ForegroundColor Yellow
            }
        }
    }
}

if ($imageFiles.Count -eq 0 -and $videoFiles.Count -eq 0) {
    Write-Host "No supported image or video files found to convert." -ForegroundColor Red
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# 4. Config Menus State Machine
$config = Show-ConfigMenus -imageFiles $imageFiles -videoFiles $videoFiles -magickExists $deps.MagickExists
if ($null -eq $config) {
    Write-Host "`nExiting..." -ForegroundColor Yellow
    exit
}

# Safeguard check if user managed to select image format but lacks ImageMagick
if ($config.ProcessImages -and !$deps.MagickExists) {
    Write-Host "`nERROR: Image conversion was requested, but ImageMagick ('magick') is not in your PATH." -ForegroundColor Red
    Write-Host "Cannot proceed. Please install ImageMagick and try again." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# 5. Execution Pipeline
if ($config.ProcessVideos) {
    Write-Host "`n[SYSTEM CHECK] Configuring hardware pipeline..." -ForegroundColor Gray
    $gpuCaps = Get-GpuEncoder -codecChoice $config.CodecChoice
    Write-Host "-> Hardware : $($gpuCaps.HardwareName)" -ForegroundColor Green
    Write-Host "-> Encoder  : $($gpuCaps.Encoder)" -ForegroundColor Green
    
    Invoke-VideoConversion -videoFiles $videoFiles -config $config -gpuCaps $gpuCaps
}

if ($config.ProcessImages) {
    Invoke-ImageConversion -imageFiles $imageFiles -config $config
}

Write-Host "`nAll tasks complete! Press any key..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")