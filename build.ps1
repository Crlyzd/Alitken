# build.ps1
# Compiles the src/ directory into a single standalone AlitConverter.ps1 file.

$ScriptDir = $PSScriptRoot
if (!$ScriptDir) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$srcPath = Join-Path $ScriptDir "src"
$templateFile = Join-Path $srcPath "AlitConverter.template.ps1"
$outputFile = Join-Path $ScriptDir "AlitConverter.ps1"

Write-Host "Building standalone script..." -ForegroundColor Cyan

# 1. Read the template
if (!(Test-Path $templateFile)) {
    Write-Host "ERROR: Template file not found at $templateFile" -ForegroundColor Red
    exit
}
$templateContent = Get-Content -Path $templateFile -Raw

# 2. Gather all source modules (excluding the template)
$moduleFiles = Get-ChildItem -Path $srcPath -Filter *.ps1 -Recurse | Where-Object { $_.Name -ne "AlitConverter.template.ps1" }

$modulesContent = ""
foreach ($file in $moduleFiles) {
    Write-Host "-> Bundling $($file.FullName.Replace($srcPath, ''))" -ForegroundColor Gray
    $modulesContent += "`n# --- START OF MODULE: $($file.Name) ---`n"
    $modulesContent += Get-Content -Path $file.FullName -Raw
    $modulesContent += "`n# --- END OF MODULE: $($file.Name) ---`n"
}

# 3. Replace the placeholder in the template with the bundled modules content
if ($templateContent -match '#\s*\[\[BUNDLED_MODULES\]\]') {
    $compiledContent = $templateContent.Replace('# [[BUNDLED_MODULES]]', $modulesContent)
} else {
    Write-Host "Warning: Placeholder # [[BUNDLED_MODULES]] not found. Prepending modules instead." -ForegroundColor Yellow
    $compiledContent = $modulesContent + "`n" + $templateContent
}

# 4. Write output to root AlitConverter.ps1
Set-Content -Path $outputFile -Value $compiledContent -Encoding utf8
Write-Host "Build complete! Standalone script written to: $outputFile" -ForegroundColor Green

# 5. Compile AlitConverter.ps1 to AlitConverter.exe
$exeFile = Join-Path $ScriptDir "AlitConverter.exe"
if (Get-Command ps2exe -ErrorAction SilentlyContinue) {
    Write-Host "`nCompiling standalone script to EXE..." -ForegroundColor Cyan
    try {
        # Using ps2exe alias (Invoke-ps2exe cmdlet)
        ps2exe -inputFile $outputFile -outputFile $exeFile -title "Alit Converter" -description "Alit Converter by Curlyzed" -version "0.2.0" -x64
        Write-Host "Compilation complete! Standalone executable written to: $exeFile" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Compilation failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host "`nWarning: ps2exe module is not installed. Skipping EXE compilation." -ForegroundColor Yellow
}
