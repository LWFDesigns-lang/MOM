$claudeCli = $env:CLAUDE_CLI
if (-not $claudeCli) { $claudeCli = "claude" }

$logFile = ".claude/data/logs/context.jsonl"
$baseTokens = 200000
$microcompactThreshold = 180000
$greenThreshold = 150000
$avgSkillCost = 2500

if (-not (Test-Path $logFile)) {
    New-Item -ItemType File -Path $logFile | Out-Null
}

$contextOutput = & $claudeCli /context 2>&1
$currentTokens = [int]($contextOutput -match '\d+' | Select-Object -First 1)
if (-not $currentTokens) { $currentTokens = 0 }

$percentUsed = [math]::Floor(($currentTokens * 100) / $baseTokens)
$remainingTokens = [math]::Max(0, $baseTokens - $currentTokens)
$operationsRemaining = [math]::Floor($remainingTokens / $avgSkillCost)
$operationHistory = [math]::Floor($currentTokens / $avgSkillCost)

$warningColor = ""
$message = "Context healthy. Continue skill chains."
$recommendedAction = "Maintain workflow and watch budgets."

if ($currentTokens -ge $microcompactThreshold) {
    $warningColor = "`e[1;31m"
    $message = "Microcompact recommended immediately."
    $recommendedAction = "Run /compact or rely on automatic microcompact."
} elseif ($currentTokens -ge $greenThreshold) {
    $warningColor = "`e[1;33m"
    $message = "Context approaching 180K. Consider checkpoint + microcompact."
    $recommendedAction = "Create checkpoint, plan for /compact soon."
} else {
    $warningColor = "`e[1;32m"
}

$resetColor = "`e[0m"

Write-Host "$warningColorCLAUDE /context snapshot$resetColor"
Write-Host "Tokens used: $currentTokens/$baseTokens ($percentUsed`%)"
Write-Host "Estimated skill chains consumed: ~$operationHistory"
Write-Host "Estimated remaining chains: ~$operationsRemaining"
Write-Host $message
Write-Host "Recommended action: $recommendedAction"
Write-Host "Efficiency metric: $percentUsed% of $baseTokens window used."

$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$logEntry = @{
    timestamp = $timestamp
    type = "context_snapshot"
    tokens_used = $currentTokens
    percent_used = $percentUsed
    remaining_tokens = $remainingTokens
    operation_history = $operationHistory
    operations_remaining = $operationsRemaining
    recommended_action = $recommendedAction
} | ConvertTo-Json -Compress

Add-Content -Path $logFile -Value $logEntry

if ($currentTokens -ge $microcompactThreshold) {
    Write-Host "`e[1;31m⚠ Microcompact trigger reached. Run /compact or await automatic microcompact.`e[0m"
}