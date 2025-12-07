param (
    [string]$LogDir = ".claude/data/logs",
    [string]$ResultsDir = ".claude/data/results"
)

# Daily niche discovery workflow (headless PowerShell variant)
# Compatible with scheduled tasks or Task Scheduler.
Set-StrictMode -Version Latest

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$logFile = Join-Path $LogDir "workflow_$timestamp.log"
$resultsFile = Join-Path $ResultsDir "niches_$timestamp.json"
$null = New-Item -ItemType Directory -Path $LogDir,$ResultsDir -Force

function Write-Log {
    param([string]$message)
    $line = "$(Get-Date -Format o) - $message"
    $line | Tee-Object -FilePath $logFile -Append
}

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Log "ERROR: claude CLI not found in PATH."
    throw "claude CLI missing"
}

Write-Log "=== Daily Niche Discovery (PowerShell) ==="
Write-Log "Token budget target: 3-5 niches @ 2-3K tokens each"

$prompt = @'
Validate five trending POD niches with the pod-research skill. Use fresh context for each, gather Etsy count + Google Trends data via MCP (data-etsy + data-trends), and call logic-validator. Output a JSON array with one result per niche. Niches:
1. sustainable home decor
2. minimalist pet accessories
3. retro gaming nostalgia
4. tactile journal stationery
5. plant-inspired fitness gear

For each niche:
1. Fetch Etsy listings with data-etsy.
2. Fetch 12-month trend stability with data-trends.
3. Run logic-validator.validate_niche.
4. Return the structured decision (GO/SKIP, confidence, etsy_count, trend_score, reasoning).
Do not include markdown or explanation. Output only JSON array.
'@

try {
    Write-Log "Invoking Claude Code headless session"
    & claude -p $prompt --output-format json 2>> $logFile | Set-Content -Path $resultsFile -Encoding UTF8
    Write-Log "Results saved to $resultsFile"
} catch {
    Write-Log "Claude invocation failed: $($_.Exception.Message)"
    throw
}

$goCount = (Select-String -Path $resultsFile -Pattern '"decision": "GO"' -SimpleMatch).Count
Write-Log "GO decisions: $goCount"
Write-Log "Completed at $(Get-Date -Format o)"