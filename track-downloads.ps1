# Logs lifetime release download counts for every public repo a user owns to downloads.csv (one row per repo per run).
# GitHub resets a count when a release file is deleted/re-uploaded, so assets.csv remembers every file ever seen:
# deleted files keep their last count, and a count that drops is banked before counting again.
# Also writes index.html (the dashboard). In GitHub Actions the user is the repo owner and -Dir is the gh-pages checkout.
# Locally: pwsh -File track-downloads.ps1 -User <name> -Dir <folder> [-Open]   (needs gh auth login)
param([string]$User = $env:GITHUB_REPOSITORY_OWNER, [string]$Dir = $PSScriptRoot, [switch]$Open)
if (-not $User) { throw "Pass -User <github username>" }
$null = New-Item -ItemType Directory -Force $Dir

$csv = Join-Path $Dir "downloads.csv"
$assetsCsv = Join-Path $Dir "assets.csv"
# UTC so every viewer's browser shows their own local time
$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm'Z'")
$prev = @{}
if (Test-Path $csv) { Import-Csv $csv | ForEach-Object { $prev[$_.repo] = [int]$_.downloads } }
$seen = @{}
if (Test-Path $assetsCsv) {
    Import-Csv $assetsCsv | ForEach-Object { $_.last = [int]$_.last; $_.banked = [int]$_.banked; $seen[$_.id] = $_ }
}

# --slurp merges paginated pages into one array of pages
$repos = (gh api "users/$User/repos?per_page=100" --paginate --slurp | ConvertFrom-Json) | ForEach-Object { $_ } |
    Where-Object { -not $_.fork }
if ($LASTEXITCODE -ne 0) { throw "gh api failed; check 'gh auth status'" }

foreach ($r in $repos) {
    $releases = (gh api "repos/$($r.full_name)/releases?per_page=100" --paginate --slurp | ConvertFrom-Json) | ForEach-Object { $_ }
    if ($LASTEXITCODE -ne 0) { throw "gh api failed for $($r.full_name); nothing saved" }
    foreach ($rel in $releases) {
        foreach ($a in $rel.assets) {
            $e = $seen["$($a.id)"]
            if (-not $e) {
                $seen["$($a.id)"] = [pscustomobject]@{ id = "$($a.id)"; repo = $r.name; release = $rel.tag_name; name = $a.name; last = [int]$a.download_count; banked = 0 }
                continue
            }
            if ($a.download_count -lt $e.last) { $e.banked += $e.last }
            $e.last = [int]$a.download_count
        }
    }
}

$rows = foreach ($r in $repos) {
    $total = ($seen.Values | Where-Object repo -eq $r.name | ForEach-Object { $_.banked + $_.last } | Measure-Object -Sum).Sum
    if (-not $total) { $total = 0 }
    [pscustomobject]@{ time = $now; repo = $r.name; downloads = [int]$total; change = [int]$total - [int]$prev[$r.name] }
}

$seen.Values | Sort-Object repo, release, name | Export-Csv $assetsCsv -NoTypeInformation
$rows | Export-Csv $csv -Append -NoTypeInformation

$json = ConvertTo-Json -Compress -InputObject @(Import-Csv $csv | Select-Object time, repo, downloads)
$assetsJson = ConvertTo-Json -Compress -InputObject @(Import-Csv $assetsCsv | Select-Object repo, release, name, last, banked)
$html = (Get-Content (Join-Path $PSScriptRoot "dashboard.template.html") -Raw -Encoding UTF8).
    Replace("__DATA__", $json).Replace("__ASSETS__", $assetsJson).Replace("__USER__", $User)
$dash = Join-Path $Dir "index.html"
[IO.File]::WriteAllText($dash, $html)
if ($Open) { Start-Process $dash }
$released = $seen.Values.repo
$rows | Where-Object { $_.repo -in $released } | Sort-Object downloads -Descending | Format-Table repo, downloads, change -AutoSize
"TOTAL: {0} lifetime downloads ({1:+#;-#;0} since last run)" -f ($rows | Measure-Object downloads -Sum).Sum, ($rows | Measure-Object change -Sum).Sum
