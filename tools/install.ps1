# Downloads the .ipa from the latest successful `ios` workflow run on main (PLAN.md §2.1)
# into build\ and prints the Sideloadly step. Needs the GitHub CLI, signed in.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $repoRoot 'build'
$ipaPath = Join-Path $buildDir 'OutlawDuels.ipa'

Push-Location $repoRoot
try {
    $runJson = gh run list --workflow ios.yml --branch main --status success --limit 1 --json databaseId,headSha,createdAt
    if ($LASTEXITCODE -ne 0) { throw 'gh run list failed. Is gh installed and signed in?' }
    $run = $runJson | ConvertFrom-Json | Select-Object -First 1
    if ($null -eq $run) { throw 'No successful ios run on main yet.' }

    New-Item -ItemType Directory -Force $buildDir | Out-Null
    if (Test-Path $ipaPath) { Remove-Item $ipaPath -Confirm:$false }

    gh run download $run.databaseId --name OutlawDuels-ipa --dir $buildDir
    if ($LASTEXITCODE -ne 0) { throw "gh run download failed for run $($run.databaseId)." }
    if (-not (Test-Path $ipaPath)) { throw "Artifact downloaded but $ipaPath is missing." }

    $sizeMb = [math]::Round((Get-Item $ipaPath).Length / 1MB, 1)
    Write-Host "Run $($run.databaseId), commit $($run.headSha.Substring(0, 7)), built $($run.createdAt)"
    Write-Host "Saved $ipaPath ($sizeMb MB)"
    Write-Host ''
    Write-Host 'Next: plug in the iPhone, open Sideloadly, drag that .ipa in, enter your Apple ID, press Start.'
}
finally {
    Pop-Location
}
