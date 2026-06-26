<#
.SYNOPSIS
  SCHEDULING move — Windows local fallback.

  Registers a Windows Task Scheduler job that runs the SAME `dep-triage` skill
  every day at 06:00, mirroring the cloud cron in .github/workflows/dep-triage.yml.

  NOTE: a local scheduler only turns while THIS MACHINE STAYS ON. If the laptop
  is asleep or powered off at 06:00, the job does not fire (Task Scheduler can be
  told to run on next wake with -StartWhenAvailable, but it still cannot run on a
  powered-off box). The GitHub Actions cron is the one that turns even when your
  machine is off — this is the belt-and-suspenders local copy.

.PARAMETER Unregister
  Remove the scheduled task instead of creating it.

.EXAMPLE
  ./scripts/register-task.ps1                # register the 06:00 daily job
  ./scripts/register-task.ps1 -Unregister    # remove it
#>
[CmdletBinding()]
param(
  [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$TaskName = 'dep-hygiene-loop-triage'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ($Unregister) {
  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed scheduled task '$TaskName'."
  }
  else {
    Write-Host "No scheduled task '$TaskName' found."
  }
  return
}

# The action: cd into the repo and run Claude Code headless, invoking the
# dep-triage skill. Headless print mode (-p) runs one pass and exits — exactly
# one turn of the loop. Adjust the `claude` invocation to your install if needed.
$Command = "Set-Location -LiteralPath '$RepoRoot'; claude -p '/dep-triage'"

$Action = New-ScheduledTaskAction `
  -Execute 'powershell.exe' `
  -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$Command`""

# 06:00 daily — same wall-clock time as the cloud cron (0 6 * * *).
$Trigger = New-ScheduledTaskTrigger -Daily -At 6:00am

# StartWhenAvailable lets a missed run (machine asleep) fire on next wake. It
# still cannot run while the machine is fully powered off — see the note above.
$Settings = New-ScheduledTaskSettingsSet `
  -StartWhenAvailable `
  -DontStopOnIdleEnd `
  -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $Action `
  -Trigger $Trigger `
  -Settings $Settings `
  -Description 'dep-hygiene-loop: daily dependency triage (local fallback for the GitHub Actions cron).' `
  -Force | Out-Null

Write-Host "Registered scheduled task '$TaskName' — runs daily at 06:00."
Write-Host "Reminder: the local scheduler only turns while this machine is on."
