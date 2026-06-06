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

# --- START OF MODULE: ImageProcessor.ps1 ---
function Invoke-ImageConversion {
    <#
    .SYNOPSIS
        Main execution loop for converting image files with ImageMagick.
    .PARAMETER imageFiles
        An array of FileInfo objects for images to convert.
    .PARAMETER config
        The configuration object returned by Show-ConfigMenus.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$imageFiles,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$config
    )

    $imageFormatChoice = $config.ImageFormatChoice
    $jpgQuality = $config.JpgQuality
    $webQuality = $config.WebQuality
    $webResChoice = $config.WebResChoice
    $webHeight = $config.WebHeight

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
            
            $cmdLine = "`"$global:MagickPath`" " + ($magickArgs -join " ")
            
            $errLogPath = "$env:TEMP\magick_pdf_err.log"
            if (Test-Path $errLogPath) { Remove-Item $errLogPath }
            
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c @cd . & $cmdLine 2> `"$errLogPath`""
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
            
            $magickCmd = "`"$global:MagickPath`" `"$($file.FullName)`" $magickQualityFlags `"$resolvedOutFile`""
            
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c @cd . & $magickCmd 2> `"$errLogPath`""
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

# --- END OF MODULE: ImageProcessor.ps1 ---

# --- START OF MODULE: VideoProcessor.ps1 ---
function Invoke-VideoConversion {
    <#
    .SYNOPSIS
        Main execution loop for converting video files with FFmpeg using progress feedback.
    .PARAMETER videoFiles
        An array of FileInfo objects for videos to convert.
    .PARAMETER config
        The configuration object returned by Show-ConfigMenus.
    .PARAMETER gpuCaps
        The GPU encoder capability mapping returned by Get-GpuEncoder.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$videoFiles,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$config,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$gpuCaps
    )

    $targetHeight = $config.TargetHeight
    $targetBitrate = $config.TargetBitrate
    $encoder = $gpuCaps.Encoder
    $encArgs = $gpuCaps.EncoderArgs
    $ext = $gpuCaps.Extension

    $maxBitrate = $null
    $bufSize = $null
    if ($targetBitrate -ne "ORIGINAL" -and $targetBitrate) {
        $maxBitrate = [int]$targetBitrate + ([int]$targetBitrate / 4)
        $bufSize = [int]$targetBitrate * 2
    }

    foreach ($file in $videoFiles) {
        # Formatting the output filename based on choices
        $resTag = if ($targetHeight -eq "ORIGINAL") { "origRes" } else { "$($targetHeight)p" }
        $bitTag = if ($targetBitrate -eq "ORIGINAL") { "origBit" } else { "$($targetBitrate)k" }
        $outFile = "$($file.DirectoryName)\$($file.BaseName)_$($resTag)_$($bitTag).$ext"
        
        $resolvedOutFile = Get-ConflictResolution -filePath $outFile
        if (!$resolvedOutFile) { continue }

        Write-Host "`n[ANALYZING] $($file.Name)..." -ForegroundColor Gray
        $totalFrames = & $global:FfprobePath -v error -select_streams v:0 -show_entries stream=nb_frames -of default=noprint_wrappers=1:nokey=1 "$($file.FullName)"
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
                "h264_nvenc" { $bitrateFlags = "-qp 23" }
                "hevc_nvenc" { $bitrateFlags = "-qp 23" }
                "av1_nvenc"  { $bitrateFlags = "-qp 23" }
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
        $ffmpegCmd = "`"$global:FfmpegPath`" -hide_banner -i `"$($file.FullName)`" $vfFlag -c:v $encoder $encArgs $bitrateFlags -map 0:v:0 -map 0:a? -c:a copy -fps_mode cfr -y -progress pipe:1 `"$resolvedOutFile`" 2> `"$errLogPath`""
        
        $psi.Arguments = "/c @cd . & $ffmpegCmd"
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

# --- END OF MODULE: VideoProcessor.ps1 ---

# --- START OF MODULE: DependencyChecker.ps1 ---
function Get-SystemDependencies {
    <#
    .SYNOPSIS
        Checks if required command-line tools are available in the local bin/ folder or the system PATH.
    .PARAMETER AppDir
        The root directory of the application where the local bin/ folder is located.
    .OUTPUTS
        [PSCustomObject] containing booleans and paths for Ffmpeg, Ffprobe, and Magick.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppDir
    )

    $localBin = Join-Path $AppDir "bin"
    $ffmpegPath = ""
    $ffprobePath = ""
    $magickPath = ""

    # 1. Resolve ffmpeg
    $localFfmpeg = Join-Path $localBin "ffmpeg.exe"
    if (Test-Path $localFfmpeg) {
        $ffmpegPath = $localFfmpeg
    } else {
        $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($cmd) { $ffmpegPath = $cmd.Source }
    }

    # 2. Resolve ffprobe
    $localFfprobe = Join-Path $localBin "ffprobe.exe"
    if (Test-Path $localFfprobe) {
        $ffprobePath = $localFfprobe
    } else {
        $cmd = Get-Command ffprobe -ErrorAction SilentlyContinue
        if ($cmd) { $ffprobePath = $cmd.Source }
    }

    # 3. Resolve magick
    $localMagick = Join-Path $localBin "magick.exe"
    if (Test-Path $localMagick) {
        $magickPath = $localMagick
    } else {
        $cmd = Get-Command magick -ErrorAction SilentlyContinue
        if ($cmd) { $magickPath = $cmd.Source }
    }

    return [PSCustomObject]@{
        FfmpegExists  = [bool]$ffmpegPath
        FfprobeExists = [bool]$ffprobePath
        MagickExists  = [bool]$magickPath
        FfmpegPath    = $ffmpegPath
        FfprobePath   = $ffprobePath
        MagickPath    = $magickPath
    }
}

# --- END OF MODULE: DependencyChecker.ps1 ---

# --- START OF MODULE: DependencyInstaller.ps1 ---
# DependencyInstaller.ps1
# Contains logic to automatically download and extract portable binaries for FFmpeg and ImageMagick.

function Install-PortableDependencies {
    <#
    .SYNOPSIS
        Downloads and installs FFmpeg and ImageMagick portable binaries into the local bin/ folder.
    .PARAMETER AppDir
        The root directory of the application where the bin/ folder will be created.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppDir
    )

    $localBin = Join-Path $AppDir "bin"
    if (!(Test-Path $localBin)) {
        New-Item -ItemType Directory -Path $localBin -Force | Out-Null
    }

    # Helper function for downloads with visual feedback
    function Start-FileDownload {
        param (
            [string]$url,
            [string]$outPath,
            [string]$activity
        )
        Write-Host "[DOWNLOAD] Downloading $activity..." -ForegroundColor Cyan
        
        # Ensure TLS 1.2 is active for external downloads
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Add-Type -AssemblyName System.Net.Http
        
        $httpClient = $null
        $response = $null
        $downloadStream = $null
        $fileStream = $null
        
        try {
            $httpClient = New-Object System.Net.Http.HttpClient
            $response = $httpClient.GetAsync($url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            
            if (!$response.IsSuccessStatusCode) {
                throw "HTTP Request failed with status code $($response.StatusCode)"
            }
            
            $contentLength = $response.Content.Headers.ContentLength
            $downloadStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $fileStream = [System.IO.File]::Create($outPath)
            
            $buffer = New-Object byte[] 65536 # 64KB chunks
            $totalBytesRead = 0
            $startWatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Write a dummy initial progress bar
            Write-Host -NoNewline "Progress: [                              ] 0% (0.00 MB / 0.00 MB)"
            
            while ($true) {
                $bytesRead = $downloadStream.Read($buffer, 0, $buffer.Length)
                if ($bytesRead -eq 0) { break }
                
                $fileStream.Write($buffer, 0, $bytesRead)
                $totalBytesRead += $bytesRead
                
                if ($contentLength) {
                    $percent = [int](($totalBytesRead / $contentLength) * 100)
                    $mbRead = [math]::Round($totalBytesRead / 1MB, 2)
                    $mbTotal = [math]::Round($contentLength / 1MB, 2)
                    
                    $elapsedSeconds = $startWatch.Elapsed.TotalSeconds
                    $speedStr = ""
                    if ($elapsedSeconds -gt 0) {
                        $speed = [math]::Round(($totalBytesRead / 1MB) / $elapsedSeconds, 2)
                        $speedStr = " @ $speed MB/s"
                    }
                    
                    # 30-char visual progress bar
                    $barWidth = 30
                    $doneWidth = [int]($percent * $barWidth / 100)
                    $todoWidth = $barWidth - $doneWidth
                    $bar = ("=" * $doneWidth) + (" " * $todoWidth)
                    
                    $statusLine = "`rProgress: [$bar] $percent% ($mbRead / $mbTotal MB)$speedStr"
                    Write-Host -NoNewline ($statusLine.PadRight(100))
                } else {
                    $mbRead = [math]::Round($totalBytesRead / 1MB, 2)
                    $elapsedSeconds = $startWatch.Elapsed.TotalSeconds
                    $speedStr = ""
                    if ($elapsedSeconds -gt 0) {
                        $speed = [math]::Round(($totalBytesRead / 1MB) / $elapsedSeconds, 2)
                        $speedStr = " @ $speed MB/s"
                    }
                    $statusLine = "`rProgress: $mbRead MB downloaded$speedStr"
                    Write-Host -NoNewline ($statusLine.PadRight(100))
                }
            }
            
            # Print newline when download is completed
            Write-Host ""
            $startWatch.Stop()
        } catch {
            Write-Host "`n[ERROR] Download failed: $_" -ForegroundColor Red
            throw $_
        } finally {
            if ($fileStream) { $fileStream.Dispose() }
            if ($downloadStream) { $downloadStream.Dispose() }
            if ($response) { $response.Dispose() }
            if ($httpClient) { $httpClient.Dispose() }
        }
    }

    # --- 1. DOWNLOAD FFmpeg ---
    $ffmpegZip = Join-Path $env:TEMP "ffmpeg.zip"
    $ffmpegExtractTemp = Join-Path $env:TEMP "ffmpeg_extract_temp"
    
    if (Test-Path $ffmpegZip) { Remove-Item $ffmpegZip -Force }
    if (Test-Path $ffmpegExtractTemp) { Remove-Item $ffmpegExtractTemp -Recurse -Force }
    
    try {
        $ffmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
        Start-FileDownload -url $ffmpegUrl -outPath $ffmpegZip -activity "FFmpeg Essentials Pack (~90MB)"
        
        Write-Host "[EXTRACT] Extracting FFmpeg archive..." -ForegroundColor Cyan
        Expand-Archive -Path $ffmpegZip -DestinationPath $ffmpegExtractTemp -Force
        
        # Locate and copy binaries recursively to bin/
        $ffmpegFile = Get-ChildItem -Path $ffmpegExtractTemp -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1
        $ffprobeFile = Get-ChildItem -Path $ffmpegExtractTemp -Filter "ffprobe.exe" -Recurse | Select-Object -First 1
        
        if ($ffmpegFile) {
            Move-Item -Path $ffmpegFile.FullName -Destination $localBin -Force
            Write-Host "[SUCCESS] Extracted ffmpeg.exe to local bin/" -ForegroundColor Green
        } else {
            throw "ffmpeg.exe not found in the extracted files."
        }
        
        if ($ffprobeFile) {
            Move-Item -Path $ffprobeFile.FullName -Destination $localBin -Force
            Write-Host "[SUCCESS] Extracted ffprobe.exe to local bin/" -ForegroundColor Green
        } else {
            throw "ffprobe.exe not found in the extracted files."
        }
        
    } catch {
        Write-Host "[ERROR] Failed to install FFmpeg: $_" -ForegroundColor Red
    } finally {
        if (Test-Path $ffmpegZip) { Remove-Item $ffmpegZip -Force }
        if (Test-Path $ffmpegExtractTemp) { Remove-Item $ffmpegExtractTemp -Recurse -Force }
    }

    # --- 2. DOWNLOAD ImageMagick ---
    $magick7z = Join-Path $env:TEMP "imagemagick.7z"
    $magickExtractTemp = Join-Path $localBin "magick_extract_temp"
    $sevenZipExe = Join-Path $localBin "7zr.exe"
    
    if (Test-Path $magick7z) { Remove-Item $magick7z -Force }
    if (Test-Path $magickExtractTemp) { Remove-Item $magickExtractTemp -Recurse -Force }
    
    try {
        # A. Download 7zr.exe console helper if not exists
        if (!(Test-Path $sevenZipExe)) {
            $sevenZipUrl = "https://www.7-zip.org/a/7zr.exe"
            Start-FileDownload -url $sevenZipUrl -outPath $sevenZipExe -activity "7-Zip console helper (7zr.exe)"
        }
        
        # B. Get latest ImageMagick download URL from GitHub releases API
        Write-Host "[API] Resolving latest ImageMagick release URL..." -ForegroundColor Cyan
        $apiUri = "https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest"
        $magickUrl = ""
        try {
            $release = Invoke-RestMethod -Uri $apiUri -UseBasicParsing -ErrorAction Stop
            $asset = $release.assets | Where-Object { $_.name -like "*portable*x64.7z" } | Select-Object -First 1
            if ($asset) {
                $magickUrl = $asset.browser_download_url
            }
        } catch {
            Write-Host "Warning: Could not contact GitHub API. Using fallback ImageMagick archive URL..." -ForegroundColor Yellow
        }
        
        if (!$magickUrl) {
            # Fallback direct archive URL
            $magickUrl = "https://imagemagick.org/archive/binaries/ImageMagick-7.1.1-33-portable-Q16-x64.7z"
        }
        
        Start-FileDownload -url $magickUrl -outPath $magick7z -activity "ImageMagick Portable Pack (~40MB)"
        
        Write-Host "[EXTRACT] Extracting ImageMagick archive..." -ForegroundColor Cyan
        # Run 7zr.exe to extract .7z archive
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $sevenZipExe
        $psi.Arguments = "x `"$magick7z`" -o`"$magickExtractTemp`" -y"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $p.Start() | Out-Null
        $p.WaitForExit()
        
        if ($p.ExitCode -eq 0) {
            $magickFile = Get-ChildItem -Path $magickExtractTemp -Filter "magick.exe" -Recurse | Select-Object -First 1
            if ($magickFile) {
                Move-Item -Path $magickFile.FullName -Destination $localBin -Force
                Write-Host "[SUCCESS] Extracted magick.exe to local bin/" -ForegroundColor Green
            } else {
                throw "magick.exe not found in the extracted files."
            }
        } else {
            Write-Host "[ERROR] 7zr extraction failed with exit code $($p.ExitCode)" -ForegroundColor Red
        }
    } catch {
        Write-Host "[ERROR] Failed to install ImageMagick: $_" -ForegroundColor Red
    } finally {
        # Clean up temporary downloads/extractions
        if (Test-Path $magick7z) { Remove-Item $magick7z -Force }
        if (Test-Path $magickExtractTemp) { Remove-Item $magickExtractTemp -Recurse -Force }
        if (Test-Path $sevenZipExe) { Remove-Item $sevenZipExe -Force }
    }
}

