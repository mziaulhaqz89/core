#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automates Power Platform solution versioning and export process
.DESCRIPTION
    This script:
    1. Checks the existing version of the solution
    2. Increments the version (patch version by default)
    3. Exports the solution as unmanaged and unpacks it
    4. Exports the solution as managed and unpacks it
.PARAMETER SolutionName
    Name of the solution to export (default: "main")
.PARAMETER VersionType
    Type of version increment: patch, minor, major (default: "patch")
.EXAMPLE
    ./export-solution.ps1 -SolutionName "main" -VersionType "patch"
#>

param(
    [string]$SolutionName = "main",
    [ValidateSet("patch", "minor", "major")]
    [string]$VersionType = "patch"
)

# Function to increment version
function Get-IncrementedVersion {
    param(
        [string]$CurrentVersion,
        [string]$IncrementType
    )
    
    $versionParts = $CurrentVersion.Split('.')
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $build = [int]$versionParts[2]
    $revision = [int]$versionParts[3]
    
    switch ($IncrementType) {
        "major" {
            $major++
            $minor = 0
            $build = 0
            $revision = 0
        }
        "minor" {
            $minor++
            $build = 0
            $revision = 0
        }
        "patch" {
            $revision++
        }
    }
    
    return "$major.$minor.$build.$revision"
}

# Function to get current solution version
function Get-CurrentSolutionVersion {
    param([string]$SolutionName)
    
    Write-Host "🔍 Checking current version of solution '$SolutionName'..." -ForegroundColor Cyan
    
    # Get solution list as text and parse manually
    $solutionOutput = pac solution list
    
    # Find the line with our solution
    $solutionLine = $solutionOutput | Where-Object { $_ -match "^$SolutionName\s+" }
    
    if (-not $solutionLine) {
        throw "Solution '$SolutionName' not found!"
    }
    
    # Extract version using regex (assuming format: name friendly_name version managed)
    if ($solutionLine -match "^$SolutionName\s+.*?\s+(\d+\.\d+\.\d+\.\d+)\s+") {
        return $matches[1]
    }
    
    throw "Could not parse version from solution list"
}

# Function to update solution version
function Update-SolutionVersion {
    param(
        [string]$SolutionName,
        [string]$NewVersion
    )
    
    Write-Host "⬆️  Updating solution version to $NewVersion..." -ForegroundColor Yellow
    
    # Update the solution version
    $result = pac solution online-version --solution-name $SolutionName --solution-version $NewVersion
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update solution version"
    }
    
    Write-Host "✅ Solution version updated successfully!" -ForegroundColor Green
}

# Function to export and unpack solution
function Export-AndUnpackSolution {
    param(
        [string]$SolutionName,
        [string]$FolderPath,
        [bool]$IsManaged
    )
    
    $managedText = if ($IsManaged) { "managed" } else { "unmanaged" }
    $packageType = if ($IsManaged) { "Managed" } else { "Unmanaged" }
    
    Write-Host "📦 Exporting $managedText solution..." -ForegroundColor Cyan
    
    # Create temporary zip file
    $tempZip = "./temp_$managedText.zip"
    
    # Export solution
    pac solution export --name $SolutionName --path $tempZip --managed $IsManaged
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to export $managedText solution"
    }
    
    # Clean existing folder
    if (Test-Path $FolderPath) {
        Write-Host "🧹 Cleaning existing $managedText folder..." -ForegroundColor Yellow
        Remove-Item $FolderPath -Recurse -Force
    }
    
    # Create folder
    New-Item -ItemType Directory -Path $FolderPath -Force | Out-Null
    
    # Unpack solution
    Write-Host "📂 Unpacking $managedText solution..." -ForegroundColor Cyan
    pac solution unpack --zipfile $tempZip --folder $FolderPath --packagetype $packageType
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to unpack $managedText solution"
    }
    
    # Clean up temp zip
    Remove-Item $tempZip -Force
    
    Write-Host "✅ $managedText solution exported and unpacked successfully!" -ForegroundColor Green
}

# Main script execution
try {
    Write-Host "🚀 Starting automated solution export process..." -ForegroundColor Magenta
    Write-Host "Solution: $SolutionName" -ForegroundColor White
    Write-Host "Version increment type: $VersionType" -ForegroundColor White
    Write-Host ""
    
    # Step 1: Get current version
    $currentVersion = Get-CurrentSolutionVersion -SolutionName $SolutionName
    Write-Host "📋 Current version: $currentVersion" -ForegroundColor White
    
    # Step 2: Calculate new version
    $newVersion = Get-IncrementedVersion -CurrentVersion $currentVersion -IncrementType $VersionType
    Write-Host "📋 New version: $newVersion" -ForegroundColor White
    Write-Host ""
    
    # Step 3: Update solution version
    Update-SolutionVersion -SolutionName $SolutionName -NewVersion $newVersion
    Write-Host ""
    
    # Step 4: Export and unpack unmanaged solution
    Export-AndUnpackSolution -SolutionName $SolutionName -FolderPath "./$SolutionName/unmanaged" -IsManaged $false
    Write-Host ""
    
    # Step 5: Export and unpack managed solution
    Export-AndUnpackSolution -SolutionName $SolutionName -FolderPath "./$SolutionName/managed" -IsManaged $true
    Write-Host ""
    
    Write-Host "🎉 All steps completed successfully!" -ForegroundColor Green
    Write-Host "📁 Solutions exported to:" -ForegroundColor White
    Write-Host "   - Unmanaged: ./$SolutionName/unmanaged" -ForegroundColor Gray
    Write-Host "   - Managed: ./$SolutionName/managed" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
