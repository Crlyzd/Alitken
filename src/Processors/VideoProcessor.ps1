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
