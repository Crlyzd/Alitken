# Alit Video Converter by Curlyzed (Universal + AV1 Edition) - Updated
$Header = @"
============================================
      Alit Video Converter by Curlyzed
============================================
"@

Clear-Host
Write-Host $Header -ForegroundColor Cyan

# 0. Dependency Check
Write-Host "[SYSTEM CHECK] Checking dependencies..." -ForegroundColor Gray
$ffmpegExists = Get-Command ffmpeg -ErrorAction SilentlyContinue
$ffprobeExists = Get-Command ffprobe -ErrorAction SilentlyContinue
if (!$ffmpegExists -or !$ffprobeExists) {
    Write-Host "ERROR: ffmpeg and/or ffprobe could not be found in your system PATH." -ForegroundColor Red
    Write-Host "Please install FFmpeg and make sure it is added to your environment variables." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# 1. Codec Menu
$codecChoice = $null
while ($true) {
    Write-Host "SELECT VIDEO CODEC" -ForegroundColor Yellow
    Write-Host "1. H.264 (Maximum Compatibility)"
    Write-Host "2. H.265 / HEVC (Better File Size)"
    Write-Host "3. AV1 (Best Size/Quality - Needs Modern GPU)"
    $choice = Read-Host "Pick (1-3)"
    if ($choice -match '^[1-3]$') {
        $codecChoice = $choice
        break
    }
    Write-Host "Invalid choice. Please select 1, 2, or 3.`n" -ForegroundColor Red
}

# 2. Resolution Menu
$resChoice = $null
while ($true) {
    Write-Host "`nSELECT TARGET RESOLUTION" -ForegroundColor Yellow
    Write-Host "1. 480p | 2. 720p | 3. 1080p | 4. 1440p (2k) | 5. 2160p (4k) | 6. CUSTOM | 7. ORIGINAL"
    $choice = Read-Host "Pick (1-7)"
    if ($choice -match '^[1-7]$') {
        $resChoice = $choice
        break
    }
    Write-Host "Invalid choice. Please select 1-7." -ForegroundColor Red
}

if ($resChoice -eq "6") {
    while ($true) {
        $customHeightInput = Read-Host "Enter custom height (must be an even integer, e.g., 864)"
        if ($customHeightInput -match '^\d+$' -and [int]$customHeightInput -gt 0) {
            $heightVal = [int]$customHeightInput
            if ($heightVal % 2 -ne 0) {
                $heightVal = $heightVal + 1
                Write-Host "Adjusted custom height to even number: $heightVal" -ForegroundColor Cyan
            }
            $targetHeight = $heightVal
            break
        }
        Write-Host "Invalid input. Please enter a positive integer." -ForegroundColor Red
    }
} elseif ($resChoice -eq "7") {
    $targetHeight = "ORIGINAL"
} else {
    $heights = @{ "1"="480"; "2"="720"; "3"="1080"; "4"="1440"; "5"="2160" }
    $targetHeight = $heights[$resChoice]
}

# 3. Bitrate Menu
$bitChoice = $null
while ($true) {
    Write-Host "`nSELECT BITRATE (kbps)" -ForegroundColor Yellow
    Write-Host "1. 1k | 2. 2k | 3. 5k | 4. 10k | 5. 15k | 6. 20k | 7. CUSTOM | 8. ORIGINAL (Auto/CRF)"
    $choice = Read-Host "Pick (1-8)"
    if ($choice -match '^[1-8]$') {
        $bitChoice = $choice
        break
    }
    Write-Host "Invalid choice. Please select 1-8." -ForegroundColor Red
}

if ($bitChoice -eq "7") {
    while ($true) {
        $customBitrateInput = Read-Host "Enter custom bitrate in kbps (e.g., 8000)"
        if ($customBitrateInput -match '^\d+$' -and [int]$customBitrateInput -gt 0) {
            $targetBitrate = [int]$customBitrateInput
            $maxBitrate = $targetBitrate + ($targetBitrate / 4)
            $bufSize = $targetBitrate * 2
            break
        }
        Write-Host "Invalid input. Please enter a positive integer." -ForegroundColor Red
    }
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

if (!$targetHeight -or !$targetBitrate -or !$codecChoice) { exit }

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

foreach ($arg in $args) {
    $items = if (Test-Path $arg -PathType Container) { Get-ChildItem -Path $arg -Include *.mp4,*.mkv,*.mov,*.avi,*.m4v -File } else { Get-Item $arg }

    foreach ($file in $items) {
        # Formatting the output filename based on choices
        $resTag = if ($targetHeight -eq "ORIGINAL") { "origRes" } else { "$($targetHeight)p" }
        $bitTag = if ($targetBitrate -eq "ORIGINAL") { "origBit" } else { "$($targetBitrate)k" }
        $outFile = "$($file.DirectoryName)\$($file.BaseName)_$($resTag)_$($bitTag).$ext"
        
        if (Test-Path $outFile) { Write-Host "[SKIP] Already exists: $($file.Name)"; continue }

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
        $ffmpegCmd = "ffmpeg -hide_banner -i `"$($file.FullName)`" $vfFlag -c:v $encoder $encArgs $bitrateFlags -map 0:v:0 -map 0:a? -c:a copy -fps_mode cfr -y -progress pipe:1 `"$outFile`" 2> `"$errLogPath`""
        
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

        if ($p.ExitCode -eq 0 -and (Test-Path $outFile)) {
            Write-Host "[SUCCESS] Saved: $($file.BaseName)_$($resTag)_$($bitTag).$ext" -ForegroundColor Cyan
        } else {
            Write-Host "[ERROR] FFmpeg failed. Code: $($p.ExitCode)" -ForegroundColor Red
            Write-Host "--- WHAT FFMPEG ACTUALLY SAID ---" -ForegroundColor Yellow
            if (Test-Path $errLogPath) { Get-Content $errLogPath | Write-Host -ForegroundColor DarkRed }
            Write-Host "---------------------------------" -ForegroundColor Yellow
            if (Test-Path $outFile) { Remove-Item $outFile }
        }
    }
}

Write-Host "`nAll tasks complete! Press any key..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")