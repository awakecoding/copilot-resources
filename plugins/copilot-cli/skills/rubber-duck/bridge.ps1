param(
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
    if ([string]::IsNullOrWhiteSpace($request)) { throw 'Provide a review request after /rubber-duck.' }

    $copilot = Resolve-Copilot
    $logRoot = Join-Path $HOME '.claude/logs/rubber-duck'
    $logDirectory = Join-Path $logRoot ("{0}-{1}" -f [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ'), [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $logDirectory -Force
    if (-not $IsWindows) {
        [IO.Directory]::SetUnixFileMode($logDirectory, [IO.UnixFileMode]'UserRead,UserWrite,UserExecute')
    }
    [Console]::Error.WriteLine("Rubber-duck log: $logDirectory")

    $prompt = '/rubber-duck ' + $request
    $arguments = @(
        '--prompt', $prompt,
        '--output-format=json', '--stream=off',
        '--no-ask-user', '--no-auto-update', '--disable-builtin-mcps',
        '--allow-tool=read', '--allow-tool=shell(git status),shell(git diff)',
        '--deny-tool=write', '--deny-tool=url', '--deny-tool=memory'
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
    $rubberDuckAgentId = $null
    $critiqueMessages = [Collections.Generic.List[string]]::new()
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
        $data = $event['data']
        if ($type -eq 'model.call_start' -and -not $parentModel) {
            $parentModel = $data.model
        }
        elseif ($type -eq 'subagent.started') {
            $agentsStarted += [ordered]@{ name = $data.agentName; model = $data.model }
            if ($data.agentName -eq 'rubber-duck') {
                # A later rubber-duck invocation supersedes earlier ones.
                $started = $true
                $completed = $false
                $rubberDuckAgentId = $event['agentId']
                $critiqueMessages.Clear()
                $criticModel = $data.model
                $modelSelection = $data.modelSelectionSource
            }
        }
        elseif ($type -eq 'assistant.message') {
            $content = $data.content
            if ($content -isnot [string] -or -not $content.Trim()) { continue }
            $agentId = $event['agentId']
            if ($agentId) {
                # Messages that also request tools are progress narration, not the critique.
                $hasToolRequests = $data.toolRequests -and @($data.toolRequests).Count -gt 0
                if ($rubberDuckAgentId -and $agentId -eq $rubberDuckAgentId -and -not $completed -and -not $hasToolRequests) {
                    $critiqueMessages.Add($content)
                }
            }
            elseif (-not $started) {
                $lastParentMessage = $content
            }
        }
        elseif ($type -eq 'subagent.completed' -and $rubberDuckAgentId -and $event['agentId'] -eq $rubberDuckAgentId) {
            $completed = $true
        }
        elseif ($type -eq 'result') { $sessionExitCode = $event['exitCode'] }
    }

    $metadata = [ordered]@{
        timestampUtc = [DateTimeOffset]::UtcNow.ToString('o')
        workingDirectory = $info.WorkingDirectory
        copilotExecutable = $copilot
        parentModel = $parentModel
        criticModel = $criticModel
        modelSelectionSource = $modelSelection
        copilotExitCode = $exitCode
        sessionExitCode = $sessionExitCode
        rubberDuckStarted = $started
        rubberDuckCompleted = $completed
        agentsStarted = $agentsStarted
        outcome = if ($exitCode -eq 0 -and $sessionExitCode -eq 0 -and $completed -and $critiqueMessages.Count -gt 0) { 'success' } else { 'failed' }
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
        throw "The built-in rubber-duck subagent $status. Copilot said: $reason"
    }
    if ($critiqueMessages.Count -eq 0) { throw 'The built-in rubber-duck subagent completed without a critique.' }
    $critique = $critiqueMessages -join "`n`n"
    $verifiedModel = if ($criticModel) { $criticModel } else { 'not reported' }
    $selection = if ($modelSelection) { $modelSelection } else { 'not reported' }
    $report = "**Verified rubber-duck critic model:** ``$verifiedModel`` (Copilot selection: ``$selection``).`n`n$critique"
    [IO.File]::WriteAllText((Join-Path $logDirectory 'critique.md'), $report, [Text.UTF8Encoding]::new($false))
    [Console]::Out.WriteLine($report)
}
catch {
    [Console]::Error.WriteLine("Rubber-duck bridge failed: $($_.Exception.Message)")
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
