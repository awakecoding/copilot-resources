<#
.SYNOPSIS
    Synchronizes prompt files from workspace to VS Code user profiles and Cursor IDE.

.DESCRIPTION
    Copies all .prompt.md files from the workspace prompts directory to the prompts
    folder of all VS Code user profiles and to Cursor IDE's commands directory.
    
    VS Code: Files are copied as .prompt.md to profile prompts directories
    Cursor IDE: Files are copied as .md to ~/.cursor/commands directory

.PARAMETER WorkspaceRoot
    The root directory of the copilot-resources workspace. Defaults to the script's parent directory.

.PARAMETER DryRun
    If specified, shows what would be copied without actually copying files.

.EXAMPLE
    .\Sync-VSCodeUserPrompts.ps1
    Synchronizes prompts to all VS Code profiles and Cursor IDE using default paths.

.EXAMPLE
    .\Sync-VSCodeUserPrompts.ps1 -DryRun
    Shows what would be synchronized without actually copying.

.EXAMPLE
    .\Sync-VSCodeUserPrompts.ps1 -WorkspaceRoot "D:\dev\copilot-resources"
    Synchronizes prompts using a specific workspace path.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),
    
    [Parameter()]
    [switch]$DryRun
)

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

# Determine VS Code profile paths based on OS
if ($IsWindows -or $null -eq $IsWindows) {
    # Windows (PowerShell 5.1 doesn't have $IsWindows, so it's null)
    $VSCodeUserProfilesPaths = @(
        "$Env:AppData\Code\User\Profiles",
        "$Env:AppData\Code - Insiders\User\Profiles"
    )
    $CursorCommandsPath = "$Env:USERPROFILE\.cursor\commands"
}
elseif ($IsMacOS) {
    # macOS
    $VSCodeUserProfilesPaths = @(
        "$HOME/Library/Application Support/Code/User/Profiles",
        "$HOME/Library/Application Support/Code - Insiders/User/Profiles"
    )
    $CursorCommandsPath = "$HOME/.cursor/commands"
}
elseif ($IsLinux) {
    # Linux
    $VSCodeUserProfilesPaths = @(
        "$HOME/.config/Code/User/Profiles",
        "$HOME/.config/Code - Insiders/User/Profiles"
    )
    $CursorCommandsPath = "$HOME/.cursor/commands"
}
else {
    Write-ColorOutput "ERROR: Unable to determine operating system" -Color Red
    exit 1
}

# Validate workspace prompts directory exists
$sourcePromptsDir = Join-Path $WorkspaceRoot "prompts"
if (-not (Test-Path $sourcePromptsDir)) {
    Write-ColorOutput "ERROR: Source prompts directory not found: $sourcePromptsDir" -Color Red
    exit 1
}

# Get all prompt files from workspace
$promptFiles = Get-ChildItem -Path $sourcePromptsDir -Filter "*.prompt.md"
if ($promptFiles.Count -eq 0) {
    Write-ColorOutput "WARNING: No .prompt.md files found in $sourcePromptsDir" -Color Yellow
    exit 0
}

Write-ColorOutput "`nFound $($promptFiles.Count) prompt file(s) to synchronize:" -Color Cyan
$promptFiles | ForEach-Object { Write-ColorOutput "  - $($_.Name)" -Color Gray }

# Check for Cursor IDE installation
$cursorRootPath = if ($IsWindows -or $null -eq $IsWindows) {
    "$Env:USERPROFILE\.cursor"
} else {
    "$HOME/.cursor"
}

$hasCursor = Test-Path $cursorRootPath
if ($hasCursor) {
    Write-ColorOutput "`nCursor IDE detected at: $cursorRootPath" -Color Cyan
}

# Collect all profile directories from all VS Code installations
$allProfileDirs = @()
foreach ($profilesPath in $VSCodeUserProfilesPaths) {
    if (Test-Path $profilesPath) {
        $edition = if ($profilesPath -like "*Insiders*") { "Insiders" } else { "Stable" }
        $profiles = Get-ChildItem -Path $profilesPath -Directory
        if ($profiles.Count -gt 0) {
            Write-ColorOutput "`nFound $($profiles.Count) profile(s) in VS Code $edition ($profilesPath):" -Color Cyan
            $profiles | ForEach-Object { 
                Write-ColorOutput "  - $($_.Name)" -Color Gray
                $allProfileDirs += [PSCustomObject]@{
                    Directory = $_
                    Edition = $edition
                }
            }
        }
        else {
            Write-ColorOutput "`nNo profiles found in VS Code $edition ($profilesPath)" -Color Gray
        }
    }
    else {
        $edition = if ($profilesPath -like "*Insiders*") { "Insiders" } else { "Stable" }
        Write-ColorOutput "`nVS Code $edition profiles directory not found: $profilesPath" -Color Gray
    }
}

