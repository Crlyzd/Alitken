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
        
        $choice = (Read-Host $prompt).Trim()
        if ($validKeys.Contains($choice)) {
            return $choice.ToLower()
        }
        Write-Host "Invalid choice. Please select a valid option." -ForegroundColor Red
    }
}
