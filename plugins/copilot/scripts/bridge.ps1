param(
    [ValidateSet('review', 'security-review')][string]$ReviewType,
    [Alias('ClaudeSessionId')][string]$ConversationId,
    [string]$StateDirectory,
    [ValidateSet('claude', 'codex', 'cursor')][string]$AgentHost = 'claude',
    [switch]$Heredoc,
    [ValidateRange(1, 480)][int]$TimeoutSeconds = 480
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$logDirectory = $null
$metadata = $null

$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$cursorHome = Join-Path $HOME '.cursor'
if ($AgentHost -eq 'codex') {
    $hostName = 'Codex'
    $conversationField = 'codexThreadId'
    $promptCommand = '$copilot:prompt'
    $logRoot = Join-Path $codexHome 'logs/copilot'
}
elseif ($AgentHost -eq 'cursor') {
    $hostName = 'Cursor'
    $conversationField = 'cursorSessionId'
    $promptCommand = '$copilot:prompt'
    $logRoot = Join-Path $cursorHome 'logs/copilot'
}
else {
    $hostName = 'Claude'
    $conversationField = 'claudeSessionId'
    $promptCommand = '/copilot:prompt'
    $logRoot = Join-Path $HOME '.claude/logs/copilot'
}

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

function Save-SessionState($Path, $State) {
    $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporaryPath, ($State | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
        if (-not $IsWindows) {
            [IO.File]::SetUnixFileMode($temporaryPath, [IO.UnixFileMode]'UserRead,UserWrite')
        }
        [IO.File]::Move($temporaryPath, $Path, $true)
    }
    finally {
        if ([IO.File]::Exists($temporaryPath)) { [IO.File]::Delete($temporaryPath) }
    }
}

$stateLock = $null
try {
    if (-not $ReviewType) {
        if ($AgentHost -eq 'codex') {
            if (-not $ConversationId) { $ConversationId = $env:CODEX_THREAD_ID }
            if (-not $StateDirectory) { $StateDirectory = Join-Path $codexHome 'copilot' }
        }
        elseif ($AgentHost -eq 'cursor') {
            if (-not $StateDirectory) { $StateDirectory = Join-Path $cursorHome 'copilot' }
        }
        $parsedId = [guid]::Empty
        if (-not [guid]::TryParse($ConversationId, [ref]$parsedId) -or -not $StateDirectory) {
            $idName = switch ($AgentHost) {
                'codex' { 'Codex thread ID (CODEX_THREAD_ID)' }
                'cursor' { 'Cursor conversation ID (-ConversationId)' }
                default { 'Claude session ID' }
            }
            throw "A $idName and plugin data directory are required for $promptCommand."
        }
        $ConversationId = $parsedId.ToString()
    }
    elseif ($ConversationId -or $StateDirectory) {
        throw "Reviews use independent sessions; do not supply $hostName session state."
    }

    $stdin = [IO.StreamReader]::new([Console]::OpenStandardInput(), [Text.UTF8Encoding]::new($false))
    try { $request = $stdin.ReadToEnd() }
    finally { $stdin.Dispose() }
    if ($Heredoc) {
        if ($request.EndsWith("`r`n")) { $request = $request.Substring(0, $request.Length - 2) }
        elseif ($request.EndsWith("`n")) { $request = $request.Substring(0, $request.Length - 1) }
        else { throw 'The request heredoc must end with a newline.' }
    }

    $sessionAction = 'continue'
    $resumeId = $null
    $model = $null
    $modelSelectionSource = 'default'
    if (-not $ReviewType) {
        while ($true) {
            $match = [regex]::Match($request, '\A--model(?:=|[ \t]+)([A-Za-z0-9._:-]+)(?:[ \t]*\r?\n|[ \t]+)')
            if ($match.Success) {
                if ($model) { throw 'Specify --model only once.' }
                $model = $match.Groups[1].Value
                $modelSelectionSource = 'explicit option'
            }
            else {
                $match = [regex]::Match($request, '\A--new(?:[ \t]*\r?\n|[ \t]+)')
                if ($match.Success) {
                    if ($sessionAction -ne 'continue') { throw 'Choose only one session action.' }
                    $sessionAction = 'new'
                }
                else {
                    $match = [regex]::Match($request, '\A--resume(?:=|[ \t]+)([0-9a-fA-F-]+)(?:[ \t]*\r?\n|[ \t]+)')
                    if (-not $match.Success) { break }
                    if ($sessionAction -ne 'continue') { throw 'Choose only one session action.' }
                    $parsedResumeId = [guid]::Empty
                    if (-not [guid]::TryParse($match.Groups[1].Value, [ref]$parsedResumeId)) {
                        throw 'Provide a full Copilot session UUID after --resume.'
                    }
                    $resumeId = $parsedResumeId.ToString()
                    $sessionAction = 'resume'
                }
            }
            $request = $request.Substring($match.Length)
        }
    }
    if (-not $model -and -not $ReviewType) {
        $modelNames = @(
            'GPT[ -]?[0-9]+(?:\.[0-9]+)*(?:[ -](?:mini|codex|astra|sol|terra|luna))?'
            'Claude[ -](?:Opus|Sonnet|Haiku|Fable)[ -][0-9]+(?:\.[0-9]+)*(?:[ -]fast)?'
            'Gemini[ -][0-9]+(?:\.[0-9]+)*(?:[ -](?:Flash|Pro))?'
            'Grok[ -][0-9]+(?:\.[0-9]+)*'
            'Kimi[ -]K[0-9]+(?:\.[0-9]+)*(?:[ -]Code)?'
            'MAI[ -]Code[ -][0-9]+(?:\.[0-9]+)*(?:[ -]Flash)?'
        )
        $modelName = '(?<model>(?:' + ($modelNames -join '|') + '))'
        $match = [regex]::Match($request, "\A(?:use|using|with)\s+$modelName(?=\s+(?:to\b|for\b)|[\s,:])", [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $match.Success) {
            $match = [regex]::Match($request, "(?:\s|^)(?:using|with)\s+$modelName[.!]?\s*\z", [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
        if ($match.Success) {
            $model = [regex]::Replace($match.Groups['model'].Value.ToLowerInvariant(), '[ -]+', '-')
            $modelSelectionSource = 'prompt'
        }
    }
    if ([string]::IsNullOrWhiteSpace($request)) { throw 'Provide a request after the command.' }

    $tools = if ($ReviewType) {
        @(
            '--allow-tool=read',
            '--allow-tool=shell(git status),shell(git diff),shell(git log),shell(git show),shell(git rev-parse),shell(git merge-base),shell(git ls-files)',
            '--deny-tool=write', '--deny-tool=url', '--deny-tool=memory', '--deny-tool=shell(git push)'
        )
    }
    else {
        @(
            '--allow-tool=read', '--allow-tool=write', '--allow-tool=shell',
            '--deny-tool=shell(git push)', '--deny-tool=url', '--deny-tool=memory'
        )
    }

    $copilot = Resolve-Copilot
    $workingDirectory = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath((Get-Location).ProviderPath))
    $targetSessionId = $null
    $state = $null
    $statePath = $null
    if (-not $ReviewType) {
        $normalizedDirectory = if ($IsWindows) { $workingDirectory.ToUpperInvariant() } else { $workingDirectory }
        $key = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
            [Text.Encoding]::UTF8.GetBytes("$ConversationId`n$normalizedDirectory")
        )).ToLowerInvariant()
        $sessionsDirectory = Join-Path ([IO.Path]::GetFullPath($StateDirectory)) 'sessions'
        $null = New-Item -ItemType Directory -Path $sessionsDirectory -Force
        if (-not $IsWindows) {
            [IO.Directory]::SetUnixFileMode($sessionsDirectory, [IO.UnixFileMode]'UserRead,UserWrite,UserExecute')
        }
        $statePath = Join-Path $sessionsDirectory "$key.json"
        try {
            $stateLock = [IO.FileStream]::new("$statePath.lock", [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        }
        catch [IO.IOException] {
            throw "Another Copilot prompt is using this $hostName conversation and workspace; wait for it to finish."
        }
        if ([IO.File]::Exists($statePath)) {
            $state = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($statePath)) -AsHashtable
            if ($state[$conversationField] -ne $ConversationId -or
                $state.workingDirectory -ne $normalizedDirectory -or
                $state.sessionIds -isnot [array] -or
                $state.activeSessionId -notin $state.sessionIds) {
                throw 'Copilot session state is invalid or belongs to a different conversation or workspace.'
            }
        }
        else {
            $state = @{ $conversationField = $ConversationId; workingDirectory = $normalizedDirectory; activeSessionId = $null; sessionIds = @() }
        }
        if ($sessionAction -eq 'resume') {
            if ($resumeId -notin $state.sessionIds) {
                throw "Copilot session $resumeId is not recorded for this $hostName conversation and workspace."
            }
            $targetSessionId = $resumeId
        }
        elseif ($sessionAction -eq 'new' -or -not $state.activeSessionId) {
            $targetSessionId = [guid]::NewGuid().ToString()
            $sessionAction = 'new'
        }
        else {
            $targetSessionId = $state.activeSessionId
        }
    }
    $logDirectory = Join-Path $logRoot ("{0}-{1}" -f [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ'), [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $logDirectory -Force
    if (-not $IsWindows) {
        [IO.Directory]::SetUnixFileMode($logDirectory, [IO.UnixFileMode]'UserRead,UserWrite,UserExecute')
    }
    $label = if ($ReviewType) { $ReviewType } else { 'write-enabled' }
    [Console]::Error.WriteLine("Copilot CLI ($label) log: $logDirectory")

    $copilotPrompt = if ($ReviewType) {
        $reviewerName = if ($ReviewType -eq 'review') { 'code-review' } else { 'security-review' }
        "/$ReviewType Use the built-in $reviewerName subagent for this review; do not review the changes yourself. Review request: $request"
    }
    else { $request }
    $arguments = @(
        '--prompt', $copilotPrompt,
        '--output-format=json', '--stream=off',
        '--no-ask-user', '--no-auto-update', '--disable-builtin-mcps'
    ) + $tools
    if ($model) { $arguments += @('--model', $model) }
    if ($targetSessionId) {
        $arguments += if ($sessionAction -eq 'new') { @('--session-id', $targetSessionId) } else { @('--resume', $targetSessionId) }
    }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $copilot
    $info.WorkingDirectory = $workingDirectory
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

    $resultMessages = [Collections.Generic.List[string]]::new()
    $reviewMessages = [Collections.Generic.List[string]]::new()
    $reviewerAgentId = $null
    $reviewerCompleted = $false
    $reviewerModel = $null
    $reviewerModelSource = $null
    $lastParentMessage = $null
    $parentModel = $null
    $sessionExitCode = $null
    $resultSessionId = $null
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
            if ($ReviewType -and $data['agentName'] -eq $reviewerName) {
                $reviewerAgentId = $agentId
                $reviewerCompleted = $false
                $reviewerModel = $data['model']
                $reviewerModelSource = $data['modelSelectionSource']
                $reviewMessages.Clear()
            }
        }
        elseif ($type -eq 'assistant.message') {
            $content = $data['content']
            $toolRequests = $data['toolRequests']
            $hasToolRequests = $toolRequests -and @($toolRequests).Count -gt 0
            if ($content -is [string] -and $content.Trim() -and -not $hasToolRequests) {
                if (-not $agentId) {
                    $resultMessages.Add($content)
                    $lastParentMessage = $content
                }
                elseif ($ReviewType -and $agentId -eq $reviewerAgentId -and -not $reviewerCompleted) {
                    $reviewMessages.Add($content)
                }
            }
        }
        elseif ($type -eq 'subagent.completed' -and $ReviewType -and $agentId -eq $reviewerAgentId) {
            $reviewerCompleted = $true
        }
        elseif ($type -eq 'result') {
            $sessionExitCode = $event['exitCode']
            $resultSessionId = $event['sessionId']
        }
    }

    $metadata = [ordered]@{
        timestampUtc = [DateTimeOffset]::UtcNow.ToString('o')
        mode = if ($ReviewType) { 'read' } else { 'write' }
        reviewType = $ReviewType
        workingDirectory = $info.WorkingDirectory
        copilotExecutable = $copilot
        agentHost = $AgentHost
        $conversationField = $ConversationId
        sessionAction = if ($ReviewType) { 'independent' } else { $sessionAction }
        sessionId = $resultSessionId
        requestedModel = $model
        modelSelectionSource = $modelSelectionSource
        parentModel = $parentModel
        copilotExitCode = $exitCode
        sessionExitCode = $sessionExitCode
        agentsStarted = $agentsStarted
        reviewerAgentId = $reviewerAgentId
        reviewerCompleted = $reviewerCompleted
        reviewerModel = $reviewerModel
        reviewerModelSelectionSource = $reviewerModelSource
        outcome = 'failed'
        eventCounts = $eventCounts
    }

    if ($exitCode -ne 0) {
        throw "Copilot CLI exited with code $exitCode. See stderr.txt and events.jsonl."
    }
    if ($sessionExitCode -ne 0) {
        throw "Copilot session ended with exit code $sessionExitCode. See events.jsonl."
    }
    if ($ReviewType) {
        if (-not $reviewerCompleted) {
            $reason = if ($lastParentMessage) { $lastParentMessage.Trim() } else { 'No parent response was recorded.' }
            if ($reason.Length -gt 500) { $reason = $reason.Substring(0, 500) + '...' }
            throw "The built-in $ReviewType reviewer did not complete. Copilot said: $reason"
        }
        if ($reviewMessages.Count -eq 0) { throw "The built-in $ReviewType reviewer completed without a review." }
        $reviewLabel = if ($ReviewType -eq 'review') { 'code review' } else { 'security review' }
        $modelLabel = if ($reviewerModel) { $reviewerModel } else { 'not reported' }
        $report = "**Verified Copilot $reviewLabel** (read-only; reviewer model: ``$modelLabel``).`n`n" + ($reviewMessages -join "`n`n")
    }
    else {
        if ($resultMessages.Count -eq 0) { throw 'Copilot completed without a final response.' }
        if ($resultSessionId -ne $targetSessionId) { throw "Copilot returned an unexpected session ID: $resultSessionId" }
        $state.activeSessionId = $targetSessionId
        if ($targetSessionId -notin $state.sessionIds) { $state.sessionIds += $targetSessionId }
        Save-SessionState $statePath $state
        $verifiedModel = if ($parentModel) { $parentModel } else { 'not reported' }
        $report = "**Copilot CLI model:** ``$verifiedModel`` (write-enabled).`n**Copilot session:** ``$targetSessionId`` ($sessionAction).`n`n" + ($resultMessages -join "`n`n")
    }
    $metadata.outcome = 'success'
    [IO.File]::WriteAllText((Join-Path $logDirectory 'metadata.json'), ($metadata | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $logDirectory 'result.md'), $report, [Text.UTF8Encoding]::new($false))
    [Console]::Out.WriteLine($report)
}
catch {
    $label = if ($ReviewType) { $ReviewType } else { 'write-enabled' }
    [Console]::Error.WriteLine("Copilot CLI ($label) failed: $($_.Exception.Message)")
    if ($logDirectory) {
        if ($metadata) {
            $metadata.outcome = 'failed'
            [IO.File]::WriteAllText((Join-Path $logDirectory 'metadata.json'), ($metadata | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
        }
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
finally {
    if ($stateLock) { $stateLock.Dispose() }
}
