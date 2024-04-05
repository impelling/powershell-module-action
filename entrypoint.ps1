#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'


$ModulePath = $env:INPUT_MODULEPATH
$PSGalleryKey = $env:INPUT_PSGALLERYKEY
$OutputPath = $env:INPUT_RELATIVEOUTPUTPATH ? $env:INPUT_RELATIVEOUTPUTPATH : '../Output'
$Version = $env:INPUT_VERSION ? $env:INPUT_VERSION : '0.0.1-localonly'
$Publish = $env:INPUT_PUBLISH ? $env:INPUT_PUBLISH : $false

Write-Host "Working with inputs:"
Write-Host "    - ModulePath: $ModulePath"
Write-Host "    - PSGalleryKey: $($PSGalleryKey ? 'Provided' : 'Not provided')"
Write-Host "    - OutputPath: $OutputPath"
Write-Host "    - Version: $Version"
Write-Host "    - Publish: $Publish"

$ModuleDirectory = $null
if ([string]::IsNullOrWhiteSpace($ModulePath)) {
    Write-Output "No module path provided, searching for module in repository"
    $SearchPath = Get-Location
    # Get the first module in the repo, excluding all psd1 files in the root
}
else {
    $SearchPath = $ModulePath
}

$ModuleDirectory = Get-ChildItem -Path $SearchPath -Recurse -Include *.psm1 | Select-Object -First 1 -ExpandProperty Directory

if (-not $ModuleDirectory) {
    throw "No module found in $SearchPath"
}

$ModuleName = $ModuleDirectory | Split-Path -Leaf
Write-Host "Processing module: $ModuleName"

if ([string]::IsNullOrWhiteSpace($PSGalleryKey)) {
    throw "No API key provided"
}

Write-Host "- Building $ModuleName in $OutputPath"

$ResolvedOutputPath = Join-Path -Path $ModuleDirectory.FullName -ChildPath $OutputPath
if (-not (Test-Path $ResolvedOutputPath)) {
    New-Item -Path $ResolvedOutputPath -ItemType Directory | Out-Null
}
else {
    Remove-Item -Path $ResolvedOutputPath/* -Recurse -Force -ErrorAction SilentlyContinue
}

Install-Module ModuleBuilder -Force
Build-Module -Path $ModuleDirectory.FullName -OutputDirectory $OutputPath -UnversionedOutputDirectory

if (-not $Publish) {
    Write-Host "Publishing disabled, skipping publish"
    exit 0
}

if ($Version -like '*-localonly') {
    Write-Host "Skipping publish, version is $Version (matches '*-localonly')"
    exit 0
}

$ManifestSplat = @{
Path = "$OutputPath\$ModuleName\$ModuleName.psd1"
}

if ($Version -like "*-*") {
    Write-Host "Publishing prerelease version"
    $ManifestSplat += @{
        ModuleVersion = ($Version -split '-')[0]
        Prerelease = ($Version -split '-')[1]
    }
}
else {
    Write-Host "Publishing stable version"
    $ManifestSplat += @{
        ModuleVersion = $Version
    }
}

try {
    Update-ModuleManifest @ManifestSplat
}
catch {
    Write-Error "Failed to update module manifest"
    throw $_.Exception.Message
}

Write-Host "Publishing $ModuleName version $Version to PowerShell Gallery"

try {
    Publish-Module -Path "$OutputPath\$ModuleName" -NuGetApiKey $PSGalleryKey -Force
    Write-Host "$ModuleName published to PowerShell Gallery"
}
catch {
    Write-Error "Failed to publish $ModuleName to PowerShell Gallery"
    throw $_.Exception.Message
}
