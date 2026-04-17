# bos-sdk_user_experience_tester

User-experience testing for the BOS A0 (Tenstorrent Blackhole) TT-XLA development environment.
This repository documents the full installation workflow from hardware setup through running a
ResNet50 inference on a BOS A0 card.

---

## Target hardware

**BOS A0 — Tenstorrent Blackhole** (p100a / p150a / p150b)

The primary source for this workflow is the BOS internal tutorial
(`AIMultimed-TT-XLA Installation-030426-023800.pdf`) provided in `inputs/`, combined with the
public Tenstorrent getting-started documentation.

---

## Generated artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| **Manual** | [`docs/manuals/tt-xla-linux-manual.md`](docs/manuals/tt-xla-linux-manual.md) | Step-by-step guide for beginners: hardware setup, driver install, wheel install, Docker, build-from-source, ResNet50 demo |
| **Bootstrap script** | [`scripts/tt-xla-bootstrap.sh`](scripts/tt-xla-bootstrap.sh) | One-command automated install + ResNet50 demo on BOS A0; idempotent (safe to re-run) |
| **Installation report** | [`reports/tt-xla-installation-report.md`](reports/tt-xla-installation-report.md) | Gap analysis, PDF findings, assumptions, blockers, environment matrix |
| **Access issues** | [`reports/credential_or_access_issues.md`](reports/credential_or_access_issues.md) | Documents credentials/access that blocked the agent and their resolutions |
| **Input PDF** | [`inputs/AIMultimed-TT-XLA Installation-030426-023800.pdf`](inputs/AIMultimed-TT-XLA%20Installation-030426-023800.pdf) | BOS internal TT-XLA installation guide (source document) |

---

## Supported workflows

### Option A — Wheel install (fastest, recommended)

```bash
# 1. Complete BOS A0 hardware + BIOS setup (Section 3 of the manual)
# 2. Run TT-Installer to set up driver and hugepages (Section 4)
# 3. Run the bootstrap script:
chmod +x scripts/tt-xla-bootstrap.sh
./scripts/tt-xla-bootstrap.sh
```

The script is **idempotent**: re-running it skips steps that are already complete.

### Option B — Docker (BOS A0)

See `docs/manuals/tt-xla-linux-manual.md` Section 6 for the full `docker run` command
using `ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest` and the BOS A0 device
path `/dev/bos/<id>`.

### Option C — Build from source (BOS A0)

See `docs/manuals/tt-xla-linux-manual.md` Section 7 for:
- GitHub SSH setup for the `bos-semi` private repositories
- TT-MLIR toolchain build (`cmake env/build`)
- TT-XLA BOS A0 cmake flags (`-DUSE_BOS_SEMI_TTMLIR=ON`, `-DUSE_BOS_REPO=ON`, etc.)
- Known `core_assignment.cpp` build workaround

---

## Quick reference

```bash
# Verify BOS A0 hardware is present:
lspci -d 1e52:
ls /dev/bos/

# Check hugepages (set by TT-Installer):
grep HugePages_Total /proc/meminfo

# Run ResNet50 on BOS A0 (after wheel install):
source ~/.tt-xla-venv/bin/activate
python run_resnet50_tt.py
```

NOTE: the user_experience_tester can use the access to claude_pm_assistant for jira, confluence, git, outlook,  one drive sharepoints and also do some diagramms in .drawio format

General PM_ASSISTANT AGENT RULES:
# PM Assistant Knowledge Rules

When answering user questions, PM Assistant should use the following data sources as the primary internal knowledge base, in this order when relevant:

## 1. SharePoint content available through local OneDrive sync

Search all locally available SharePoint shortcuts and synced folders in the user's OneDrive, especially:

- `C:\Users\SimonJacqmart\OneDrive - 보스반도체\SW개발팀 - Documents`
- `C:\Users\SimonJacqmart\OneDrive - 보스반도체\PM_SE 팀 - Documents`
- `C:\Users\SimonJacqmart\OneDrive - 보스반도체\SoC Solution Team - Documents`
-  `C:\Users\SimonJacqmart\OneDrive - 보스반도체\SOC Architecture 팀 - Documents`

Rules:

- Prefer direct filesystem search over browser-based SharePoint access.
- Search filenames first, then inspect file contents where possible.
- Treat these synced folders as the main SharePoint database for PM Assistant.

## 2. Confluence

Use the configured Confluence crawler and crawl/search across every accessible Confluence space and page under:

- `https://bos-semi.atlassian.net/wiki`

Rules:

- Use `C:\Agents\pm_assistant\tools\confluence_crawler\confluence_crawler.py`
- Use `C:\Agents\pm_assistant\scripts\crawl_confluence.ps1`
- Refresh the local crawl when needed before answering questions that depend on Confluence content.

