# build.ps1
# Compiles the src/ directory into a single standalone AlitConverter.ps1 file.

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$srcPath = Join-Path $PSScriptRoot "src"
$templateFile = Join-Path $srcPath "AlitConverter.template.ps1"
$outputFile = Join-Path $PSScriptRoot "AlitConverter.ps1"

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