# --- END OF MODULE: DependencyInstaller.ps1 ---

# --- START OF MODULE: GpuDetector.ps1 ---
function Get-GpuEncoder {
    <#
    .SYNOPSIS
        Detects installed graphics hardware and maps the selected video codec to the corresponding
        hardware-accelerated FFmpeg encoder (or falls back to software/CPU encoding).
    .PARAMETER codecChoice
        The codec selection string ("1" = H.264, "2" = H.265/HEVC, "3" = AV1).
    .OUTPUTS
        [PSCustomObject] containing HardwareName, Encoder, EncoderArgs, and Extension.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$codecChoice
    )

    $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
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

    return [PSCustomObject]@{
        HardwareName = $hwName
        Encoder      = $encoder
        EncoderArgs  = $encArgs
        Extension    = $ext
    }
}

# --- END OF MODULE: GpuDetector.ps1 ---

# --- START OF MODULE: ConfigMenus.ps1 ---
function Show-ConfigMenus {
    <#
    .SYNOPSIS
        Drives the configuration interactive flow (state machine) using Show-Menu,
        gathering all encoding requirements from the user.
    .PARAMETER imageFiles
        An array of FileInfo objects for images.
    .PARAMETER videoFiles
        An array of FileInfo objects for videos.
    .PARAMETER magickExists
        A boolean indicating if ImageMagick is present.
    .OUTPUTS
        [PSCustomObject] containing the complete user options, or $null if exited.
    #>
    param (
        [System.IO.FileInfo[]]$imageFiles,
        [System.IO.FileInfo[]]$videoFiles,
        [bool]$magickExists
    )

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
            $options = [ordered]@{
                "1" = "Videos only"
                "2" = "Images only"
                "3" = "Both sequentially"
            }
            $title = "Both Images ($($imageFiles.Count)) and Videos ($($videoFiles.Count)) detected. What do you want to process?"
            $choice = Show-Menu -Title $title -Options $options -AllowBack $false -AllowQuit $true
            
            if ($choice -eq "q") { return $null }
            if ($choice -eq "1") {
                $mode = "VideosOnly"
                $processVideos = $true
                $processImages = $false
                $step = 1
            } elseif ($choice -eq "2") {
                if (!$magickExists) {
                    Write-Host "`nERROR: ImageMagick is not installed. Cannot process images." -ForegroundColor Red
                    continue
                }
                $mode = "ImagesOnly"
                $processImages = $true
                $processVideos = $false
                $step = 4
            } elseif ($choice -eq "3") {
                if (!$magickExists) {
                    Write-Host "`nERROR: ImageMagick is not installed. Cannot process images sequentially." -ForegroundColor Red
                    continue
                }
                $mode = "Both"
                $processVideos = $true
                $processImages = $true
                $step = 1
            }
            continue
        }

        # --- STEP 1: Video Codec Menu ---
        if ($step -eq 1) {
            $options = [ordered]@{
                "1" = "H.264 (Maximum Compatibility)"
                "2" = "H.265 / HEVC (Better File Size)"
                "3" = "AV1 (Best Size/Quality - Needs Modern GPU)"
            }
            $choice = Show-Menu -Title "SELECT VIDEO CODEC" -Options $options -AllowBack $hasMixedFiles -AllowQuit (!$hasMixedFiles)
            
            if ($choice -eq "q") { return $null }
            if ($choice -eq "b") {
                if ($hasMixedFiles) { $step = 0 }
                continue
            }
            $codecChoice = $choice
            $step = 2
            continue
        }

        # --- STEP 2: Video Resolution Menu ---
        if ($step -eq 2) {
            $options = [ordered]@{
                "1" = "480p"
                "2" = "720p"
                "3" = "1080p"
                "4" = "1440p (2k)"
                "5" = "2160p (4k)"
                "6" = "CUSTOM"
                "7" = "ORIGINAL"
            }
            $choice = Show-Menu -Title "SELECT TARGET RESOLUTION" -Options $options -AllowBack $true -AllowQuit $true
            
            if ($choice -eq "q") { return $null }
            if ($choice -eq "b") { $step = 1; continue }
            
            $resChoice = $choice
            if ($resChoice -eq "6") {
                $tempHeight = $null
                while ($true) {
                    $customHeightInput = Read-Host "Enter custom height (must be an even integer, e.g., 864, or B to go back)"
                    if ($customHeightInput.Trim() -match '^[Bb]$') {
                        $tempHeight = "BACK"
                        break
                    }
                    if ($customHeightInput.Trim() -match '^\d+$' -and [int]$customHeightInput -gt 0) {
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
                if ($tempHeight -eq "BACK") { continue }
                $targetHeight = $tempHeight
            } elseif ($resChoice -eq "7") {
                $targetHeight = "ORIGINAL"
            } else {
                $heights = @{ "1"="480"; "2"="720"; "3"="1080"; "4"="1440"; "5"="2160" }
                $targetHeight = $heights[$resChoice]
            }
            $step = 3
            continue
        }

        # --- STEP 3: Video Bitrate Menu ---
        if ($step -eq 3) {
            $options = [ordered]@{
                "1" = "1k"
                "2" = "2k"
                "3" = "5k"
                "4" = "10k"
                "5" = "15k"
                "6" = "20k"
                "7" = "CUSTOM"
                "8" = "ORIGINAL (Auto/CRF)"
            }
            $choice = Show-Menu -Title "SELECT BITRATE (kbps)" -Options $options -AllowBack $true -AllowQuit $true
            
            if ($choice -eq "q") { return $null }
            if ($choice -eq "b") { $step = 2; continue }
            
            $bitChoice = $choice
            if ($bitChoice -eq "7") {
                $tempBitrate = $null
                while ($true) {
                    $customBitrateInput = Read-Host "Enter custom bitrate in kbps (e.g., 8000, or B to go back)"
                    if ($customBitrateInput.Trim() -match '^[Bb]$') {
                        $tempBitrate = "BACK"
                        break
                    }
                    if ($customBitrateInput.Trim() -match '^\d+$' -and [int]$customBitrateInput -gt 0) {
                        $tempBitrate = [int]$customBitrateInput
                        break
                    }
                    Write-Host "Invalid input. Please enter a positive integer." -ForegroundColor Red
                }
                if ($tempBitrate -eq "BACK") { continue }
                $targetBitrate = $tempBitrate
            } elseif ($bitChoice -eq "8") {
                $targetBitrate = "ORIGINAL"
            } else {
                $bitrates = @{ "1"="1000"; "2"="2000"; "3"="5000"; "4"="10000"; "5"="15000"; "6"="20000" }
                $targetBitrate = $bitrates[$bitChoice]
            }
            
            if ($mode -eq "Both") { $step = 4 } else { $step = 7 }
            continue
        }

        # --- STEP 4: Image Format Menu ---
        if ($step -eq 4) {
            $options = [ordered]@{
                "1" = "JPG (Joint Photographic Experts Group)"
                "2" = "PDF (Portable Document Format - Multi-page if multiple selected)"
                "3" = "PNG (Portable Network Graphics)"
                "4" = "WEB (WebP format for high quality web compression)"
            }
            $allowBack = ($mode -eq "Both" -or $hasMixedFiles)
            $allowQuit = !$allowBack
            $choice = Show-Menu -Title "SELECT TARGET IMAGE FORMAT" -Options $options -AllowBack $allowBack -AllowQuit $allowQuit
            
            if ($choice -eq "q") { return $null }
            if ($choice -eq "b") {
                if ($mode -eq "Both") { $step = 3 } elseif ($hasMixedFiles) { $step = 0 }
                continue
            }
            $imageFormatChoice = $choice
            if ($imageFormatChoice -eq "1" -or $imageFormatChoice -eq "4") {
                $step = 5
            } else {
                $step = 7
            }
            continue
        }

        # --- STEP 5: Image Sub-Menu A (JPG Quality or WEB Resolution) ---
        if ($step -eq 5) {
            if ($imageFormatChoice -eq "1") {
                $options = [ordered]@{
                    "1" = "20%"
                    "2" = "40%"
                    "3" = "60%"
                    "4" = "80%"
                    "5" = "CUSTOM"
                    "6" = "ORIGINAL"
                }
                $choice = Show-Menu -Title "SELECT JPG QUALITY" -Options $options -AllowBack $true -AllowQuit $true
                
                if ($choice -eq "q") { return $null }
                if ($choice -eq "b") { $step = 4; continue }
                
                if ($choice -eq "5") {
                    $tempQuality = $null
                    while ($true) {
                        $customQualityInput = Read-Host "Enter custom quality (1-100, or B to go back)"
                        if ($customQualityInput.Trim() -match '^[Bb]$') {
                            $tempQuality = "BACK"
                            break
                        }
                        if ($customQualityInput.Trim() -match '^\d+$' -and [int]$customQualityInput -ge 1 -and [int]$customQualityInput -le 100) {
                            $tempQuality = [int]$customQualityInput
                            break
                        }
                        Write-Host "Invalid input. Please enter an integer between 1 and 100." -ForegroundColor Red
                    }
                    if ($tempQuality -eq "BACK") { continue }
                    $jpgQuality = $tempQuality
                } elseif ($choice -eq "6") {
                    $jpgQuality = "ORIGINAL"
                } else {
                    $qualities = @{ "1"=20; "2"=40; "3"=60; "4"=80 }
                    $jpgQuality = $qualities[$choice]
                }
                $step = 7
                continue
            }
            
            if ($imageFormatChoice -eq "4") {
                $options = [ordered]@{
                    "1" = "30%"
                    "2" = "50%"
                    "3" = "80%"
                    "4" = "CUSTOM"
                    "5" = "ORIGINAL"
                }
                $choice = Show-Menu -Title "SELECT WEB Target Resolution / Scale" -Options $options -AllowBack $true -AllowQuit $true
                
                if ($choice -eq "q") { return $null }
                if ($choice -eq "b") { $step = 4; continue }
                
                $tempResChoice = $choice
                if ($tempResChoice -eq "4") {
                    $tempHeight = $null
                    while ($true) {
                        $customHeightInput = Read-Host "Enter custom height in pixels (locking aspect ratio, e.g., 600, or B to go back)"
                        if ($customHeightInput.Trim() -match '^[Bb]$') {
                            $tempHeight = "BACK"
                            break
                        }
                        if ($customHeightInput.Trim() -match '^\d+$' -and [int]$customHeightInput -gt 0) {
                            $tempHeight = [int]$customHeightInput
                            break
                        }
                        Write-Host "Invalid input. Please enter a positive integer." -ForegroundColor Red
                    }
                    if ($tempHeight -eq "BACK") { continue }
                    $webHeight = $tempHeight
                }
                $webResChoice = $tempResChoice
                $step = 6
                continue
            }
        }

        # --- STEP 6: Image Sub-Menu B (WEB Quality) ---
        if ($step -eq 6) {
            $options = [ordered]@{
                "1" = "50%"
                "2" = "60%"
                "3" = "80%"
                "4" = "90%"
                "5" = "CUSTOM"
            }
            $choice = Show-Menu -Title "SELECT WEB QUALITY" -Options $options -AllowBack $true -AllowQuit $true
            
            if ($choice -eq "q") { return $null }
            if ($choice -eq "b") { $step = 5; continue }
            
            if ($choice -eq "5") {
                $tempQuality = $null
                while ($true) {
                    $customQualityInput = Read-Host "Enter custom quality (1-100, or B to go back)"
                    if ($customQualityInput.Trim() -match '^[Bb]$') {
                        $tempQuality = "BACK"
                        break
                    }
                    if ($customQualityInput.Trim() -match '^\d+$' -and [int]$customQualityInput -ge 1 -and [int]$customQualityInput -le 100) {
                        $tempQuality = [int]$customQualityInput
                        break
                    }
                    Write-Host "Invalid input. Please enter an integer between 1 and 100." -ForegroundColor Red
                }
                if ($tempQuality -eq "BACK") { continue }
                $webQuality = $tempQuality
            } else {
                $qualities = @{ "1"=50; "2"=60; "3"=80; "4"=90 }
                $webQuality = $qualities[$choice]
            }
            $step = 7
            continue
        }
    }

    return [PSCustomObject]@{
        Mode               = $mode
        ProcessVideos      = $processVideos
        ProcessImages      = $processImages
        CodecChoice        = $codecChoice
        TargetHeight       = $targetHeight
        TargetBitrate      = $targetBitrate
        ImageFormatChoice  = $imageFormatChoice
        JpgQuality         = $jpgQuality
        WebQuality         = $webQuality
        WebResChoice       = $webResChoice
        WebHeight          = $webHeight
    }
}

