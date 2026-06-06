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
