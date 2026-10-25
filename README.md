# GitHub Download Tracker

A live dashboard of the **lifetime** release downloads across all your public GitHub repos, updated every hour by GitHub Actions. It costs nothing, and no server or PC needs to stay on.

GitHub resets a file's download count whenever you delete or re-upload a release file, for example to ship a fix. This tracker remembers every release file it has ever seen, so those downloads are never lost from your total.

**Example:** https://josiahg2502-glitch.github.io/github-download-tracker/

## Track your own account

1. Click **Use this template → Create a new repository**. Name it anything and make it **public**, because GitHub Pages is free only for public repos.
2. In the new repo, go to **Actions**, choose **Track downloads**, then click **Run workflow**. The first run takes about a minute and creates the `gh-pages` branch.
3. Go to **Settings → Pages**. Under **Branch**, pick `gh-pages` and `/ (root)`, then click **Save**.

Your dashboard will be at `https://<your-username>.github.io/<repo-name>/`. After that it updates itself every hour, and there's nothing to configure. It tracks whoever owns the repo, whether that's a user or an organization.

## What's counted

- Downloads of files attached to releases in every public, non-fork repo you own. Source-code zips aren't counted, because GitHub doesn't count them.
- Every check is saved on the `gh-pages` branch: `downloads.csv` holds lifetime totals per repo per check, and `assets.csv` holds every release file ever seen.
- Downloads of a deleted file are kept up to its last check. The tracker checks hourly, so at most about an hour of downloads on a file you replace can be lost.
- GitHub turns off scheduled workflows after 60 days with no repo activity. If updates stop, re-enable the workflow in the **Actions** tab.

## Run it locally

You need [PowerShell](https://aka.ms/powershell) and the [GitHub CLI](https://cli.github.com) signed in with `gh auth login`.

```
pwsh ./track-downloads.ps1 -User <github-username> -Dir ./site -Open
```
