$claudeCli = $env:CLAUDE_CLI
if (-not $claudeCli) { $claudeCli = "claude" }

$stateFile = ".claude/data/logs/session-state.json"
$metricsFile = ".claude/data/logs/session-metrics.json"
$logFile = ".claude/data/logs/context.jsonl"
$baseTokens = 200000

New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

if (-not (Test-Path $stateFile)) {
    $sessionState = @{
        session_id = [guid]::NewGuid().ToString()
        start_time = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    $sessionState | ConvertTo-Json -Compress | Out-File -Encoding utf8 $stateFile
}
$sessionState = Get-Content $stateFile | ConvertFrom-Json

if (-not (Test-Path $metricsFile)) {
    $metrics = @{ skills_executed = 0; mcp_calls = 0; checkpoints = 0 }
    $metrics | ConvertTo-Json -Compress | Out-File -Encoding utf8 $metricsFile
}
$metrics = Get-Content $metricsFile | ConvertFrom-Json

while ($args.Count -gt 0) {
    switch ($args[0]) {
        "--skill" { $metrics.skills_executed++ }
        "--mcp" { $metrics.mcp_calls++ }
        "--checkpoint" { $metrics.checkpoints++ }
        default { Write-Host "Unknown flag: $($args[0])" }
    }
    $args = $args[1..($args.Count - 1)]
}

$metrics | ConvertTo-Json -Compress | Out-File -Encoding utf8 $metricsFile

$currentTokensRaw = (& $claudeCli /context 2>&1 | Select-String -Pattern '\d+' | Select-Object -First 1).Matches.Value
$currentTokens = if ($currentTokensRaw) { [int]$currentTokensRaw } else { 0 }

$startTime = [DateTime]::Parse($sessionState.start_time)
$elapsed = (Get-Date).ToUniversalTime() - $startTime
$elapsedMinutes = [math]::Max(1, [math]::Floor($elapsed.TotalMinutes))

$tokenRate = [math]::Floor($currentTokens / $elapsedMinutes)
$remainingTokens = [math]::Max(0, $baseTokens - $currentTokens)
$timeToLimit = if ($tokenRate -gt 0) { [math]::Floor($remainingTokens / $tokenRate) } else { 0 }

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "Session ID: $($sessionState.session_id)"
Write-Host "Start Time: $($sessionState.start_time) (UTC)"
Write-Host "Elapsed: $($elapsed.TotalSeconds) seconds (~$elapsedMinutes minutes)"
Write-Host "Current Tokens: $currentTokens"
Write-Host "Token Rate: $tokenRate tokens/minute"
Write-Host "Predicted Time to Limit: $timeToLimit minutes"
Write-Host "Skills Executed: $($metrics.skills_executed)"
Write-Host "MCP Calls: $($metrics.mcp_calls)"
Write-Host "Checkpoints Created: $($metrics.checkpoints)"

$logEntry = @{
    timestamp = $timestamp
    session_id = $sessionState.session_id
    start_time = $sessionState.start_time
    current_tokens = $currentTokens
    token_rate = $tokenRate
    time_to_limit_minutes = $timeToLimit
    skills_executed = $metrics.skills_executed
    mcp_calls = $metrics.mcp_calls
    checkpoints = $metrics.checkpoints
} | ConvertTo-Json -Compress

Add-Content -Path $logFile -Value $logEntry