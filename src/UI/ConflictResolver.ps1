# Script-scoped variable to track conflict choice across multiple files
$script:conflictAction = $null

function Get-UniqueFilePath {
    <#
    .SYNOPSIS
        Appends a numeric suffix (e.g. _1, _2) to a filename to resolve a path collision.
    .PARAMETER filePath
        The path of the file to auto-rename.
    .OUTPUTS
        [string] representing the unique file path.
    #>
    param (
        [string]$filePath
    )
    $dir = Split-Path $filePath -Parent
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
    $ext = [System.IO.Path]::GetExtension($filePath)
    
    $counter = 1
    while ($true) {
        $candidatePath = Join-Path $dir "${baseName}_$counter$ext"
        if (!(Test-Path $candidatePath)) {
            return $candidatePath
        }
        $counter++
    }
}

function Get-ConflictResolution {
    <#
    .SYNOPSIS
        Evaluates a potential file write path collision. Prompting user or skipping/overwriting
        depending on previous selections.
    .PARAMETER filePath
        The target file path.
    .OUTPUTS
        [string] representing the resolved path to write to, or $null if the operation is skipped.
    #>
    param (
        [string]$filePath
    )
    
    if (!(Test-Path $filePath)) {
        return $filePath
    }
    
    if ($script:conflictAction -eq "OverwriteAll") {
        return $filePath
    }
    
    if ($script:conflictAction -eq "SkipAll") {
        Write-Host "[SKIP] Already exists: $filePath" -ForegroundColor Yellow
        return $null
    }
    
    if ($script:conflictAction -eq "AutoRenameAll") {
        return Get-UniqueFilePath -filePath $filePath
    }
    
    $fileName = Split-Path $filePath -Leaf
    while ($true) {
        Write-Host "`n[CONFLICT] File already exists: $fileName" -ForegroundColor Yellow
        Write-Host "What would you like to do?"
        Write-Host "1. Overwrite this file"
        Write-Host "2. Overwrite all subsequent conflicts"
        Write-Host "3. Skip this file"
        Write-Host "4. Skip all subsequent conflicts"
        Write-Host "5. Auto-rename this file"
        Write-Host "6. Auto-rename all subsequent conflicts"
        Write-Host "Q. Quit / Exit"
        
        $choice = Read-Host "Pick (1-6, Q)"
        if ($choice -eq "1") {
            return $filePath
        } elseif ($choice -eq "2") {
            $script:conflictAction = "OverwriteAll"
            return $filePath
        } elseif ($choice -eq "3") {
            Write-Host "[SKIP] Skipped: $fileName" -ForegroundColor Yellow
            return $null
        } elseif ($choice -eq "4") {
            $script:conflictAction = "SkipAll"
            Write-Host "[SKIP] Skipped: $fileName" -ForegroundColor Yellow
            return $null
        } elseif ($choice -eq "5") {
            $newPath = Get-UniqueFilePath -filePath $filePath
            $newFileName = Split-Path $newPath -Leaf
            Write-Host "[RENAME] Renamed to: $newFileName" -ForegroundColor Cyan
            return $newPath
        } elseif ($choice -eq "6") {
            $script:conflictAction = "AutoRenameAll"
            $newPath = Get-UniqueFilePath -filePath $filePath
            $newFileName = Split-Path $newPath -Leaf
            Write-Host "[RENAME] Renamed to: $newFileName" -ForegroundColor Cyan
            return $newPath
        } elseif ($choice -match '^[Qq]$') {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            exit
        }
        Write-Host "Invalid choice. Please select 1-6, or Q." -ForegroundColor Red
    }
}
