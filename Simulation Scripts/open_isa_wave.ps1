$ErrorActionPreference = "Stop"

$questa = "C:\questasim64_10.2c\win64\vsim.exe"
if (-not (Test-Path $questa)) {
  throw "QuestaSim 10.2c vsim.exe not found at $questa"
}

& $questa -do 'do {Simulation Scripts/wave_cpu_isa.do}'
