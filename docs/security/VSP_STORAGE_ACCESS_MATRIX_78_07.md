# VSP — 78.07 Storage/file permissions matrix

Date: 2026-11-11. **Documented policy matrix and evidence scope**; not a claim of complete storage audit, real file-upload E2E, or proof that all buckets are safe. Extends [role access matrix](VSP_ROLE_ACCESS_MATRIX_78_03.md).

## Sensitive buckets and intended actor permissions

| Bucket or resource | Anonymous | Player | Owner | Active admin/founder | Service role | Evidence and caveat |
|---|---|---|---|---|---|---|
| `owner_documents` | Deny | Deny unrelated documents | Own scoped path/record only | Scoped privileged read/manage | Server-only | Private bucket readback; `owner_documents_owner_manage`, `Owner access own documents or Admin`, `secure_owner_docs_read` |
| `deposit-receipts` | Deny | Own receipt only where policy permits | Related stadium/booking only where policy permits | Scoped privileged read | Server-only | Private bucket flag; `secure_deposit_receipts_read`; actual participant joins require per-policy review |
| `verification-documents` | Deny | Deny unless explicitly approved | Own verification record where policy permits | Scoped privileged review | Server-only | Private bucket flag; exact storage object policies not comprehensively established by the batch-10 evidence |
| Stadium images | Public read only when specifically designated public | No unrelated writes | Own stadium image update/delete only | Scoped privileged maintenance | Server-only | `Owner delete own stadium images`, `Owner update own stadium images`; public read and upload policies not fully audited here |
| Banner images | Public read only if intended | No privileged writes | No privileged writes | Upload/modify/delete | Server-only | `Admin Upload Access for Banner Images`, `Admin Modify Access for Banner Images`, `Admin Delete Access for Banner Images` |

**Critical distinction:** the entries above are **intended access boundaries**. A bucket's private flag does not prove that every SQL storage.objects policy, signed URL, download path or Edge Function is safe. A named policy is evidence of its existence, not complete proof of its effective OR-composed permissions.

## Grounded production/staging evidence

- [Batch-10 readback evidence](STORE_COMPLIANCE_BATCH_10_EVIDENCE_2026-11-11.json) records nine production `storage.objects` policies matching their reviewed post-hardening definitions and metadata.
- [Batch-10 receipt](STORE_COMPLIANCE_BATCH_10_2026-11-11.md) records 37 reviewed policy corrections across public and storage, including **nine storage policies**; staging has eight target policies absent and one reviewed guarded alternate preserved. Do **not** interpret production/staging as identical.
- Production flags for `owner_documents`, `deposit-receipts`, and `verification-documents` were read back as private. The staging synthetic checks verified an unrelated owner could not see another owner's storage metadata, while own-profile/file and authorized founder paths remained available.
- The receipt explicitly says no real storage upload/download, GoTrue session, production customer-row probe, or full storage inventory was tested. No new grants, migrations, uploads, or data mutations were made for this matrix.

## Verification still required (not accepted under 78.07)

1. Enumerate **all** buckets and effective storage.objects policies across staging and production; inspect every permissive policy composition and upload path.
2. Real signed-in two-account tests: owner A upload/read/delete own object, owner B cannot read/write it, blocked admin cannot use privileged branch, active authorized admin retains expected scoped access.
3. Confirm public stadium/banner asset visibility and no private signed-URL leakage.
4. Confirm private receipt/document access is bound to the actual booking/owner relationship; audit service-role Edge Functions and object path sanitization.
5. Capture results under **78.04**, **79.02**, **79.03**, **79.06** and security hardening tasks as applicable.

**78.07 acceptance meaning:** storage and file authorization are now explicitly represented in the role matrix with evidence, known policy names and unresolved gaps. This closes **matrix coverage**, not storage security verification.
