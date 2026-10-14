# 在解压后的 CampusTerminal 目录运行本脚本；自动更新工程及资源路径并编译。
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$taskPython = 'C:\Users\gzx20\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (!(Test-Path -LiteralPath $taskPython)) { $taskPython = (Get-Command python -ErrorAction Stop).Source }
$taskTD = 'C:\Anlogic\TD_6.2.1_SP1_6.2.178.840\bin\td_commands_prompt.exe'
if (!(Test-Path -LiteralPath $taskTD)) { $taskTD = (Get-Command td_commands_prompt.exe -ErrorAction Stop).Source }
& $taskPython (Join-Path $projectRoot 'tools\update_project.py')
if ($LASTEXITCODE -ne 0) { throw 'Project generation failed' }
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'build') -Force | Out-Null
Push-Location $projectRoot
try {
    & $taskTD ((Join-Path $projectRoot 'build.tcl').Replace('\','/'))
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath (Join-Path $projectRoot 'build\SUCCESS'))) {
        throw 'TD build failed'
    }
    Write-Host 'BIT: build/campus_terminal.bit; copy media/MEDIA to the FAT32 TF card root.'
} finally { Pop-Location }
