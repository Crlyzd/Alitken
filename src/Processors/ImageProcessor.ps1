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
    $pdfQuality = $config.PdfQuality
    $pdfResChoice = $config.PdfResChoice
    $pdfHeight = $config.PdfHeight

    Write-Host "`n[WORKING] Processing images..." -ForegroundColor Green
    
    if ($imageFormatChoice -eq "2") {
        # PDF format
        $resizeFlag = ""
        $resTag = ""
        if ($pdfResChoice -eq "1") {
            $resizeFlag = "-resize 30%"
            $resTag = "_30pct"
        } elseif ($pdfResChoice -eq "2") {
            $resizeFlag = "-resize 50%"
            $resTag = "_50pct"
        } elseif ($pdfResChoice -eq "3") {
            $resizeFlag = "-resize 80%"
            $resTag = "_80pct"
        } elseif ($pdfResChoice -eq "4") {
            $resizeFlag = "-resize x$pdfHeight"
            $resTag = "_h$pdfHeight"
        }

        $qualityFlag = ""
        $qualityTag = ""
        if ($pdfQuality -and $pdfQuality -ne "ORIGINAL") {
            $qualityFlag = "-quality $pdfQuality"
            $qualityTag = "_q$pdfQuality"
        }

        $pdfTag = "${resTag}${qualityTag}"

        if ($imageFiles.Count -eq 1) {
            $file = $imageFiles[0]
            $outFile = "$($file.DirectoryName)\$($file.BaseName)$pdfTag.pdf"
        } else {
            $firstFile = $imageFiles[0]
            $outFile = "$($firstFile.DirectoryName)\Merged_Images$pdfTag.pdf"
        }
        
        $resolvedOutFile = Get-ConflictResolution -filePath $outFile
        if (!$resolvedOutFile) {
            # Skipped
        } else {
            # Construct args for magick
            $magickArgs = @("-monitor")
            foreach ($img in $imageFiles) {
                $magickArgs += "`"$($img.FullName)`""
            }
            if ($resizeFlag) {
                $magickArgs += $resizeFlag
            }
            if ($qualityFlag) {
                $magickArgs += $qualityFlag
            }
            $magickArgs += "`"$resolvedOutFile`""
            
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $global:MagickPath
            $psi.Arguments = $magickArgs -join " "
            $psi.UseShellExecute = $false
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $psi
            
            Show-TextProgressBar -PercentComplete 0 -Status "Merging images to PDF..."
            $p.Start() | Out-Null
            
            $errLines = @()
            while (!$p.StandardError.EndOfStream) {
                $line = $p.StandardError.ReadLine()
                if ($line) {
                    if ($line -match "^([^\[]+)\[.+?(\d+)%\s+complete") {
                        $rawPhase = $matches[1]
                        $pct = [int]$matches[2]
                        if ($pct -gt 100) { $pct = 100 }
                        
                        $phase = "Merging"
                        switch ($rawPhase) {
                            "Resize/Image" { $phase = "Resizing images" }
                            "Save/Images"  { $phase = "Writing PDF" }
                            "Save/Image"   { $phase = "Writing PDF" }
                            "Sample/Image" { $phase = "Sampling images" }
                            default        { $phase = $rawPhase }
                        }
                        
                        Show-TextProgressBar -PercentComplete $pct -Status "$phase..."
                    } else {
                        $errLines += $line
                    }
                }
            }
            $p.WaitForExit()
            
            if ($p.ExitCode -eq 0 -and (Test-Path $resolvedOutFile)) {
                Write-Host "`r[SUCCESS] Saved PDF: $(Split-Path $resolvedOutFile -Leaf)".PadRight(110) -ForegroundColor Cyan
            } else {
                Write-Host "`r[ERROR] ImageMagick PDF merge failed. Code: $($p.ExitCode)".PadRight(110) -ForegroundColor Red
                if ($errLines.Count -gt 0) {
                    $errLines | Write-Host -ForegroundColor DarkRed
                }
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
                Write-Host "`r[SKIP] Input and output paths are identical: $($file.Name)".PadRight(110) -ForegroundColor Yellow
                continue
            }
            
            $resolvedOutFile = Get-ConflictResolution -filePath $outFile
            if (!$resolvedOutFile) {
                continue
            }
            
            Show-TextProgressBar -PercentComplete $pct -Status "Converting $($file.Name) to $formatExt..."
            
            $errLogPath = "$env:TEMP\magick_err.log"
            if (Test-Path $errLogPath) { Remove-Item $errLogPath }
            
            $magickCmd = "`"$global:MagickPath`" `"$($file.FullName)`" $magickQualityFlags `"$resolvedOutFile`""
            
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c @cd . & $magickCmd 2> `"$errLogPath`""
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $psi
            $p.Start() | Out-Null
            $p.WaitForExit()
            
            if ($p.ExitCode -eq 0 -and (Test-Path $resolvedOutFile)) {
                Write-Host "`r[SUCCESS] Saved: $(Split-Path $resolvedOutFile -Leaf)".PadRight(110) -ForegroundColor Cyan
            } else {
                Write-Host "`r[ERROR] ImageMagick failed for $($file.Name). Code: $($p.ExitCode)".PadRight(110) -ForegroundColor Red
                if (Test-Path $errLogPath) { Get-Content $errLogPath | Write-Host -ForegroundColor DarkRed }
                if (Test-Path $resolvedOutFile) { Remove-Item $resolvedOutFile }
            }
        }
    }
}
