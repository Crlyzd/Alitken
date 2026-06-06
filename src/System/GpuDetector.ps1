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
