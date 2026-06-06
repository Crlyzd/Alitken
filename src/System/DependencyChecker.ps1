function Get-SystemDependencies {
    <#
    .SYNOPSIS
        Checks if required command-line tools are available in the system PATH.
    .OUTPUTS
        [PSCustomObject] containing booleans: FfmpegExists, FfprobeExists, MagickExists.
    #>
    $ffmpegExists = Get-Command ffmpeg -ErrorAction SilentlyContinue
    $ffprobeExists = Get-Command ffprobe -ErrorAction SilentlyContinue
    $magickExists = Get-Command magick -ErrorAction SilentlyContinue

    return [PSCustomObject]@{
        FfmpegExists  = [bool]$ffmpegExists
        FfprobeExists = [bool]$ffprobeExists
        MagickExists  = [bool]$magickExists
    }
}
