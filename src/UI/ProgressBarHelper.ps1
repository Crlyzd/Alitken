function Show-TextProgressBar {
    param (
        [Parameter(Mandatory = $true)]
        [double]$PercentComplete,
        [Parameter(Mandatory = $false)]
        [string]$Status = ""
    )

    $width = 30
    $percent = [Math]::Max(0, [Math]::Min(100, $PercentComplete))
    $completedWidth = [Math]::Round(($percent / 100) * $width)
    $remainingWidth = $width - $completedWidth

    $bar = ("#" * $completedWidth) + ("-" * $remainingWidth)
    
    $statusMsg = if ($Status) { " | $Status" } else { "" }
    $text = "`r[$bar] $([Math]::Round($percent))%$statusMsg"

    # Pad with spaces to clear any previous longer text line
    $paddedText = $text.PadRight(110)
    
    # Safely truncate to window width to prevent line wrapping if possible
    try {
        if ([Console]::WindowWidth -gt 20) {
            $lineWidth = [Console]::WindowWidth - 1
            if ($paddedText.Length -gt $lineWidth) {
                $paddedText = $paddedText.Substring(0, $lineWidth)
            }
        }
    } catch {}

    Write-Host -NoNewline $paddedText
}
