param(
    [string]$Model    = "webhie/Qwen3.6-27B-int4-AutoRound-Code",
    [string]$BindHost = "0.0.0.0",
    [int]   $Port     = 8000,
    [string]$ApiKey   = "",
    [int]   $GpuMemoryUtilization = 90,
    [string]$ExtraArgs = ""
)

$vllmSrc = Join-Path $PSScriptRoot "vllm-windows"
$python   = Join-Path $vllmSrc ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    Write-Error "venv not found - run: cd vllm-windows && uv venv && VLLM_USE_PRECOMPILED=1 uv pip install -e ."
    exit 1
}

$env:PYTHONPATH = "$vllmSrc;$env:PYTHONPATH"

$dotenv = Join-Path $PSScriptRoot ".env"
if (Test-Path $dotenv) {
    Get-Content $dotenv | Where-Object { $_ -match "^\s*[^#]" } | ForEach-Object {
        $k, $v = $_ -split "=", 2
        Set-Item "env:$($k.Trim())" $v.Trim()
    }
}
$env:PATH = "$vllmSrc\.venv\Lib\site-packages\torch\lib;$env:PATH"
$env:VLLM_USE_FLASHINFER_SAMPLER = "0"

$args_list = @(
    "-m", "vllm.entrypoints.cli.main",
    "serve", $Model,
    "--host", $BindHost,
    "--port", $Port,
    "--gpu-memory-utilization", ($GpuMemoryUtilization / 100),
    "--max-model-len", 12288,
    "--max-num-seqs", 27,
    "--enforce-eager"
)

if ($ApiKey) {
    $args_list += @("--api-key", $ApiKey)
}

if ($ExtraArgs) {
    $args_list += $ExtraArgs.Split(" ")
}

Write-Host "Launching vLLM: $Model on ${BindHost}:${Port}" -ForegroundColor Cyan
& $python @args_list
