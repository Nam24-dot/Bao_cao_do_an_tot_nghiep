$ErrorActionPreference = "Stop"

$questa = "C:\questasim64_10.2c\win64\vsim.exe"
if (-not (Test-Path $questa)) {
  throw "QuestaSim 10.2c vsim.exe not found at $questa"
}

& $questa -c -do 'do {Simulation Scripts/run_isa.do}; quit -f'
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

& $questa -c -do 'do {Simulation Scripts/run_aes.do}; quit -f'
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
