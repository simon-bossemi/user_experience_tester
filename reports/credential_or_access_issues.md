# Credential and Access Issues

**Report type:** Access blockers encountered during user-experience testing  
**Author:** user_experience_tester agent  
**Date:** 2026-04-03

---

## 1. BOS Semi Atlassian Confluence — TT-XLA Installation Page

| Attribute | Value |
|-----------|-------|
| **URL** | `https://bos-semi.atlassian.net/wiki/spaces/AIMultimed/pages/337346574/TT-XLA+Installation` |
| **Status** | ❌ Inaccessible — requires authenticated BOS Semi Confluence account |
| **Impact** | The primary input for the user-experience test could not be read directly |
| **Resolution** | A PDF export of the page (`AIMultimed-TT-XLA Installation-030426-023800.pdf`) was provided in `inputs/` and has been fully incorporated into the manual and script. |

### What was blocked

The GitHub Copilot agent has no mechanism to authenticate to `bos-semi.atlassian.net`.
Any attempt to fetch the page returns a redirect to the Atlassian login screen, not the
page content. This is an inherent limitation of the agent runtime: it can access public
URLs but cannot authenticate to private SaaS systems.

### What was done instead

1. The PDF export (`inputs/AIMultimed-TT-XLA Installation-030426-023800.pdf`) was read in full.
2. All 7 pages of the PDF were extracted with `pdftotext` and every step was incorporated
   into `docs/manuals/tt-xla-linux-manual.md` and `scripts/tt-xla-bootstrap.sh`.
3. The report (`reports/tt-xla-installation-report.md`) was updated to reflect the PDF as the
   resolved source.

### Remaining gaps that require internal Confluence access

The PDF export was the complete page content as of 2026-04-03. If the Confluence page has
been updated since that export, the following should be reviewed by a developer with access:

- Any new BOS-specific build flags or cmake option changes
- Any firmware update procedure specific to BOS A0 that was added after the export date
- Any internal package mirror (e.g., private PyPI or Artifactory) for `pjrt-plugin-tt` wheels

---

## 2. BOS Semi GitHub — Private Repositories

| Attribute | Value |
|-----------|-------|
| **Repositories** | `git@github.com:bos-semi/tt-mlir.git`, `git@github.com:bos-semi/tt-xla.git` |
| **Status** | ❌ Not cloneable by the agent — requires SSH key registered to a `bos-semi` org member |
| **Impact** | Source-build commands could not be run or verified in the agent sandbox |
| **Resolution** | Commands were derived from the PDF tutorial and documented verbatim in Section 7 of the manual. No live execution was possible. |

### Recommended follow-up

A developer with `bos-semi` org access should:
1. Run `scripts/tt-xla-bootstrap.sh` on a BOS A0 system and verify Steps 1–10 pass.
2. Attempt the source build in `docs/manuals/tt-xla-linux-manual.md` Section 7 (build from source)
   and update any commands that have changed in the `release/a0` branch.

---

## 3. Tenstorrent Private PyPI Index

| Attribute | Value |
|-----------|-------|
| **URL** | `https://pypi.eng.aws.tenstorrent.com/` |
| **Status** | ⚠️ Accessible from the agent at time of analysis (no authentication required) |
| **Impact** | None during analysis — pip install commands were drafted and should work |
| **Risk** | This URL is Tenstorrent's internal AWS-hosted index. It may be subject to network access controls in corporate environments (VPN, firewall allowlist). |

### Recommended follow-up

- If `pip install pjrt-plugin-tt --extra-index-url https://pypi.eng.aws.tenstorrent.com/`
  fails in a BOS build environment, the wheel can be downloaded directly from
  `https://github.com/bos-semi/tt-xla/releases` and installed locally.
- Consider mirroring the wheel to an internal Artifactory or Nexus registry to remove
  the external dependency.
