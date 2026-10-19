# Package checks

Performed 2026-10-18 on the authoring host:

- All PowerShell scripts parsed using `System.Management.Automation.Language.Parser`: zero syntax errors. Python scripts compiled successfully.
- CSV contains 30 unique account names across five departments, six accounts each.
- Ticket document contains 20 numbered scenarios with proposed diagnostics, repair, verification and rollback guidance.

Live deployment is complete. All 19 domain baseline checks passed; all 20 support exercises have observed fault/repair records and are closed in osTicket with published FAQs. See [validation.md](validation.md) for the full acceptance register and T09's cache-only limitation.

The build script scans package inputs for the actual known lab passwords and private-key headers, excludes VM disks/media/secret storage, creates a file SHA-256 manifest, and verifies ZIP CRCs. Its result and final archive hash are delivered alongside the ZIP in `Build`.
