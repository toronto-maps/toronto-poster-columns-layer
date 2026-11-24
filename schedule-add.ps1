$taskName   = "kk-TorontoPosterColumnsLayer"
$projectDir = $PSScriptRoot
$logFile    = "$projectDir\logs\scheduler.log"

if (-not (Test-Path "$projectDir\logs")) {
    New-Item -ItemType Directory -Path "$projectDir\logs" | Out-Null
}

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"`"$projectDir\run-scheduled.cmd`" >> `"$logFile`" 2>&1`""

# Weekly is enough: the City refreshes both postering datasets semi-annually,
# so the tiles rarely change. The gap page is what actually moves week to week
# -- it diffs against live OSM. Every 16:30 slot is taken (Sun guelph-trees,
# Mon toronto-parks, Tue guelph-parks, Wed guelph-buildings, Thu
# guelph-bus-stops, Fri guelph-hydrants, Sat guelph-sidewalks), and the 19:30
# ones on Monday and Tuesday by guelph-water and guelph-gardens. Wednesday
# 19:30 is three hours after guelph-buildings starts, so no two of them drive
# tippecanoe in the same WSL instance at once.
$trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Wednesday -At "19:30"
# Retries live in run-scheduled.cmd, not here: 'update' exits 75 when it sees no
# usable link, and 70 when no Overpass mirror answered and the gap page fell back
# to cached OSM (published first). The wrapper tries either again up to twice, half
# an hour apart, and the 3-hour limit leaves room for that. RestartCount covers only
# a launch that fails; Task Scheduler never re-runs on an exit code.
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 3) -StartWhenAvailable `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 30)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force

Write-Host "Scheduled '$taskName' to run weekly on Wednesday at 19:30."
Write-Host "Log: $logFile"
