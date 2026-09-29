param(
    [Parameter(Mandatory)][ValidateSet('rubber-duck', 'read', 'write')][string]$Mode,
    [switch]$Heredoc,
    [ValidateRange(1, 480)][int]$TimeoutSeconds = 480
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$logDirectory = $null

function Resolve-Copilot {
    $command = Get-Command copilot -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }

    if ($IsWindows) {
        $paths = @(
            [Environment]::GetEnvironmentVariable('Path', 'User'),
            [Environment]::GetEnvironmentVariable('Path', 'Machine')
        ) | Where-Object { $_ }
        if ($paths) {
            $env:Path = ($env:Path, ($paths -join [IO.Path]::PathSeparator)) -join [IO.Path]::PathSeparator
            $command = Get-Command copilot -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($command) { return $command.Source }
        }

        $winget = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GitHub.Copilot_Microsoft.Winget.Source_8wekyb3d8bbwe\copilot.exe'
        if (Test-Path -LiteralPath $winget -PathType Leaf) { return $winget }
    }

    throw 'Copilot CLI was not found. Install it and ensure its directory is on PATH.'
}

try {
    $request = [Console]::In.ReadToEnd()
    if ($Heredoc) {
        if ($request.EndsWith("`r`n")) { $request = $request.Substring(0, $request.Length - 2) }
        elseif ($request.EndsWith("`n")) { $request = $request.Substring(0, $request.Length - 1) }
        else { throw 'The request heredoc must end with a newline.' }
    }
    $model = $null
    if ($Mode -ne 'rubber-duck') {
        # Only a leading --model option is recognized; the rest of the request is passed through unchanged.
        $match = [regex]::Match($request, '\A--model(?:=|[ \t]+)([A-Za-z0-9._:-]+)(?:[ \t]*\r?\n|[ \t]+)')
        if ($match.Success) {
            $model = $match.Groups[1].Value
            $request = $request.Substring($match.Length)
        }
    }
    if ([string]::IsNullOrWhiteSpace($request)) { throw 'Provide a request after the command.' }

    $readOnlyTools = @(
        '--allow-tool=read', '--allow-tool=shell(git status),shell(git diff)',
        '--deny-tool=write', '--deny-tool=url', '--deny-tool=memory'
    )
    $modeConfig = @{
        'rubber-duck' = @{ Prefix = '/rubber-duck '; RequiredAgent = 'rubber-duck'; LogName = 'rubber-duck'; Tools = $readOnlyTools }
        'read' = @{ Prefix = ''; RequiredAgent = $null; LogName = 'copilot-cli'; Tools = $readOnlyTools }
        'write' = @{
            Prefix = ''; RequiredAgent = $null; LogName = 'copilot-cli'
            Tools = @(
                '--allow-tool=read', '--allow-tool=write', '--allow-tool=shell',
                '--deny-tool=shell(git push)', '--deny-tool=url', '--deny-tool=memory'
            )
        }
    }[$Mode]
    $requiredAgent = $modeConfig.RequiredAgent

    $copilot = Resolve-Copilot
    $logRoot = Join-Path $HOME ".claude/logs/$($modeConfig.LogName)"
    $logDirectory = Join-Path $logRoot ("{0}-{1}" -f [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ'), [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $logDirectory -Force
    if (-not $IsWindows) {
        [IO.Directory]::SetUnixFileMode($logDirectory, [IO.UnixFileMode]'UserRead,UserWrite,UserExecute')
    }
    [Console]::Error.WriteLine("Copilot bridge ($Mode) log: $logDirectory")

    $prompt = $modeConfig.Prefix + $request
    $arguments = @(
        '--prompt', $prompt,
        '--output-format=json', '--stream=off',
        '--no-ask-user', '--no-auto-update', '--disable-builtin-mcps'
    ) + $modeConfig.Tools
    if ($model) { $arguments += @('--model', $model) }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $copilot
    $info.WorkingDirectory = (Get-Location).ProviderPath
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $arguments) { $null = $info.ArgumentList.Add($argument) }
    $null = $info.Environment.Remove('COPILOT_ALLOW_ALL')

    $eventsPath = Join-Path $logDirectory 'events.jsonl'
    $stderrPath = Join-Path $logDirectory 'stderr.txt'
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $eventFile = $null
    $errorFile = $null
    try {
        $eventFile = [IO.FileStream]::new($eventsPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read, 1, [IO.FileOptions]::Asynchronous)
        $errorFile = [IO.FileStream]::new($stderrPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read, 1, [IO.FileOptions]::Asynchronous)
        if (-not $IsWindows) {
            [IO.File]::SetUnixFileMode($eventsPath, [IO.UnixFileMode]'UserRead,UserWrite')
            [IO.File]::SetUnixFileMode($stderrPath, [IO.UnixFileMode]'UserRead,UserWrite')
        }
        $null = $process.Start()
        $stdout = $process.StandardOutput.BaseStream.CopyToAsync($eventFile)
        $stderr = $process.StandardError.BaseStream.CopyToAsync($errorFile)
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $null = $stdout.GetAwaiter().GetResult()
        $null = $stderr.GetAwaiter().GetResult()
        $eventFile.Flush()
        $errorFile.Flush()
        $exitCode = $process.ExitCode
    }
    finally {
        if ($eventFile) { $eventFile.Dispose() }
        if ($errorFile) { $errorFile.Dispose() }
        $process.Dispose()
    }

    if ($timedOut) { throw "Copilot CLI timed out after $TimeoutSeconds seconds; partial events and stderr are in the log." }
    $output = [IO.File]::ReadAllText($eventsPath, [Text.Encoding]::UTF8)

    $started = $false
    $completed = $false
    $targetAgentId = $null
    $resultMessages = [Collections.Generic.List[string]]::new()
    $parentFinalMessages = [Collections.Generic.List[string]]::new()
    $lastParentMessage = $null
    $parentModel = $null
    $criticModel = $null
    $modelSelection = $null
    $sessionExitCode = $null
    $agentsStarted = @()
    $eventCounts = @{}
    foreach ($line in ($output -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $event = ConvertFrom-Json -InputObject $line -AsHashtable
        $type = $event['type']
        $eventCounts[$type] = 1 + [int]$eventCounts[$type]
        $agentId = $event['agentId']
        $data = $event['data']
        if ($data -isnot [Collections.IDictionary]) { $data = @{} }
        if ($type -eq 'model.call_start' -and -not $agentId -and -not $parentModel) {
            $parentModel = $data['model']
        }
        elseif ($type -eq 'subagent.started') {
            $agentsStarted += [ordered]@{ name = $data['agentName']; model = $data['model'] }
            if ($requiredAgent -and $data['agentName'] -eq $requiredAgent) {
                # A later invocation of the required agent supersedes earlier ones.
                $started = $true
                $completed = $false
                $targetAgentId = $agentId
                $resultMessages.Clear()
                $criticModel = $data['model']
                $modelSelection = $data['modelSelectionSource']
            }
        }
        elseif ($type -eq 'assistant.message') {
            $content = $data['content']
            if ($content -isnot [string] -or -not $content.Trim()) { continue }
            # Messages that also request tools are progress narration, not the answer.
            $toolRequests = $data['toolRequests']
            $isFinal = -not ($toolRequests -and @($toolRequests).Count -gt 0)
            if ($agentId) {
                if ($isFinal -and $targetAgentId -and $agentId -eq $targetAgentId -and -not $completed) {
                    $resultMessages.Add($content)
                }
            }
            else {
                $lastParentMessage = $content
                if ($isFinal) { $parentFinalMessages.Add($content) }
            }
        }
        elseif ($type -eq 'subagent.completed' -and $targetAgentId -and $agentId -eq $targetAgentId) {
            $completed = $true
        }
        elseif ($type -eq 'result') { $sessionExitCode = $event['exitCode'] }
    }

    if (-not $requiredAgent) {
        $started = $true
        $completed = $true
        foreach ($message in $parentFinalMessages) { $resultMessages.Add($message) }
    }

    $metadata = [ordered]@{
        timestampUtc = [DateTimeOffset]::UtcNow.ToString('o')
        mode = $Mode
        workingDirectory = $info.WorkingDirectory
        copilotExecutable = $copilot
        requestedModel = $model
        parentModel = $parentModel
        requiredAgent = $requiredAgent
        criticModel = $criticModel
        modelSelectionSource = $modelSelection
        copilotExitCode = $exitCode
        sessionExitCode = $sessionExitCode
        requiredAgentStarted = $started
        requiredAgentCompleted = $completed
        agentsStarted = $agentsStarted
        outcome = if ($exitCode -eq 0 -and $sessionExitCode -eq 0 -and $completed -and $resultMessages.Count -gt 0) { 'success' } else { 'failed' }
        eventCounts = $eventCounts
    }
    [IO.File]::WriteAllText((Join-Path $logDirectory 'metadata.json'), ($metadata | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))

    if ($exitCode -ne 0) {
        throw "Copilot CLI exited with code $exitCode. See stderr.txt and events.jsonl."
    }
    if ($sessionExitCode -ne 0) {
        throw "Copilot session ended with exit code $sessionExitCode. See events.jsonl."
    }
    if (-not $completed) {
        if ($lastParentMessage) {
            [IO.File]::WriteAllText((Join-Path $logDirectory 'parent-response.txt'), $lastParentMessage, [Text.UTF8Encoding]::new($false))
        }
        $reason = if ($lastParentMessage) { $lastParentMessage.Trim() } else { 'No parent response was recorded.' }
        if ($reason.Length -gt 500) { $reason = $reason.Substring(0, 500) + '...' }
        $status = if ($started) { 'started but did not complete' } else { 'was not invoked' }
        throw "The built-in $requiredAgent subagent $status. Copilot said: $reason"
    }
    if ($resultMessages.Count -eq 0) {
        $who = if ($requiredAgent) { "The built-in $requiredAgent subagent" } else { 'Copilot' }
        throw "$who completed without a final response."
    }
    $body = $resultMessages -join "`n`n"
    if ($requiredAgent) {
        $verifiedModel = if ($criticModel) { $criticModel } else { 'not reported' }
        $selection = if ($modelSelection) { $modelSelection } else { 'not reported' }
        $report = "**Verified $requiredAgent critic model:** ``$verifiedModel`` (Copilot selection: ``$selection``).`n`n$body"
        $reportName = 'critique.md'
    }
    else {
        $verifiedModel = if ($parentModel) { $parentModel } else { 'not reported' }
        $access = if ($Mode -eq 'write') { 'write-enabled' } else { 'read-only' }
        $report = "**Copilot CLI model:** ``$verifiedModel`` ($access).`n`n$body"
        $reportName = 'result.md'
    }
    [IO.File]::WriteAllText((Join-Path $logDirectory $reportName), $report, [Text.UTF8Encoding]::new($false))
    [Console]::Out.WriteLine($report)
}
catch {
    [Console]::Error.WriteLine("Copilot bridge ($Mode) failed: $($_.Exception.Message)")
    if ($logDirectory) {
        try {
            [IO.File]::WriteAllText(
                (Join-Path $logDirectory 'failure.txt'),
                "$([DateTimeOffset]::UtcNow.ToString('o')) $($_.Exception.Message)",
                [Text.UTF8Encoding]::new($false)
            )
        }
        catch { [Console]::Error.WriteLine("Could not save failure log: $($_.Exception.Message)") }
    }
    exit 1
}