## 3. Jira

Use the configured Jira search tools to inspect the Jira projects and tickets the user can access under:

- `https://bos-semi.atlassian.net/jira/for-you`

Rules:

- Use `C:\Agents\pm_assistant\tools\jira_search\jira_search.py`
- Use `C:\Agents\pm_assistant\scripts\list_jira_projects.ps1` to discover accessible Jira projects
- Use `C:\Agents\pm_assistant\scripts\search_jira.ps1` to search accessible Jira tickets
- Prefer live Jira queries when the answer may have changed recently

## Answering behavior

- For technical or project questions, combine evidence from SharePoint, Confluence, and Jira whenever useful.
- If one source is incomplete, continue searching the others before answering.
- If SharePoint content exists locally, prefer that over attempting browser-authenticated SharePoint access.
- If Jira or Confluence access fails, say so clearly and continue with the remaining available sources.


# Confluence Crawler

This is the PM Assistant copy of the Confluence crawler used in `review_engineer`.

## Config

The crawler is already configured for:

- `https://bos-semi.atlassian.net/wiki`
- Atlassian account `simon.jacqmart@bos-semi.com`
- output root `C:\Agents\pm_assistant\wiki`

Credentials are stored in `tools\confluence_crawler\.env`.

## Run

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\crawl_confluence.ps1
```

Optional filters:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\crawl_confluence.ps1 -SpaceKey ENG -MaxPages 50
```

Single page:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\crawl_confluence.ps1 -PageId 123456789
```

# Jira Search

This toolset lets PM Assistant query Jira projects and tickets available to the configured Atlassian account.

Base URL:

- `https://bos-semi.atlassian.net`

## List accessible projects

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\list_jira_projects.ps1
```

## Search issues

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_jira.ps1 -Jql "text ~ \"Tenstorrent\" order by updated DESC"
```

## Read one ticket in detail

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\get_jira_issue.ps1 -Key PTTM-158
```

## Create a ticket

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\create_jira_issue.ps1 -ProjectKey PTTM -IssueType Task -Summary "Example ticket" -Description "Created by PM Assistant"
```

Examples:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_jira.ps1 -Jql "assignee = currentUser() order by updated DESC"
powershell -ExecutionPolicy Bypass -File .\scripts\search_jira.ps1 -Jql "project = BOS AND statusCategory != Done order by updated DESC" -MaxResults 25
```

Output is written under `C:\Agents\pm_assistant\jira`.

# SharePoint Search

This toolset lets PM Assistant search SharePoint sites and documents under:

- `https://bossemi.sharepoint.com/_layouts/15/sharepoint.aspx`

It signs in with Microsoft Graph delegated permissions and scopes searches to the `bossemi.sharepoint.com` tenant.

## One-time setup

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup_sharepoint_search.ps1
```

## Sign in

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\connect_sharepoint_search.ps1
```

The script uses device-code sign-in and requests:

- `Sites.Read.All`
- `Files.Read.All`

## Search

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_sharepoint.ps1 -Query "NPU compiler"
```

Examples:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_sharepoint.ps1 -Query "tensor layout"
powershell -ExecutionPolicy Bypass -File .\scripts\search_sharepoint.ps1 -Query "manual" -EntityType driveItem
powershell -ExecutionPolicy Bypass -File .\scripts\search_sharepoint.ps1 -Query "platform" -EntityType site -Top 20
```

Output is saved under `C:\Agents\pm_assistant\sharepoint_search`.

## List a shared folder directly

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\list_sharepoint_folder.ps1 -ShareUrl "https://bossemi.sharepoint.com/:f:/s/PMSE/IgA8TwLDzkRtSayUAD-ydhf4AT1eqPyZa7DnG9g9q-zK5Ew?e=6Q1wGo"
```

This uses Microsoft sign-in and saves a JSON and Markdown listing for that exact shared folder link.

# Git

Access, pull
https://github.com/bos-semi
https://github.com/bos-semi-release

Access, modify, pull, push, commit
https://github.com/simon-bossemi?tab=repositories
https://github.com/simon-bossemi/user_experience_tester
https://github.com/simon-bossemi/linux_tester

# Reporting style
When asked to generate a report, use the HTML and the style of reports
in C:\Users\SimonJacqmart\.claude\agents\reporting_style
as well as the colors used in http://192.128.10.230/bos-sdk/

# Reports location
When generating a report, create a new folder in C:\Users\SimonJacqmart\OneDrive - 보스반도체\PM_SE 팀 - Documents\Reports or use an exisitng foler if report update, include the htm file and related images in the sharepoint. For the ppictures, imagesLink the the sharepoint address in the html file.

# Diagrams
create required diagrams as .drawio files and include screenshots, exports in the reports