# --- END OF MODULE: ConfigMenus.ps1 ---

# --- START OF MODULE: ConflictResolver.ps1 ---
# Script-scoped variable to track conflict choice across multiple files
$script:conflictAction = $null

function Get-UniqueFilePath {
    <#
    .SYNOPSIS
        Appends a numeric suffix (e.g. _1, _2) to a filename to resolve a path collision.
    .PARAMETER filePath
        The path of the file to auto-rename.
    .OUTPUTS
        [string] representing the unique file path.
    #>
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

function Get-ConflictResolution {
    <#
    .SYNOPSIS
        Evaluates a potential file write path collision. Prompting user or skipping/overwriting
        depending on previous selections.
    .PARAMETER filePath
        The target file path.
    .OUTPUTS
        [string] representing the resolved path to write to, or $null if the operation is skipped.
    #>
    param (
        [string]$filePath
    )
    
    if (!(Test-Path $filePath)) {
        return $filePath
    }
    
    if ($script:conflictAction -eq "OverwriteAll") {
        return $filePath
    }
    
    if ($script:conflictAction -eq "SkipAll") {
        Write-Host "[SKIP] Already exists: $filePath" -ForegroundColor Yellow
        return $null
    }
    
    if ($script:conflictAction -eq "AutoRenameAll") {
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
            $script:conflictAction = "OverwriteAll"
            return $filePath
        } elseif ($choice -eq "3") {
            Write-Host "[SKIP] Skipped: $fileName" -ForegroundColor Yellow
            return $null
        } elseif ($choice -eq "4") {
            $script:conflictAction = "SkipAll"
            Write-Host "[SKIP] Skipped: $fileName" -ForegroundColor Yellow
            return $null
        } elseif ($choice -eq "5") {
            $newPath = Get-UniqueFilePath -filePath $filePath
            $newFileName = Split-Path $newPath -Leaf
            Write-Host "[RENAME] Renamed to: $newFileName" -ForegroundColor Cyan
            return $newPath
        } elseif ($choice -eq "6") {
            $script:conflictAction = "AutoRenameAll"
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

# --- END OF MODULE: ConflictResolver.ps1 ---

# --- START OF MODULE: MenuHelper.ps1 ---
function Show-Menu {
    <#
    .SYNOPSIS
        Displays a structured menu block with numbered choices, processes input,
        and enforces valid keys including "Back" and "Quit" options.
    .PARAMETER Title
        The title/header of the menu.
    .PARAMETER Options
        An ordered dictionary ([ordered]@{ "Key" = "Label" }) of options.
    .PARAMETER AllowBack
        If true, exposes a "B. Back" option.
    .PARAMETER AllowQuit
        If true, exposes a "Q. Quit / Exit" option.
    .OUTPUTS
        [string] representing the validated, lowercased user choice (e.g. "1", "2", "b", "q").
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Options,
        [bool]$AllowBack = $true,
        [bool]$AllowQuit = $true
    )

    Write-Host "`n--- $Title ---" -ForegroundColor Yellow
    foreach ($key in $Options.Keys) {
        Write-Host "$key. $($Options[$key])"
    }
    if ($AllowBack) { Write-Host "B. Back" }
    if ($AllowQuit) { Write-Host "Q. Quit / Exit" }

    $validKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($k in $Options.Keys) { [void]$validKeys.Add($k) }
    if ($AllowBack) { [void]$validKeys.Add("b") }
    if ($AllowQuit) { [void]$validKeys.Add("q") }

    while ($true) {
        $promptKeys = @() + $Options.Keys
        if ($AllowBack) { $promptKeys += "B" }
        if ($AllowQuit) { $promptKeys += "Q" }
        $prompt = "Pick (" + ($promptKeys -join "-") + ")"
        
        $rawInput = Read-Host $prompt
        if ($null -eq $rawInput) {
            # Stdin EOF reached. Fallback to prevent infinite loop.
            if ($AllowQuit) { return "q" }
            return "b"
        }
        
        $choice = $rawInput.Trim()
        if ($validKeys.Contains($choice)) {
            return $choice.ToLower()
        }
        Write-Host "Invalid choice. Please select a valid option." -ForegroundColor Red
    }
}

# --- END OF MODULE: MenuHelper.ps1 ---

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

