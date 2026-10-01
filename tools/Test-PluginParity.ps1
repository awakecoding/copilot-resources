#Requires -Version 7.0
<#
.SYNOPSIS
Validates the plugin manifests and scripts, and checks that the Claude Code, OpenAI Codex, and Cursor wrappers stay in sync.
.DESCRIPTION
Fails (exit code 1) when JSON or PowerShell files do not parse, when a command exists for only one host,
or when the hosts disagree on a command's name, bridge script, review type, or the plugin's name or version.
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()
function Fail([string]$Message) { $failures.Add($Message) }

function Read-Text([string]$Path) {
    [System.IO.File]::ReadAllText($Path) -replace "`r`n", "`n"
}

function Get-Frontmatter([string]$Path) {
    $text = Read-Text $Path
    $values = @{}
    if ($text -match '(?s)\A---\n(.*?)\n---\n') {
        foreach ($line in $Matches[1] -split "`n") {
            if ($line -match '^([A-Za-z0-9_-]+):\s*(.*)$') { $values[$Matches[1]] = $Matches[2].Trim() }
        }
    } else {
        Fail "${Path}: missing YAML frontmatter"
    }
    $values
}

function Read-Json([string]$RelativePath) {
    $path = Join-Path $RepositoryRoot $RelativePath
    try { Get-Content -Raw -LiteralPath $path | ConvertFrom-Json }
    catch { Fail "${RelativePath}: invalid JSON ($($_.Exception.Message))"; $null }
}

function Get-Names([string]$Path, [switch]$Directories, [string]$Filter = '*') {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $items = if ($Directories) { Get-ChildItem -LiteralPath $Path -Directory } else { Get-ChildItem -LiteralPath $Path -File -Filter $Filter }
    @($items | ForEach-Object { if ($Directories) { $_.Name } else { $_.BaseName } } | Sort-Object)
}

function Get-ReviewTypes([string]$Text) {
    @([regex]::Matches($Text, '-ReviewType\s+([A-Za-z-]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
}

$plugin = Join-Path $RepositoryRoot 'plugins/copilot'

# Manifests and marketplaces
$claudeMarketplace = Read-Json '.claude-plugin/marketplace.json'
$codexMarketplace = Read-Json '.agents/plugins/marketplace.json'
$claudeManifest = Read-Json 'plugins/copilot/.claude-plugin/plugin.json'
$codexManifest = Read-Json 'plugins/copilot/.codex-plugin/plugin.json'
$cursorManifest = Read-Json 'plugins/copilot/.cursor-plugin/plugin.json'

if ($claudeManifest -and $codexManifest) {
    if ($claudeManifest.name -cne $codexManifest.name) { Fail "Plugin names differ: Claude '$($claudeManifest.name)', Codex '$($codexManifest.name)'" }
    if ($claudeManifest.version -cne $codexManifest.version) { Fail "Plugin versions differ: Claude '$($claudeManifest.version)', Codex '$($codexManifest.version)'" }
    if ($codexManifest.skills -cne './codex-skills/') { Fail "Codex manifest must set skills to './codex-skills/' so it does not load the Claude skills" }
}
if ($claudeManifest -and $cursorManifest) {
    if ($claudeManifest.name -cne $cursorManifest.name) { Fail "Plugin names differ: Claude '$($claudeManifest.name)', Cursor '$($cursorManifest.name)'" }
    if ($claudeManifest.version -cne $cursorManifest.version) { Fail "Plugin versions differ: Claude '$($claudeManifest.version)', Cursor '$($cursorManifest.version)'" }
    if ($cursorManifest.skills -cne './cursor-skills/') { Fail "Cursor manifest must set skills to './cursor-skills/' so it does not load the Claude skills" }
    if ($cursorManifest.commands -cne './commands/') { Fail "Cursor manifest must set commands to './commands/'" }
}
if ($claudeMarketplace -and $codexMarketplace -and $claudeManifest -and $codexManifest) {
    if ($claudeMarketplace.name -cne $codexMarketplace.name) { Fail "Marketplace names differ: Claude '$($claudeMarketplace.name)', Codex '$($codexMarketplace.name)'" }
    $claudeEntry = @($claudeMarketplace.plugins | Where-Object name -ceq $claudeManifest.name)
    $codexEntry = @($codexMarketplace.plugins | Where-Object name -ceq $codexManifest.name)
    if ($claudeEntry.Count -ne 1) { Fail "Claude marketplace must list plugin '$($claudeManifest.name)' once" }
    if ($codexEntry.Count -ne 1) { Fail "Codex marketplace must list plugin '$($codexManifest.name)' once" }
    if ($claudeEntry.Count -eq 1 -and $codexEntry.Count -eq 1) {
        $claudeSource = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $claudeEntry[0].source))
        $codexSource = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $codexEntry[0].source.path))
        if ($claudeSource -ne $codexSource) { Fail "Marketplaces point to different plugin folders: '$($claudeEntry[0].source)' and '$($codexEntry[0].source.path)'" }
    }
}

