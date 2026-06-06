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