if ($allProfileDirs.Count -eq 0) {
    Write-ColorOutput "`nERROR: No VS Code profiles found in any installation." -Color Red
    Write-ColorOutput "Make sure VS Code is installed and you have created at least one profile." -Color Yellow
    if (-not $hasCursor) {
        exit 1
    }
    Write-ColorOutput "Continuing with Cursor synchronization..." -Color Yellow
}

if ($DryRun) {
    Write-ColorOutput "`n[DRY RUN MODE - No files will be copied]" -Color Yellow
}

Write-ColorOutput "`nSynchronizing prompts..." -Color Cyan

$totalCopied = 0
$totalErrors = 0

# Synchronize to VS Code profiles
foreach ($profileInfo in $allProfileDirs) {
    $profile = $profileInfo.Directory
    $targetPromptsDir = Join-Path $profile.FullName "prompts"
    
    Write-ColorOutput "`nProfile: $($profile.Name) [$($profileInfo.Edition)]" -Color White
    
    # Create prompts directory if it doesn't exist
    if (-not (Test-Path $targetPromptsDir)) {
        if (-not $DryRun) {
            try {
                New-Item -Path $targetPromptsDir -ItemType Directory -Force | Out-Null
                Write-ColorOutput "  Created prompts directory" -Color Green
            }
            catch {
                Write-ColorOutput "  ERROR: Failed to create directory: $_" -Color Red
                $totalErrors++
                continue
            }
        }
        else {
            Write-ColorOutput "  [DRY RUN] Would create prompts directory" -Color Yellow
        }
    }
    
    foreach ($promptFile in $promptFiles) {
        $targetFile = Join-Path $targetPromptsDir $promptFile.Name
        
        if (-not $DryRun) {
            try {
                Copy-Item -Path $promptFile.FullName -Destination $targetFile -Force
                Write-ColorOutput "  ✓ $($promptFile.Name)" -Color Green
                $totalCopied++
            }
            catch {
                Write-ColorOutput "  ✗ $($promptFile.Name) - ERROR: $_" -Color Red
                $totalErrors++
            }
        }
        else {
            Write-ColorOutput "  [DRY RUN] Would copy $($promptFile.Name)" -Color Yellow
            $totalCopied++
        }
    }
}

# Synchronize to Cursor IDE
if ($hasCursor) {
    Write-ColorOutput "`nCursor IDE Commands:" -Color White
    
    # Create commands directory if it doesn't exist
    if (-not (Test-Path $CursorCommandsPath)) {
        if (-not $DryRun) {
            try {
                New-Item -Path $CursorCommandsPath -ItemType Directory -Force | Out-Null
                Write-ColorOutput "  Created commands directory: $CursorCommandsPath" -Color Green
            }
            catch {
                Write-ColorOutput "  ERROR: Failed to create Cursor commands directory: $_" -Color Red
                $totalErrors++
            }
        }
        else {
            Write-ColorOutput "  [DRY RUN] Would create commands directory: $CursorCommandsPath" -Color Yellow
        }
    }
    
    if ((Test-Path $CursorCommandsPath) -or $DryRun) {
        foreach ($promptFile in $promptFiles) {
            # Remove .prompt.md and add .md extension for Cursor
            $cursorFileName = $promptFile.Name -replace '\.prompt\.md$', '.md'
            $targetFile = Join-Path $CursorCommandsPath $cursorFileName
            
            if (-not $DryRun) {
                try {
                    Copy-Item -Path $promptFile.FullName -Destination $targetFile -Force
                    Write-ColorOutput "  ✓ $cursorFileName" -Color Green
                    $totalCopied++
                }
                catch {
                    Write-ColorOutput "  ✗ $cursorFileName - ERROR: $_" -Color Red
                    $totalErrors++
                }
            }
            else {
                Write-ColorOutput "  [DRY RUN] Would copy $($promptFile.Name) as $cursorFileName" -Color Yellow
                $totalCopied++
            }
        }
    }
}

# Summary
Write-ColorOutput "`n$('=' * 60)" -Color Cyan
Write-ColorOutput "Synchronization Summary:" -Color Cyan
Write-ColorOutput "  Files copied: $totalCopied" -Color $(if ($totalCopied -gt 0) { 'Green' } else { 'Gray' })
if ($totalErrors -gt 0) {
    Write-ColorOutput "  Errors: $totalErrors" -Color Red
}
if ($DryRun) {
    Write-ColorOutput "`n  This was a dry run. No files were actually modified." -Color Yellow
}
Write-ColorOutput "$('=' * 60)`n" -Color Cyan

if ($totalErrors -gt 0) {
    exit 1
}
