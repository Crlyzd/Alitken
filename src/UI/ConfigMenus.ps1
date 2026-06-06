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
