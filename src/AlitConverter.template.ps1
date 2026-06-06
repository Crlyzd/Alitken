# Alit Converter by Curlyzed (Universal Edition) - Standalone
$Header = @"
============================================
          Alit Converter by Curlyzed
              Version 0.2 Alpha
============================================
"@

Clear-Host
Write-Host $Header -ForegroundColor Cyan

# Get the directory of the running script or compiled EXE (critical for ps2exe)
$AppDir = $PSScriptRoot
if (!$AppDir) {
    $exePath = [Environment]::GetCommandLineArgs()[0]
    if ($exePath -and (Test-Path $exePath)) {
        $AppDir = Split-Path $exePath -Parent
    } else {
        if ($MyInvocation.MyCommand.Path) {
            $AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        } else {
            $AppDir = $pwd
        }
    }
}

# Ensure CommandPath is populated (critical for isExe check and shortcut creation)
$CommandPath = $PSCommandPath
if (!$CommandPath) {
    $exePath = [Environment]::GetCommandLineArgs()[0]
    if ($exePath -and (Test-Path $exePath)) {
        $CommandPath = $exePath
    } else {
        if ($MyInvocation.MyCommand.Path) {
            $CommandPath = $MyInvocation.MyCommand.Path
        } else {
            $CommandPath = Join-Path $AppDir "AlitConverter.ps1"
        }
    }
}

# --- BEGIN BUNDLED MODULES ---
# [[BUNDLED_MODULES]]
# --- END BUNDLED MODULES ---

# 1. Setup / Run Router
if ($args.Count -eq 0) {
    Write-Host "No media files were provided for conversion.`n" -ForegroundColor Gray
    
    $setupOptions = [ordered]@{
        "1" = "Install Context Menu (Create 'SendTo' Shortcut)"
        "2" = "Uninstall Context Menu (Remove 'SendTo' Shortcut)"
    }
    
    $choice = Show-Menu -Title "AlitConverter Setup" -Options $setupOptions -AllowBack $false -AllowQuit $true
    
    if ($choice -eq "q") {
        Write-Host "`nExiting..." -ForegroundColor Yellow
        exit
    }
    
    $shortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\SendTo\Alitken Converter.lnk"
    
    if ($choice -eq "1") {
        Write-Host "`n[WORKING] Installing shortcut to SendTo menu..." -ForegroundColor Green
        try {
            $isExe = $CommandPath.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)
            
            $WshShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($shortcutPath)
            
            if ($isExe) {
                $Shortcut.TargetPath = $CommandPath
                $Shortcut.Arguments = ""
            } else {
                $Shortcut.TargetPath = "powershell.exe"
                $Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$CommandPath`""
            }
            
            $Shortcut.WorkingDirectory = Split-Path $CommandPath -Parent
            $Shortcut.Save()
            
            Write-Host "[SUCCESS] Installation complete!" -ForegroundColor Cyan
            Write-Host "You can now right-click any file -> Send to -> Alitken Converter." -ForegroundColor Yellow
        } catch {
            Write-Host "[ERROR] Failed to create shortcut: $_" -ForegroundColor Red
        }
    } elseif ($choice -eq "2") {
        Write-Host "`n[WORKING] Uninstalling SendTo shortcut..." -ForegroundColor Green
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force
            Write-Host "[SUCCESS] Uninstallation complete!" -ForegroundColor Cyan
        } else {
            Write-Host "[SKIP] Shortcut not found." -ForegroundColor Yellow
        }
    }
    
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# 2. Dependency Check
Write-Host "[SYSTEM CHECK] Checking dependencies..." -ForegroundColor Gray
$deps = Get-SystemDependencies -AppDir $AppDir

$ffmpegMissing = !$deps.FfmpegExists -or !$deps.FfprobeExists
$magickMissing = !$deps.MagickExists

if ($ffmpegMissing -or $magickMissing) {
    if ($ffmpegMissing) {
        Write-Host "WARNING: FFmpeg (ffmpeg and/or ffprobe) is missing." -ForegroundColor Yellow
    }
    if ($magickMissing) {
        Write-Host "WARNING: ImageMagick (magick) is missing (optional for image conversion)." -ForegroundColor Yellow
    }
    
    Write-Host "`nWould you like to automatically download and extract the missing dependencies?" -ForegroundColor Cyan
    Write-Host "This will download portable binaries (~130MB total) into: $(Join-Path $AppDir 'bin\')" -ForegroundColor Cyan
    
    $downloadChoice = Read-Host "Download missing dependencies? (Y/N)"
    if ($downloadChoice.Trim() -match '^[Yy]$') {
        # Install-PortableDependencies is defined in src/System/DependencyInstaller.ps1 which is bundled
        Install-PortableDependencies -AppDir $AppDir
        # Re-check dependencies
        $deps = Get-SystemDependencies -AppDir $AppDir
        $ffmpegMissing = !$deps.FfmpegExists -or !$deps.FfprobeExists
        $magickMissing = !$deps.MagickExists
    }
}

if ($ffmpegMissing) {
    Write-Host "ERROR: ffmpeg and/or ffprobe could not be found in your local bin/ folder or system PATH." -ForegroundColor Red
    Write-Host "Please download them manually, place them in the 'bin' directory next to the program, and try again." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

if ($magickMissing) {
    Write-Host "[WARNING] ImageMagick ('magick') was not found in your local bin/ folder or system PATH." -ForegroundColor Yellow
    Write-Host "          Image conversion options will be disabled." -ForegroundColor Yellow
}

# Save resolved paths to global variables for processors to use
$global:FfmpegPath = $deps.FfmpegPath
$global:FfprobePath = $deps.FfprobePath
$global:MagickPath = $deps.MagickPath

# 3. Input Processing & Auto-Detection
$imageExtensions = @('.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff', '.tif', '.gif', '.heic')
$videoExtensions = @('.mp4', '.mkv', '.mov', '.avi', '.m4v', '.webm', '.flv', '.3gp')

$imageFiles = @()
$videoFiles = @()

foreach ($arg in $args) {
    if (Test-Path $arg) {
        $item = Get-Item $arg
        if ($item.PSIsContainer) {
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
