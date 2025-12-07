param (
    [string]$InputFile = "",
    [int]$Workers = 4,
    [int]$BudgetPerNiche = 2500
)

Set-StrictMode -Version Latest

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$logDir = ".claude/data/logs"
$resultDir = ".claude/data/results"
$tmpDir = ".claude/data/cache/batch_validation_tmp"
$logFile = Join-Path $logDir "batch_validation_$timestamp.log"
$reportFile = Join-Path $resultDir "batch_validation_$timestamp.json"
$failFlag = Join-Path $tmpDir "fail.flag"

New-Item -ItemType Directory -Path $logDir,$resultDir,$tmpDir -Force | Out-Null

function Log {
    param([string]$message)
    $entry = "$(Get-Date -Format o) - $message"
    $entry | Tee-Object -FilePath $logFile -Append
}

if (-not (Get-Command -Name claude -ErrorAction SilentlyContinue)) {
    Log "ERROR: claude CLI not found."
    throw "claude CLI missing"
}

if (-not (Get-Command -Name jq -ErrorAction SilentlyContinue)) {
    Log "ERROR: jq CLI not found."
    throw "jq CLI missing"
}

Log "=== Batch Validation (PowerShell) ==="
Log "Workers: $Workers"
Log "Token budget per niche: $BudgetPerNiche"

if ($InputFile) {
    if (-not (Test-Path $InputFile)) {
        Log "ERROR: Input file $InputFile missing."
        throw "Input file missing"
    }
    $niches = Get-Content $InputFile | Where-Object { $_.Trim().Length -gt 0 }
} else {
    $niches = $args
}

if ($niches.Count -eq 0) {
    Log "ERROR: No niches supplied."
    throw "No niches"
}

$jobs = @()
$resultPaths = @()

foreach ($index in 0..($niches.Count - 1)) {
    $niche = $niches[$index]
    $jobIndex = $index + 1
    while ((Get-Job -State Running).Count -ge $Workers) {
        Start-Sleep -Milliseconds 250
    }

    $payload = @{ niche = $niche } | ConvertTo-Json
    $resultPath = Join-Path $tmpDir "validation_$jobIndex.json"
    $resultPaths += $resultPath

    $jobs += Start-Job -ArgumentList $niche, $jobIndex, $resultPath, $BudgetPerNiche -ScriptBlock {
        param($niche, $jobIndex, $resultPath, $budget)

        $payload = @{ niche = $niche } | ConvertTo-Json
        $claudeResult = & claude subagent run validation-specialist `
            --input $payload --output-format json 2>&1

        $claudeResult | Out-File -Encoding utf8 -FilePath $resultPath

        $tokenUsage = 0
        try {
            $json = Get-Content $resultPath -Raw | ConvertFrom-Json
            $tokenUsage = $json.metadata.tokens -as [int]
        } catch {
            $tokenUsage = 0
        }

        if ($tokenUsage -gt $budget) {
            (New-Item -Path $using:failFlag -Force | Out-Null)
        }
    }
}

Wait-Job -Job $jobs | Out-Null

if (Test-Path $failFlag) {
    Log "One or more validations exceeded limits or failed."
    throw "Batch validation failure"
}

$results = @()
foreach ($path in $resultPaths) {
    if (Test-Path $path) {
        $content = Get-Content $path -Raw
        try {
            $results += $content | ConvertFrom-Json
        } catch {
            $results += $content
        }
    }
}

$results | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -Path $reportFile
Log "Batch report saved to $reportFile"
Log "Completed with $($results.Count) results"