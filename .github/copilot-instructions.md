# Repository instructions for Copilot

When working in this repository:

- Put human-readable manuals in `docs/manuals/`
- Put runnable scripts in `scripts/`
- Put execution reports and gap analyses in `reports/`
- Prefer bash scripts for Linux automation
- Every bootstrap script must:
  - use `set -euo pipefail`
  - print clear progress messages
  - check required tools before use
  - detect Ubuntu/Debian when possible
  - explain unsupported environments clearly
- Every manual must include:
  - prerequisites
  - exact commands
  - expected outputs
  - troubleshooting
  - replay checklist
- If external tutorial steps are incomplete or ambiguous, document the gaps explicitly in the report
