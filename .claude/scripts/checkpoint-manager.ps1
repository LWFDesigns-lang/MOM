param(
    [string]$Mode = "help",
    [string]$Label = "manual"
)

$claudeCli = $env:CLAUDE_CLI
if (-not $claudeCli) { $claudeCli = "claude" }

$checkpointDir = ".claude/data/checkpoints"
$logFile = ".claude/data/logs/context.jsonl"
$autoCounterFile = ".claude/data/checkpoints/token-counter.txt"
$maxKeep = 10
$autoTokenInterval = 50000

New-Item -ItemType Directory -Path $checkpointDir -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $autoCounterFile) -Force | Out-Null

$currentTokensRaw = (& $claudeCli /context | Select-String -Pattern '\d+' | Select-Object -First 1).Matches.Value
$currentTokens = if ($currentTokensRaw) { [int]$currentTokensRaw } else { 0 }
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")

function Log-Checkpoint {
    param($Action, $Label)
    $entry = @{
        timestamp = $timestamp
        action = $Action
        label = $Label
        tokens = $currentTokens
    } | ConvertTo-Json -Compress
    Add-Content -Path $logFile -Value $entry
}

function Get-Checkpoints {
    Get-ChildItem -Path "$checkpointDir\*.meta" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
}

switch ($Mode.ToLower()) {
    "create" {
        $safeLabel = $Label -replace '\s', '_'
        $metaPath = "$checkpointDir\$timestamp-$safeLabel.meta"
        $dataPath = "$checkpointDir\$timestamp-$safeLabel.dat"
        & $claudeCli /checkpoint "`"$Label`""
        @{"label"=$Label;"tokens"=$currentTokens;"created_at"=$timestamp} | ConvertTo-Json ^| Out-File -FilePath $metaPath -Encoding utf8
        New-Item -Path $dataPath -ItemType File -Force | Out-Null
        Log-Checkpoint "create" $Label
        Maintain-Limit
        Write-Host "Checkpoint '$Label' created (tokens: $currentTokens)."
    }
    "list" {
        Write-Host "Available checkpoints:"
        Get-Checkpoints | ForEach-Object {
            $meta = Get-Content -Path $_.FullName | ConvertFrom-Json
            Write-Host "$($meta.label) | tokens:$($meta.tokens) | created:$($meta.created_at)"
        }
    }
    "restore" {
        & $claudeCli /restore "`"$Label`""
        Log-Checkpoint "restore" $Label
        Write-Host "Restored checkpoint '$Label'."
    }
    "delete" {
        $toRemove = Get-Checkpoints | Where-Object {
            (Get-Content -Path $_.FullName) -match [regex]::Escape($Label)
        }
        foreach ($item in $toRemove) {
            $dataFile = "$checkpointDir\$($item.BaseName).dat"
            Remove-Item -Path $item.FullName -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $dataFile -Force -ErrorAction SilentlyContinue
            Log-Checkpoint "delete" $Label
            Write-Host "Deleted checkpoint matching '$Label'."
        }
    }
    "auto" {
        $counter = if (Test-Path $autoCounterFile) { [int](Get-Content $autoCounterFile) } else { 0 }
        $counter += $currentTokens
        Set-Content -Path $autoCounterFile -Value $counter
        if ($counter -ge $autoTokenInterval) {
            & $claudeCli /checkpoint "`"auto_$timestamp`""
            Set-Content -Path $autoCounterFile -Value 0
            Log-Checkpoint "auto" "auto_$timestamp"
            Write-Host "Auto checkpoint triggered at $counter tokens."
        } else {
            Write-Host "Auto counter = $counter / $autoTokenInterval tokens."
        }
    }
    default {
        Write-Host "Usage: checkpoint-manager.ps1 -Mode {create|list|restore|delete|auto} [-Label <label>]"
    }
}

function Maintain-Limit {
    $checkpoints = Get-Checkpoints
    while ($checkpoints.Count -gt $maxKeep) {
        $oldest = $checkpoints | Select-Object -Last 1
        $dataFile = "$checkpointDir\$($oldest.BaseName).dat"
        Remove-Item -Path $oldest.FullName -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $dataFile -Force -ErrorAction SilentlyContinue
        $checkpoints = Get-Checkpoints
    }
}