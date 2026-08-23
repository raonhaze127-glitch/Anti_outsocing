param([string]$Time = '07:30')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $root 'run-daily.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
Register-ScheduledTask -TaskName 'RealEstateSupplyDailyCards' -Action $action -Trigger $trigger -Settings $settings -Description '부동산 공급 기사 후보 수집 및 번호·링크 목록 생성' -Force
Write-Host "매일 $Time 자동 실행 작업이 등록되었습니다."
