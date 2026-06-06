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
            $psi.Arguments = "/c $cmdLine 2> `"$errLogPath`""
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
            $psi.Arguments = "/c $magickCmd 2> `"$errLogPath`""
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
