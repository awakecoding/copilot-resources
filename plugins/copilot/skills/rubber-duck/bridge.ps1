param(
    [switch]$Heredoc,
    [ValidateSet('claude', 'codex')][string]$AgentHost = 'claude',
    [ValidateRange(1, 5400)][int]$TimeoutSeconds = 5400
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$logDirectory = $null
$metadata = $null

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
    $stdin = [IO.StreamReader]::new([Console]::OpenStandardInput(), [Text.UTF8Encoding]::new($false))
    try { $request = $stdin.ReadToEnd() }
    finally { $stdin.Dispose() }
    if ($Heredoc) {
        if ($request.EndsWith("`r`n")) { $request = $request.Substring(0, $request.Length - 2) }
        elseif ($request.EndsWith("`n")) { $request = $request.Substring(0, $request.Length - 1) }
        else { throw 'The request heredoc must end with a newline.' }
    }
    if ([string]::IsNullOrWhiteSpace($request)) { throw 'Provide a review request after /rubber-duck.' }

    $copilot = Resolve-Copilot
    $logRoot = if ($AgentHost -eq 'codex') {
        $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
        Join-Path $codexHome 'logs/rubber-duck'
    }
    else { Join-Path $HOME '.claude/logs/rubber-duck' }
    $logDirectory = Join-Path $logRoot ("{0}-{1}" -f [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ'), [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $logDirectory -Force
    if (-not $IsWindows) {
        [IO.Directory]::SetUnixFileMode($logDirectory, [IO.UnixFileMode]'UserRead,UserWrite,UserExecute')
    }
    [Console]::Error.WriteLine("Rubber-duck log: $logDirectory")

    $metadata = [ordered]@{
        timestampUtc = [DateTimeOffset]::UtcNow.ToString('o')
        workingDirectory = (Get-Location).ProviderPath
        copilotExecutable = $copilot
        parentModel = $null
        criticModel = $null
        modelSelectionSource = $null
        copilotExitCode = $null
        sessionExitCode = $null
        timeoutSeconds = $TimeoutSeconds
        timedOut = $false
        truncatedEvent = $false
        rubberDuckAgentId = $null
        rubberDuckStarted = $false
        rubberDuckCompleted = $false
        agentsStarted = @()
        outcome = 'failed'
        eventCounts = @{}
    }
    $prompt = '/rubber-duck ' + $request
    $arguments = @(
        '--prompt', $prompt,
        '--output-format=json', '--stream=off',
        '--no-ask-user', '--no-auto-update', '--disable-builtin-mcps',
        '--allow-tool=read',
        '--allow-tool=shell(git status),shell(git diff),shell(git log),shell(git show),shell(git rev-parse),shell(git merge-base),shell(git ls-files)',
        '--deny-tool=write', '--deny-tool=url', '--deny-tool=memory', '--deny-tool=shell(git push)'
    )
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
        $metadata.timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($metadata.timedOut) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $null = $stdout.GetAwaiter().GetResult()
        $null = $stderr.GetAwaiter().GetResult()
        $eventFile.Flush()
        $errorFile.Flush()
        $metadata.copilotExitCode = $process.ExitCode
    }
    finally {
        if ($eventFile) { $eventFile.Dispose() }
        if ($errorFile) { $errorFile.Dispose() }
        $process.Dispose()
    }

    $output = [IO.File]::ReadAllText($eventsPath, [Text.Encoding]::UTF8)

    $critiqueMessages = [Collections.Generic.List[string]]::new()
    $lastParentMessage = $null
    $lines = $output -split "`r?`n"
    for ($lineIndex = 0; $lineIndex -lt $lines.Length; $lineIndex++) {
        $line = $lines[$lineIndex]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $event = ConvertFrom-Json -InputObject $line -AsHashtable
        }
        catch {
            # Killing the process can interrupt its final JSON record.
            if ($metadata.timedOut -and $lineIndex -eq $lines.Length - 1 -and -not $output.EndsWith("`n")) {
                $metadata.truncatedEvent = $true
                break
            }
            throw
        }
        $type = $event['type']
        $metadata.eventCounts[$type] = 1 + [int]$metadata.eventCounts[$type]
        $agentId = $event['agentId']
        $data = $event['data']
        if ($data -isnot [Collections.IDictionary]) { $data = @{} }
        if ($type -eq 'model.call_start' -and -not $agentId -and -not $metadata.parentModel) {
            $metadata.parentModel = $data['model']
        }
        elseif ($type -eq 'subagent.started') {
            $metadata.agentsStarted += [ordered]@{ name = $data['agentName']; model = $data['model'] }
            if ($data['agentName'] -eq 'rubber-duck') {
                # A later rubber-duck invocation supersedes earlier ones.
                $metadata.rubberDuckStarted = $true
                $metadata.rubberDuckCompleted = $false
                $metadata.rubberDuckAgentId = $agentId
                $critiqueMessages.Clear()
                $metadata.criticModel = $data['model']
                $metadata.modelSelectionSource = $data['modelSelectionSource']
            }
        }
        elseif ($type -eq 'assistant.message') {
            $content = $data['content']
            if ($content -isnot [string] -or -not $content.Trim()) { continue }
            if ($agentId) {
                # Messages that also request tools are progress narration, not the critique.
                $toolRequests = $data['toolRequests']
                $hasToolRequests = $toolRequests -and @($toolRequests).Count -gt 0
                if ($metadata.rubberDuckAgentId -and $agentId -eq $metadata.rubberDuckAgentId -and -not $metadata.rubberDuckCompleted -and -not $hasToolRequests) {
                    $critiqueMessages.Add($content)
                }
            }
            elseif (-not $metadata.rubberDuckStarted) {
                $lastParentMessage = $content
            }
        }
        elseif ($type -eq 'subagent.completed' -and $metadata.rubberDuckAgentId -and $agentId -eq $metadata.rubberDuckAgentId) {
            $metadata.rubberDuckCompleted = $true
        }
        elseif ($type -eq 'result') { $metadata.sessionExitCode = $event['exitCode'] }
    }

    if ($metadata.timedOut) { throw "Copilot CLI timed out after $TimeoutSeconds seconds; partial events and stderr are in the log." }
    if ($metadata.copilotExitCode -ne 0) {
        throw "Copilot CLI exited with code $($metadata.copilotExitCode). See stderr.txt and events.jsonl."
    }
    if ($metadata.sessionExitCode -ne 0) {
        throw "Copilot session ended with exit code $($metadata.sessionExitCode). See events.jsonl."
    }
    if (-not $metadata.rubberDuckCompleted) {
        if ($lastParentMessage) {
            [IO.File]::WriteAllText((Join-Path $logDirectory 'parent-response.txt'), $lastParentMessage, [Text.UTF8Encoding]::new($false))
        }
        $reason = if ($lastParentMessage) { $lastParentMessage.Trim() } else { 'No parent response was recorded.' }
        if ($reason.Length -gt 500) { $reason = $reason.Substring(0, 500) + '...' }
        $status = if ($metadata.rubberDuckStarted) { 'started but did not complete' } else { 'was not invoked' }
        throw "The built-in rubber-duck subagent $status. Copilot said: $reason"
    }
    if ($critiqueMessages.Count -eq 0) { throw 'The built-in rubber-duck subagent completed without a critique.' }
    $critique = $critiqueMessages -join "`n`n"
    $verifiedModel = if ($metadata.criticModel) { $metadata.criticModel } else { 'not reported' }
    $selection = if ($metadata.modelSelectionSource) { $metadata.modelSelectionSource } else { 'not reported' }
    $report = "**Verified rubber-duck critic model:** ``$verifiedModel`` (Copilot selection: ``$selection``).`n`n$critique"
    [IO.File]::WriteAllText((Join-Path $logDirectory 'critique.md'), $report, [Text.UTF8Encoding]::new($false))
    $metadata.outcome = 'success'
    $metadata.timestampUtc = [DateTimeOffset]::UtcNow.ToString('o')
    [IO.File]::WriteAllText((Join-Path $logDirectory 'metadata.json'), ($metadata | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    [Console]::Out.WriteLine($report)
}
catch {
    [Console]::Error.WriteLine("Rubber-duck bridge failed: $($_.Exception.Message)")
    if ($logDirectory) {
        try {
            if ($metadata) {
                $metadata.outcome = 'failed'
                $metadata.timestampUtc = [DateTimeOffset]::UtcNow.ToString('o')
                [IO.File]::WriteAllText((Join-Path $logDirectory 'metadata.json'), ($metadata | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
            }
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
