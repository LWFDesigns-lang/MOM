param(
    [switch]$Manual
)

$claudeCli = $env:CLAUDE_CLI
if (-not $claudeCli) { $claudeCli = "claude" }

$autoThreshold = 180000
$scheduleLimit = 30
$operationCountFile = ".claude/data/logs/operation-count.txt"
$logFile = ".claude/data/logs/context.jsonl"

New-Item -ItemType Directory -Path (Split-Path $operationCountFile) -Force | Out-Null

if (-not (Test-Path $operationCountFile)) {
    Set-Content -Path $operationCountFile -Value "0"
}

$operationCount = [int](Get-Content $operationCountFile)
$operationCount++
Set-Content -Path $operationCountFile -Value $operationCount

$currentTokensRaw = (& $claudeCli /context 2>&1 | Select-String -Pattern '\d+' | Select-Object -First 1).Matches.Value
$currentTokens = if ($currentTokensRaw) { [int]$currentTokensRaw } else { 0 }

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

function Run-Compact {
    $before = $currentTokens
    & $claudeCli /compact | Out-Null
    Start-Sleep -Seconds 1
    $afterRaw = (& $claudeCli /context 2>&1 | Select-String -Pattern '\d+' | Select-Object -First 1).Matches.Value
    $after = if ($afterRaw) { [int]$afterRaw } else { 0 }
    $savings = $before - $after
    $ratio = if ($after -gt 0) { "{0:N2}" -f ($before / $after) } else { "N/A" }
    $entry = @{
        timestamp = $timestamp
        action = "compact"
        before = $before
        after = $after
        savings = $savings
        ratio = $ratio
    } | ConvertTo-Json -Compress
    Add-Content -Path $logFile -Value $entry
    Write-Host "Compact completed. Tokens before: $before, after: $after, saved: $savings, ratio: $ratio"
}

if ($Manual -or $currentTokens -ge $autoThreshold -or ($operationCount % $scheduleLimit) -eq 0) {
    Write-Host "Triggering context cleanup..."
    Run-Compact
} else {
    Write-Host "No cleanup needed (current tokens: $currentTokens, threshold: $autoThreshold)."
}