# PowerShell syntax
foreach ($script in Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -Filter '*.ps1' | Where-Object FullName -notmatch '[\\/]\.git[\\/]') {
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$null, [ref]$errors)
    if ($errors) { Fail "$($script.FullName): PowerShell parse errors: $($errors[0].Message)" }
}

# Command sets
$claudeSkills = Get-Names (Join-Path $plugin 'skills') -Directories
$claudeAgents = Get-Names (Join-Path $plugin 'agents') -Filter '*.md'
$codexSkills = Get-Names (Join-Path $plugin 'codex-skills') -Directories
$cursorSkills = Get-Names (Join-Path $plugin 'cursor-skills') -Directories
$cursorCommands = Get-Names (Join-Path $plugin 'commands') -Filter '*.md'
$allCommands = @($claudeSkills + $claudeAgents + $codexSkills + $cursorSkills + $cursorCommands | Sort-Object -Unique)

foreach ($command in $allCommands) {
    $claudeSkillPath = Join-Path $plugin "skills/$command/SKILL.md"
    $claudeAgentPath = Join-Path $plugin "agents/$command.md"
    $codexSkillPath = Join-Path $plugin "codex-skills/$command/SKILL.md"
    $openAiYamlPath = Join-Path $plugin "codex-skills/$command/agents/openai.yaml"
    $cursorSkillPath = Join-Path $plugin "cursor-skills/$command/SKILL.md"
    $cursorCommandPath = Join-Path $plugin "commands/$command.md"

    $missing = @(
        if (-not (Test-Path -LiteralPath $claudeSkillPath)) { 'Claude skill (skills/<name>/SKILL.md)' }
        if (-not (Test-Path -LiteralPath $claudeAgentPath)) { 'Claude agent (agents/<name>.md)' }
        if (-not (Test-Path -LiteralPath $codexSkillPath)) { 'Codex skill (codex-skills/<name>/SKILL.md)' }
        if (-not (Test-Path -LiteralPath $openAiYamlPath)) { 'Codex metadata (codex-skills/<name>/agents/openai.yaml)' }
        if (-not (Test-Path -LiteralPath $cursorSkillPath)) { 'Cursor skill (cursor-skills/<name>/SKILL.md)' }
        if (-not (Test-Path -LiteralPath $cursorCommandPath)) { 'Cursor command (commands/<name>.md)' }
    )
    if ($missing) { Fail "Command '$command' is missing: $($missing -join ', ')"; continue }

    $claudeSkill = Get-Frontmatter $claudeSkillPath
    $claudeAgent = Get-Frontmatter $claudeAgentPath
    $codexSkill = Get-Frontmatter $codexSkillPath
    $cursorSkill = Get-Frontmatter $cursorSkillPath
    $cursorCommand = Get-Frontmatter $cursorCommandPath
    foreach ($pair in @(@('Claude skill', $claudeSkill), @('Claude agent', $claudeAgent), @('Codex skill', $codexSkill), @('Cursor skill', $cursorSkill), @('Cursor command', $cursorCommand))) {
        if ($pair[1].name -cne $command) { Fail "${command}: $($pair[0]) frontmatter name is '$($pair[1].name)'" }
        if (-not $pair[1].description) { Fail "${command}: $($pair[0]) has no description" }
    }
    if ($claudeSkill.agent -cne "copilot:$command") { Fail "${command}: Claude skill must fork into agent 'copilot:$command' (found '$($claudeSkill.agent)')" }
    if ($claudeSkill.'disable-model-invocation' -ne 'true') { Fail "${command}: Claude skill must set disable-model-invocation: true" }

    $openAiYaml = Read-Text $openAiYamlPath
    if ($openAiYaml -notmatch '(?m)^\s*allow_implicit_invocation:\s*false\s*$') { Fail "${command}: openai.yaml must set allow_implicit_invocation: false" }
    if ($openAiYaml -notmatch [regex]::Escape("`$copilot:$command")) { Fail "${command}: openai.yaml default_prompt must use `$copilot:$command" }

    $agentText = Read-Text $claudeAgentPath
    $codexText = Read-Text $codexSkillPath
    $cursorText = Read-Text $cursorSkillPath

    $claudeBridge = [regex]::Match($agentText, '\$\{CLAUDE_PLUGIN_ROOT\}/([^"\s]+\.ps1)').Groups[1].Value
    $codexBridge = [regex]::Match($codexText, '`\.\./\.\./([^`]+\.ps1)`').Groups[1].Value
    $cursorBridge = [regex]::Match($cursorText, '`\.\./\.\./([^`]+\.ps1)`').Groups[1].Value
    if (-not $claudeBridge) { Fail "${command}: Claude agent does not reference a bridge under `${CLAUDE_PLUGIN_ROOT}" }
    if (-not $codexBridge) { Fail "${command}: Codex skill does not reference a bridge as ``../../<path>.ps1``" }
    if (-not $cursorBridge) { Fail "${command}: Cursor skill does not reference a bridge as ``../../<path>.ps1``" }
    if ($claudeBridge -and $codexBridge) {
        if ($claudeBridge -cne $codexBridge) { Fail "${command}: bridges differ (Claude '$claudeBridge', Codex '$codexBridge')" }
        elseif (-not (Test-Path -LiteralPath (Join-Path $plugin $claudeBridge))) { Fail "${command}: bridge '$claudeBridge' does not exist" }
    }
    if ($codexBridge -and $cursorBridge -and $codexBridge -cne $cursorBridge) {
        Fail "${command}: bridges differ (Codex '$codexBridge', Cursor '$cursorBridge')"
    }

    $claudeTypes = Get-ReviewTypes $agentText
    $codexTypes = Get-ReviewTypes $codexText
    $cursorTypes = Get-ReviewTypes $cursorText
    if (($claudeTypes -join ',') -cne ($codexTypes -join ',')) {
        Fail "${command}: -ReviewType differs (Claude '$($claudeTypes -join ',')', Codex '$($codexTypes -join ',')')"
    }
    if (($codexTypes -join ',') -cne ($cursorTypes -join ',')) {
        Fail "${command}: -ReviewType differs (Codex '$($codexTypes -join ',')', Cursor '$($cursorTypes -join ',')')"
    }

    $codexInvocations = @($codexText -split "`n" | Where-Object { $_ -match '\bpwsh\b.*-File\b' })
    if (-not $codexInvocations) { Fail "${command}: Codex skill has no pwsh invocation" }
    foreach ($line in $codexInvocations) {
        if ($line -notmatch '-AgentHost\s+codex\b') { Fail "${command}: Codex invocation lacks -AgentHost codex: $($line.Trim())" }
    }
    $cursorInvocations = @($cursorText -split "`n" | Where-Object { $_ -match '\bpwsh\b.*-File\b' })
    if (-not $cursorInvocations) { Fail "${command}: Cursor skill has no pwsh invocation" }
    foreach ($line in $cursorInvocations) {
        if ($line -notmatch '-AgentHost\s+cursor\b') { Fail "${command}: Cursor invocation lacks -AgentHost cursor: $($line.Trim())" }
    }
    if ($agentText -match '-AgentHost\s+codex\b') { Fail "${command}: Claude agent must not pass -AgentHost codex" }
    if ($agentText -match '-AgentHost\s+cursor\b') { Fail "${command}: Claude agent must not pass -AgentHost cursor" }
    if ($codexText -match '-AgentHost\s+cursor\b') { Fail "${command}: Codex skill must not pass -AgentHost cursor" }
    if ($cursorText -match '-AgentHost\s+codex\b') { Fail "${command}: Cursor skill must not pass -AgentHost codex" }
    if ($codexText -notmatch [regex]::Escape("`$copilot:$command")) { Fail "${command}: Codex skill never mentions `$copilot:$command" }
    if ($cursorText -notmatch [regex]::Escape("`$copilot:$command")) { Fail "${command}: Cursor skill never mentions `$copilot:$command" }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    Write-Host "$($failures.Count) parity or validation problem(s) found." -ForegroundColor Red
    exit 1
}
Write-Host "OK: $($allCommands.Count) commands ($($allCommands -join ', ')) are in sync across Claude Code, Codex, and Cursor."
