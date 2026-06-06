# Alit Converter by Curlyzed (Universal Edition) - Updated
$Header = @"
============================================
          Alit Converter by Curlyzed
              Version 0.1 Alpha
============================================
"@

Clear-Host
Write-Host $Header -ForegroundColor Cyan

# 0. Dependency Check
Write-Host "[SYSTEM CHECK] Checking dependencies..." -ForegroundColor Gray
$ffmpegExists = Get-Command ffmpeg -ErrorAction SilentlyContinue
$ffprobeExists = Get-Command ffprobe -ErrorAction SilentlyContinue
$magickExists = Get-Command magick -ErrorAction SilentlyContinue

if (!$ffmpegExists -or !$ffprobeExists) {
    Write-Host "ERROR: ffmpeg and/or ffprobe could not be found in your system PATH." -ForegroundColor Red
    Write-Host "Please install FFmpeg and make sure it is added to your environment variables." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

if (!$magickExists) {
    Write-Host "[WARNING] ImageMagick ('magick') was not found in your system PATH." -ForegroundColor Yellow
    Write-Host "          Image conversion options will be disabled." -ForegroundColor Yellow
}

# 1. Input Processing & Auto-Detection
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

$processVideos = $false
$processImages = $false

$processVideos = $false
$processImages = $false
$mode = ""
$hasMixedFiles = $false

if ($videoFiles.Count -gt 0 -and $imageFiles.Count -gt 0) {
    $hasMixedFiles = $true
    $step = 0
} elseif ($videoFiles.Count -gt 0) {
    $mode = "VideosOnly"
    $processVideos = $true
    $step = 1
} elseif ($imageFiles.Count -gt 0) {
    $mode = "ImagesOnly"
    $processImages = $true
    $step = 4
}

# Safeguard if ImageMagick is missing but image conversion is requested
if ($processImages -and !$magickExists) {
    Write-Host "`nERROR: Image conversion was requested, but ImageMagick ('magick') is not in your PATH." -ForegroundColor Red
    if ($videoFiles.Count -gt 0) {
        Write-Host "Proceeding with Videos only..." -ForegroundColor Yellow
        $processImages = $false
        $mode = "VideosOnly"
        $processVideos = $true
        $step = 1
    } else {
        Write-Host "Cannot proceed. Please install ImageMagick and try again." -ForegroundColor Yellow
        Write-Host "`nPress any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
}

# 2. Config Menus State Machine

$codecChoice = $null
$resChoice = $null
$targetHeight = $null
$bitChoice = $null
$targetBitrate = $null
$imageFormatChoice = $null
$jpgQuality = $null
$webQuality = $null
$webResChoice = $null
$webHeight = $null

while ($step -ge 0 -and $step -le 6) {
    # --- STEP 0: Mixed Files Router ---
    if ($step -eq 0) {
        Write-Host "`nBoth Images ($($imageFiles.Count)) and Videos ($($videoFiles.Count)) detected." -ForegroundColor Yellow
        Write-Host "What do you want to process?"
        Write-Host "1. Videos only"
        Write-Host "2. Images only"
        Write-Host "3. Both sequentially"
        Write-Host "Q. Quit / Exit"
        $choice = Read-Host "Pick (1-3, Q to Quit)"
        
        if ($choice -eq "1") {
            $mode = "VideosOnly"
            $processVideos = $true
            $processImages = $false
            $step = 1
            continue
        } elseif ($choice -eq "2") {
            # Check ImageMagick again in case they chose images now
            if (!$magickExists) {
                Write-Host "`nERROR: ImageMagick is not installed. Cannot process images." -ForegroundColor Red
                continue
            }
            $mode = "ImagesOnly"
            $processImages = $true
            $processVideos = $false
            $step = 4
            continue
        } elseif ($choice -eq "3") {
            if (!$magickExists) {
                Write-Host "`nERROR: ImageMagick is not installed. Cannot process images sequentially." -ForegroundColor Red
                continue
            }
            $mode = "Both"
            $processVideos = $true
            $processImages = $true
            $step = 1
            continue
        } elseif ($choice -match '^[Qq]$') {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            exit
        }
        Write-Host "Invalid choice. Please select 1, 2, 3, or Q." -ForegroundColor Red
        continue
    }

    # --- STEP 1: Video Codec Menu ---
    if ($step -eq 1) {
        Write-Host "`nSELECT VIDEO CODEC" -ForegroundColor Yellow
        Write-Host "1. H.264 (Maximum Compatibility)"
        Write-Host "2. H.265 / HEVC (Better File Size)"
        Write-Host "3. AV1 (Best Size/Quality - Needs Modern GPU)"
        if ($hasMixedFiles) {
            Write-Host "B. Back to Main Option"
        } else {
            Write-Host "Q. Quit / Exit"
        }
        $choice = Read-Host "Pick (1-3, B/Q)"
        
        if ($choice -match '^[1-3]$') {
            $codecChoice = $choice
            $step = 2
            continue
        } elseif ($choice -match '^[Bb]$') {
            if ($hasMixedFiles) {
                $step = 0
            } else {
                Write-Host "Cannot go back further." -ForegroundColor Yellow
            }
            continue
        } elseif ($choice -match '^[Qq]$') {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            exit
        }
        Write-Host "Invalid choice. Please select 1-3, B, or Q." -ForegroundColor Red
        continue
    }

    # --- STEP 2: Video Resolution Menu ---
    if ($step -eq 2) {
        Write-Host "`nSELECT TARGET RESOLUTION" -ForegroundColor Yellow
        Write-Host "1. 480p | 2. 720p | 3. 1080p | 4. 1440p (2k) | 5. 2160p (4k) | 6. CUSTOM | 7. ORIGINAL"
        Write-Host "B. Back to Codec Menu"
        Write-Host "Q. Quit / Exit"
        $choice = Read-Host "Pick (1-7, B/Q)"
        
        if ($choice -match '^[1-7]$') {
            $resChoice = $choice
            
            if ($resChoice -eq "6") {
                $tempHeight = $null
                while ($true) {
                    $customHeightInput = Read-Host "Enter custom height (must be an even integer, e.g., 864, or B to go back)"
                    if ($customHeightInput -match '^[Bb]$') {
                        $tempHeight = "BACK"
                        break
                    }
                    if ($customHeightInput -match '^\d+$' -and [int]$customHeightInput -gt 0) {
                        $heightVal = [int]$customHeightInput
                        if ($heightVal % 2 -ne 0) {
                            $heightVal = $heightVal + 1
                            Write-Host "Adjusted custom height to even number: $heightVal" -ForegroundColor Cyan
                        }
                        $tempHeight = $heightVal
                        break
                    }
                    Write-Host "Invalid input. Please enter a positive integer." -ForegroundColor Red
                }
                if ($tempHeight -eq "BACK") {
                    continue
                }
                $targetHeight = $tempHeight
            } elseif ($resChoice -eq "7") {
                $targetHeight = "ORIGINAL"
            } else {
                $heights = @{ "1"="480"; "2"="720"; "3"="1080"; "4"="1440"; "5"="2160" }
                $targetHeight = $heights[$resChoice]
            }
            
            $step = 3
            continue
        } elseif ($choice -match '^[Bb]$') {
            $step = 1
            continue
        } elseif ($choice -match '^[Qq]$') {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            exit
        }
        Write-Host "Invalid choice. Please select 1-7, B, or Q." -ForegroundColor Red
        continue
    }

    # --- STEP 3: Video Bitrate Menu ---
    if ($step -eq 3) {
        Write-Host "`nSELECT BITRATE (kbps)" -ForegroundColor Yellow
        Write-Host "1. 1k | 2. 2k | 3. 5k | 4. 10k | 5. 15k | 6. 20k | 7. CUSTOM | 8. ORIGINAL (Auto/CRF)"
        Write-Host "B. Back to Resolution Menu"
        Write-Host "Q. Quit / Exit"
        $choice = Read-Host "Pick (1-8, B/Q)"
        
        if ($choice -match '^[1-8]$') {
            $bitChoice = $choice
            
            if ($bitChoice -eq "7") {
                $tempBitrate = $null
                while ($true) {
                    $customBitrateInput = Read-Host "Enter custom bitrate in kbps (e.g., 8000, or B to go back)"
                    if ($customBitrateInput -match '^[Bb]$') {
                        $tempBitrate = "BACK"
                        break
                    }
                    if ($customBitrateInput -match '^\d+$' -and [int]$customBitrateInput -gt 0) {
                        $tempBitrate = [int]$customBitrateInput
                        break
                    }
                    Write-Host "Invalid input. Please enter a positive integer." -ForegroundColor Red
                }
                if ($tempBitrate -eq "BACK") {
                    continue
                }
                $targetBitrate = $tempBitrate
                $maxBitrate = $targetBitrate + ($targetBitrate / 4)
                $bufSize = $targetBitrate * 2
            } elseif ($bitChoice -eq "8") {
                $targetBitrate = "ORIGINAL"
            } else {
                $bitrates = @{ "1"="1000"; "2"="2000"; "3"="5000"; "4"="10000"; "5"="15000"; "6"="20000" }
                $targetBitrate = $bitrates[$bitChoice]
                if ($targetBitrate) {
                    $maxBitrate = [int]$targetBitrate + ([int]$targetBitrate / 4)
                    $bufSize = [int]$targetBitrate * 2
                }
            }
            
            if ($mode -eq "Both") {
                $step = 4
            } else {
                $step = 7
            }
            continue
        } elseif ($choice -match '^[Bb]$') {
            $step = 2
            continue
        } elseif ($choice -match '^[Qq]$') {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            exit
        }
        Write-Host "Invalid choice. Please select 1-8, B, or Q." -ForegroundColor Red
        continue
    }

    # --- STEP 4: Image Format Menu ---
    if ($step -eq 4) {
        Write-Host "`nSELECT TARGET IMAGE FORMAT" -ForegroundColor Yellow
        Write-Host "1. JPG (Joint Photographic Experts Group)"
        Write-Host "2. PDF (Portable Document Format - Multi-page if multiple selected)"
        Write-Host "3. PNG (Portable Network Graphics)"
        Write-Host "4. WEB (WebP format for high quality web compression)"
        if ($mode -eq "Both") {
            Write-Host "B. Back to Video Bitrate Menu"
        } elseif ($hasMixedFiles) {
            Write-Host "B. Back to Main Option"
        } else {
            Write-Host "Q. Quit / Exit"
        }
        $choice = Read-Host "Pick (1-4, B/Q)"
        
        if ($choice -match '^[1-4]$') {
            $imageFormatChoice = $choice
            if ($imageFormatChoice -eq "1" -or $imageFormatChoice -eq "4") {
                $step = 5
            } else {
                $step = 7
            }
            continue
        } elseif ($choice -match '^[Bb]$') {
            if ($mode -eq "Both") {
                $step = 3
            } elseif ($hasMixedFiles) {
                $step = 0
            } else {
                Write-Host "Cannot go back further." -ForegroundColor Yellow
            }
            continue
        } elseif ($choice -match '^[Qq]$') {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            exit
        }
        Write-Host "Invalid choice. Please select 1-4, B, or Q." -ForegroundColor Red
        continue
    }

    # --- STEP 5: Image Sub-Menu A (JPG Quality or WEB Resolution) ---
    if ($step -eq 5) {
        if ($imageFormatChoice -eq "1") {
            # JPG Quality
            Write-Host "`nSELECT JPG QUALITY" -ForegroundColor Yellow
            Write-Host "1. 20% | 2. 40% | 3. 60% | 4. 80% | 5. CUSTOM | 6. ORIGINAL"
            Write-Host "B. Back to Image Format Menu"
            Write-Host "Q. Quit / Exit"
            $choice = Read-Host "Pick (1-6, B/Q)"
            
            if ($choice -match '^[1-6]$') {
                if ($choice -eq "5") {
                    $tempQuality = $null
                    while ($true) {
                        $customQualityInput = Read-Host "Enter custom quality (1-100, or B to go back)"
                        if ($customQualityInput -match '^[Bb]$') {
                            $tempQuality = "BACK"
                            break
                        }
                        if ($customQualityInput -match '^\d+$' -and [int]$customQualityInput -ge 1 -and [int]$customQualityInput -le 100) {
                            $tempQuality = [int]$customQualityInput
                            break
                        }
                        Write-Host "Invalid input. Please enter an integer between 1 and 100." -ForegroundColor Red
                    }
                    if ($tempQuality -eq "BACK") {
                        continue
                    }
                    $jpgQuality = $tempQuality
                } elseif ($choice -eq "6") {
                    $jpgQuality = "ORIGINAL"
                } else {
                    $qualities = @{ "1"=20; "2"=40; "3"=60; "4"=80 }
                    $jpgQuality = $qualities[$choice]
                }
                $step = 7
                continue
            } elseif ($choice -match '^[Bb]$') {
                $step = 4
                continue
            } elseif ($choice -match '^[Qq]$') {
                Write-Host "`nExiting..." -ForegroundColor Yellow
                exit
            }
            Write-Host "Invalid choice. Please select 1-6, B, or Q." -ForegroundColor Red
            continue
        }
        
        if ($imageFormatChoice -eq "4") {
            # WEB Resolution
            Write-Host "`nSELECT WEB Target Resolution / Scale" -ForegroundColor Yellow
            Write-Host "1. 30% | 2. 50% | 3. 80% | 4. CUSTOM | 5. ORIGINAL"
            Write-Host "B. Back to Image Format Menu"
            Write-Host "Q. Quit / Exit"
            $choice = Read-Host "Pick (1-5, B/Q)"
            
            if ($choice -match '^[1-5]$') {
                $tempResChoice = $choice
                if ($tempResChoice -eq "4") {
                    $tempHeight = $null
                    while ($true) {
                        $customHeightInput = Read-Host "Enter custom height in pixels (locking aspect ratio, e.g., 600, or B to go back)"
                        if ($customHeightInput -match '^[Bb]$') {
                            $tempHeight = "BACK"
                            break
                        }
                        if ($customHeightInput -match '^\d+$' -and [int]$customHeightInput -gt 0) {
                            $tempHeight = [int]$customHeightInput
                            break
                        }
                        Write-Host "Invalid input. Please enter a positive integer." -ForegroundColor Red
                    }
                    if ($tempHeight -eq "BACK") {
                        continue
                    }
                    $webHeight = $tempHeight
                }
                $webResChoice = $tempResChoice
                $step = 6
                continue
            } elseif ($choice -match '^[Bb]$') {
                $step = 4
                continue
            } elseif ($choice -match '^[Qq]$') {
                Write-Host "`nExiting..." -ForegroundColor Yellow
                exit
            }
            Write-Host "Invalid choice. Please select 1-5, B, or Q." -ForegroundColor Red
            continue
        }
    }

    # --- STEP 6: Image Sub-Menu B (WEB Quality) ---
    if ($step -eq 6) {
        Write-Host "`nSELECT WEB QUALITY" -ForegroundColor Yellow
        Write-Host "1. 50% | 2. 60% | 3. 80% | 4. 90% | 5. CUSTOM"
        Write-Host "B. Back to WEB Resolution Menu"
        Write-Host "Q. Quit / Exit"
        $choice = Read-Host "Pick (1-5, B/Q)"
        
        if ($choice -match '^[1-5]$') {
            if ($choice -eq "5") {
                $tempQuality = $null
                while ($true) {
                    $customQualityInput = Read-Host "Enter custom quality (1-100, or B to go back)"
                    if ($customQualityInput -match '^[Bb]$') {
                        $tempQuality = "BACK"
                        break
                    }
                    if ($customQualityInput -match '^\d+$' -and [int]$customQualityInput -ge 1 -and [int]$customQualityInput -le 100) {
                        $tempQuality = [int]$customQualityInput
                        break
                    }
                    Write-Host "Invalid input. Please enter an integer between 1 and 100." -ForegroundColor Red
                }
                if ($tempQuality -eq "BACK") {
                    continue
                }
                $webQuality = $tempQuality
            } else {
                $qualities = @{ "1"=50; "2"=60; "3"=80; "4"=90 }
                $webQuality = $qualities[$choice]
            }
            $step = 7
            continue
        } elseif ($choice -match '^[Bb]$') {
            $step = 5
            continue
        } elseif ($choice -match '^[Qq]$') {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            exit
        }
        Write-Host "Invalid choice. Please select 1-5, B, or Q." -ForegroundColor Red
        continue
    }
}

# Helper to get a unique file path by appending a numeric suffix counter
function Get-UniqueFilePath {
    param (
        [string]$filePath
    )
    $dir = Split-Path $filePath -Parent
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
    $ext = [System.IO.Path]::GetExtension($filePath)
    
    $counter = 1
    while ($true) {
        $candidatePath = Join-Path $dir "${baseName}_$counter$ext"
        if (!(Test-Path $candidatePath)) {
            return $candidatePath
        }
        $counter++
    }
}

# Helper to resolve file conflicts
# Returns the resolved file path to write to, or $null if we should skip
$globalConflictAction = $null

function Get-ConflictResolution {
    param (
        [string]$filePath
    )
    
    if (!(Test-Path $filePath)) {
        return $filePath
    }
    
    if ($global:globalConflictAction -eq "OverwriteAll") {
        return $filePath
    }
    
    if ($global:globalConflictAction -eq "SkipAll") {
        Write-Host "[SKIP] Already exists: $filePath" -ForegroundColor Yellow
        return $null
    }
    
    if ($global:globalConflictAction -eq "AutoRenameAll") {
        return Get-UniqueFilePath -filePath $filePath
    }
    
    $fileName = Split-Path $filePath -Leaf
    while ($true) {
        Write-Host "`n[CONFLICT] File already exists: $fileName" -ForegroundColor Yellow
        Write-Host "What would you like to do?"
        Write-Host "1. Overwrite this file"
        Write-Host "2. Overwrite all subsequent conflicts"
        Write-Host "3. Skip this file"
        Write-Host "4. Skip all subsequent conflicts"
        Write-Host "5. Auto-rename this file"
        Write-Host "6. Auto-rename all subsequent conflicts"
        Write-Host "Q. Quit / Exit"
        
        $choice = Read-Host "Pick (1-6, Q)"
        if ($choice -eq "1") {
            return $filePath
        } elseif ($choice -eq "2") {
            $global:globalConflictAction = "OverwriteAll"
            return $filePath
        } elseif ($choice -eq "3") {
            Write-Host "[SKIP] Skipped: $fileName" -ForegroundColor Yellow
            return $null
        } elseif ($choice -eq "4") {
            $global:globalConflictAction = "SkipAll"
            Write-Host "[SKIP] Skipped: $fileName" -ForegroundColor Yellow
            return $null
        } elseif ($choice -eq "5") {
            $newPath = Get-UniqueFilePath -filePath $filePath
            $newFileName = Split-Path $newPath -Leaf
            Write-Host "[RENAME] Renamed to: $newFileName" -ForegroundColor Cyan
            return $newPath
        } elseif ($choice -eq "6") {
            $global:globalConflictAction = "AutoRenameAll"
            $newPath = Get-UniqueFilePath -filePath $filePath
            $newFileName = Split-Path $newPath -Leaf
            Write-Host "[RENAME] Renamed to: $newFileName" -ForegroundColor Cyan
            return $newPath
        } elseif ($choice -match '^[Qq]$') {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            exit
        }
        Write-Host "Invalid choice. Please select 1-6, or Q." -ForegroundColor Red
    }
}

# 3. Processing Execution

# A. Video Processing
if ($processVideos) {
    # --- UNIVERSAL GPU AUTO-DETECT & CODEC MAPPING ---
    Write-Host "`n[SYSTEM CHECK] Configuring hardware pipeline..." -ForegroundColor Gray
    $gpus = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
    $gpuString = $gpus -join " "

    # Default CPU Fallbacks
    if ($codecChoice -eq "1") { $encoder = "libx264"; $encArgs = "-preset fast"; $ext = "mp4" }
    if ($codecChoice -eq "2") { $encoder = "libx265"; $encArgs = "-preset fast"; $ext = "mp4" }
    if ($codecChoice -eq "3") { $encoder = "libaom-av1"; $encArgs = "-cpu-used 6"; $ext = "mkv" }
    $hwName = "CPU (Software Fallback)"

    # NVIDIA Hardware
    if ($gpuString -match "NVIDIA") {
        $hwName = "NVIDIA NVENC"
        if ($codecChoice -eq "1") { $encoder = "h264_nvenc"; $encArgs = "-preset p4 -tune hq"; $ext = "mp4" }
        if ($codecChoice -eq "2") { $encoder = "hevc_nvenc"; $encArgs = "-preset p4 -tune hq"; $ext = "mp4" }
        if ($codecChoice -eq "3") { $encoder = "av1_nvenc"; $encArgs = "-preset p4 -tune hq"; $ext = "mkv" }
    } 
    # AMD Hardware
    elseif ($gpuString -match "AMD" -or $gpuString -match "Radeon") {
        $hwName = "AMD AMF"
        if ($codecChoice -eq "1") { $encoder = "h264_amf"; $encArgs = "-quality quality"; $ext = "mp4" }
        if ($codecChoice -eq "2") { $encoder = "hevc_amf"; $encArgs = "-quality quality"; $ext = "mp4" }
        if ($codecChoice -eq "3") { $encoder = "av1_amf"; $encArgs = "-quality quality"; $ext = "mkv" }
    } 
    # Intel Hardware
    elseif ($gpuString -match "Intel") {
        $hwName = "Intel QuickSync"
        if ($codecChoice -eq "1") { $encoder = "h264_qsv"; $encArgs = "-preset medium"; $ext = "mp4" }
        if ($codecChoice -eq "2") { $encoder = "hevc_qsv"; $encArgs = "-preset medium"; $ext = "mp4" }
        if ($codecChoice -eq "3") { $encoder = "av1_qsv"; $encArgs = "-preset medium"; $ext = "mkv" }
    }

    Write-Host "-> Hardware : $hwName" -ForegroundColor Green
    Write-Host "-> Encoder  : $encoder" -ForegroundColor Green
    # -------------------------------------------------

    foreach ($file in $videoFiles) {
        # Formatting the output filename based on choices
        $resTag = if ($targetHeight -eq "ORIGINAL") { "origRes" } else { "$($targetHeight)p" }
        $bitTag = if ($targetBitrate -eq "ORIGINAL") { "origBit" } else { "$($targetBitrate)k" }
        $outFile = "$($file.DirectoryName)\$($file.BaseName)_$($resTag)_$($bitTag).$ext"
        
        $resolvedOutFile = Get-ConflictResolution -filePath $outFile
        if (!$resolvedOutFile) { continue }

        Write-Host "`n[ANALYZING] $($file.Name)..." -ForegroundColor Gray
        $totalFrames = & ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=noprint_wrappers=1:nokey=1 "$($file.FullName)"
        if ($totalFrames -eq "N/A" -or !$totalFrames) { $totalFrames = 1000 }

        Write-Host "[WORKING]  Encoding video (Audio Copy)..." -ForegroundColor Green

        $errLogPath = "$env:TEMP\ffmpeg_err.log"
        if (Test-Path $errLogPath) { Remove-Item $errLogPath }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "cmd.exe"
        
        # --- DYNAMIC FLAG CONSTRUCTION ---
        # 1. Video Filter (Scaling)
        $vfFlag = if ($targetHeight -eq "ORIGINAL") { "" } else { "-vf `"scale=-2:$targetHeight,format=yuv420p`"" }
        
        # 2. Bitrate Flags
        $bitrateFlags = ""
        if ($targetBitrate -eq "ORIGINAL") {
            switch ($encoder) {
                "libx264"    { $bitrateFlags = "-crf 23" }
                "libx265"    { $bitrateFlags = "-crf 23" }
                "libaom-av1" { $bitrateFlags = "-crf 30" }
                "h264_nvenc" { $bitrateFlags = "-rc constqp -qp 23" }
                "hevc_nvenc" { $bitrateFlags = "-rc constqp -qp 23" }
                "av1_nvenc"  { $bitrateFlags = "-rc constqp -qp 23" }
                "h264_amf"   { $bitrateFlags = "-rc cqp -qp_i 23 -qp_p 23" }
                "hevc_amf"   { $bitrateFlags = "-rc cqp -qp_i 23 -qp_p 23" }
                "av1_amf"    { $bitrateFlags = "-rc cqp -qp_i 23 -qp_p 23" }
                "h264_qsv"   { $bitrateFlags = "-global_quality 23" }
                "hevc_qsv"   { $bitrateFlags = "-global_quality 23" }
                "av1_qsv"    { $bitrateFlags = "-global_quality 23" }
                default      { $bitrateFlags = "" }
            }
        } else {
            $bitrateFlags = "-b:v $($targetBitrate)k -maxrate $($maxBitrate)k -bufsize $($bufSize)k"
        }

        # 3. Final Command (using -c:a copy to maintain original audio)
        $ffmpegCmd = "ffmpeg -hide_banner -i `"$($file.FullName)`" $vfFlag -c:v $encoder $encArgs $bitrateFlags -map 0:v:0 -map 0:a? -c:a copy -fps_mode cfr -y -progress pipe:1 `"$resolvedOutFile`" 2> `"$errLogPath`""
        
        $psi.Arguments = "/c $ffmpegCmd"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.CreateNoWindow = $true
        
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $p.Start() | Out-Null
        
        while (!$p.StandardOutput.EndOfStream) {
            $line = $p.StandardOutput.ReadLine()
            if ($line -match "frame=(\d+)") {
                $cur = [int]$matches[1]
                $pct = ($cur / $totalFrames) * 100
                if ($pct -gt 100) { $pct = 100 }
                Write-Progress -Activity "Alit Converter" -Status "Converting: $($file.Name)" -PercentComplete $pct
            }
        }
        $p.WaitForExit()
        Write-Progress -Activity "Alit Converter" -Completed

        if ($p.ExitCode -eq 0 -and (Test-Path $resolvedOutFile)) {
            Write-Host "[SUCCESS] Saved: $(Split-Path $resolvedOutFile -Leaf)" -ForegroundColor Cyan
        } else {
            Write-Host "[ERROR] FFmpeg failed. Code: $($p.ExitCode)" -ForegroundColor Red
            Write-Host "--- WHAT FFMPEG ACTUALLY SAID ---" -ForegroundColor Yellow
            if (Test-Path $errLogPath) { Get-Content $errLogPath | Write-Host -ForegroundColor DarkRed }
            Write-Host "---------------------------------" -ForegroundColor Yellow
            if (Test-Path $resolvedOutFile) { Remove-Item $resolvedOutFile }
        }
    }
}

# B. Image Processing
if ($processImages) {
    Write-Host "`n[WORKING] Processing images..." -ForegroundColor Green
    
    if ($imageFormatChoice -eq "2") {
        # PDF format
        if ($imageFiles.Count -eq 1) {
            $file = $imageFiles[0]
            $outFile = "$($file.DirectoryName)\$($file.BaseName).pdf"
        } else {
            $firstFile = $imageFiles[0]
            $outFile = "$($firstFile.DirectoryName)\Merged_Images.pdf"
        }
        
        $resolvedOutFile = Get-ConflictResolution -filePath $outFile
        if (!$resolvedOutFile) {
            # Skipped
        } else {
            Write-Host "[WORKING] Merging $($imageFiles.Count) images into $resolvedOutFile..." -ForegroundColor Green
            # Construct args for magick
            $magickArgs = @()
            foreach ($img in $imageFiles) {
                $magickArgs += "`"$($img.FullName)`""
            }
            $magickArgs += "`"$resolvedOutFile`""
            
            $cmdLine = "magick " + ($magickArgs -join " ")
            
            $errLogPath = "$env:TEMP\magick_pdf_err.log"
            if (Test-Path $errLogPath) { Remove-Item $errLogPath }
            
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c $cmdLine 2> `"$errLogPath`""
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $psi
            $p.Start() | Out-Null
            $p.WaitForExit()
            
            if ($p.ExitCode -eq 0 -and (Test-Path $resolvedOutFile)) {
                Write-Host "[SUCCESS] Saved PDF: $resolvedOutFile" -ForegroundColor Cyan
            } else {
                Write-Host "[ERROR] ImageMagick PDF merge failed. Code: $($p.ExitCode)" -ForegroundColor Red
                if (Test-Path $errLogPath) { Get-Content $errLogPath | Write-Host -ForegroundColor DarkRed }
            }
        }
    } else {
        # JPG, PNG, or WEB formats
        $totalImages = $imageFiles.Count
        $index = 0
        
        foreach ($file in $imageFiles) {
            $index++
            $pct = ($index / $totalImages) * 100
            
            $formatExt = ""
            $magickQualityFlags = ""
            $qualityTag = ""
            
            if ($imageFormatChoice -eq "1") { # JPG
                $formatExt = "jpg"
                if ($jpgQuality -eq "ORIGINAL") {
                    $qualityTag = "_orig"
                } else {
                    $qualityTag = "_q$jpgQuality"
                    $magickQualityFlags = "-quality $jpgQuality"
                }
            } elseif ($imageFormatChoice -eq "3") { # PNG
                $formatExt = "png"
            } elseif ($imageFormatChoice -eq "4") { # WEB (webp)
                $formatExt = "webp"
                
                $resizeFlag = ""
                $resTag = ""
                if ($webResChoice -eq "1") {
                    $resizeFlag = "-resize 30%"
                    $resTag = "_30pct"
                } elseif ($webResChoice -eq "2") {
                    $resizeFlag = "-resize 50%"
                    $resTag = "_50pct"
                } elseif ($webResChoice -eq "3") {
                    $resizeFlag = "-resize 80%"
                    $resTag = "_80pct"
                } elseif ($webResChoice -eq "4") {
                    $resizeFlag = "-resize x$webHeight"
                    $resTag = "_h$webHeight"
                } else {
                    $resTag = "_orig"
                }
                
                $qualityTag = "${resTag}_q$webQuality"
                $magickQualityFlags = "$resizeFlag -quality $webQuality"
            }
            
            $outFile = "$($file.DirectoryName)\$($file.BaseName)$qualityTag.$formatExt"
            
            if ($file.FullName -eq $outFile) {
                Write-Host "[SKIP] Input and output paths are identical: $($file.Name)" -ForegroundColor Yellow
                continue
            }
            
            $resolvedOutFile = Get-ConflictResolution -filePath $outFile
            if (!$resolvedOutFile) {
                continue
            }
            
            Write-Host "[WORKING] Converting $($file.Name) to $formatExt..." -ForegroundColor Green
            Write-Progress -Activity "Alit Converter" -Status "Converting image: $($file.Name)" -PercentComplete $pct
            
            $errLogPath = "$env:TEMP\magick_err.log"
            if (Test-Path $errLogPath) { Remove-Item $errLogPath }
            
            $magickCmd = "magick `"$($file.FullName)`" $magickQualityFlags `"$resolvedOutFile`""
            
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c $magickCmd 2> `"$errLogPath`""
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $psi
            $p.Start() | Out-Null
            $p.WaitForExit()
            
            if ($p.ExitCode -eq 0 -and (Test-Path $resolvedOutFile)) {
                Write-Host "[SUCCESS] Saved: $(Split-Path $resolvedOutFile -Leaf)" -ForegroundColor Cyan
            } else {
                Write-Host "[ERROR] ImageMagick failed for $($file.Name). Code: $($p.ExitCode)" -ForegroundColor Red
                if (Test-Path $errLogPath) { Get-Content $errLogPath | Write-Host -ForegroundColor DarkRed }
                if (Test-Path $resolvedOutFile) { Remove-Item $resolvedOutFile }
            }
        }
        Write-Progress -Activity "Alit Converter" -Completed
    }
}

Write-Host "`nAll tasks complete! Press any key..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")