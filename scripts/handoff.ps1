<#
.SYNOPSIS
  HANDOFF move of the dependency-hygiene loop (Windows / PowerShell).

  Creates or tears down a dedicated git worktree per finding so parallel bump
  attempts never collide on package.json / package-lock.json. Each finding gets
  its own branch `fix/<slug>` checked out in its own directory.

.PARAMETER Action
  create   - add a worktree + branch fix/<slug>
  teardown - remove the worktree and delete the branch

.PARAMETER Slug
  The finding slug, e.g. lodash-4.17.15-to-4.17.21

.EXAMPLE
  ./scripts/handoff.ps1 -Action create   -Slug lodash-4.17.15-to-4.17.21
  ./scripts/handoff.ps1 -Action teardown -Slug lodash-4.17.15-to-4.17.21
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('create', 'teardown')][string]$Action,
  [Parameter(Mandatory = $true)][string]$Slug
)

$ErrorActionPreference = 'Stop'

# Repo root is the parent of this scripts/ directory.
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Worktrees live OUTSIDE the working tree (a sibling dir) so they can never be
# accidentally committed into the repo they are bumping.
$WorktreesRoot = Join-Path (Split-Path $RepoRoot -Parent) 'dep-hygiene-loop-worktrees'
$WorktreePath  = Join-Path $WorktreesRoot $Slug
$Branch        = "fix/$Slug"

Push-Location $RepoRoot
try {
  if ($Action -eq 'create') {
    if (-not (Test-Path $WorktreesRoot)) {
      New-Item -ItemType Directory -Path $WorktreesRoot | Out-Null
    }
    Write-Host "Creating worktree '$WorktreePath' on branch '$Branch'..."
    git worktree add -b $Branch $WorktreePath HEAD
    Write-Host "Worktree ready. Apply the bump INSIDE: $WorktreePath"
    Write-Host "goal=all tests pass and lint is clean, advisory resolved for this package"
  }
  else {
    Write-Host "Tearing down worktree '$WorktreePath' and branch '$Branch'..."
    if (Test-Path $WorktreePath) {
      git worktree remove $WorktreePath --force
    }
    git worktree prune
    # Delete the branch if it exists (ignore failure if already gone).
    git branch -D $Branch 2>$null
    Write-Host "Teardown complete."
  }
}
finally {
  Pop-Location
}
