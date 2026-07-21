# Research: Self-Contained Raycast EPUB Workflow

**Date**: 2026-07-20  
**Scope**: Resolve the runtime, dependency, security, interaction, delivery, testing, and migration choices required by [spec.md](./spec.md).

## 1. Raycast Runtime and Package Baseline

**Decision**: Build one macOS-only npm package using TypeScript 6.0.x, React 19 as provided by the Raycast toolchain, and `@raycast/api` 1.104.x or its compatible implementation-time update. Set `engines.node` to `>=22.22.2 <23`, matching the current Raycast API package requirement, and commit `package-lock.json`.

**Rationale**: The Raycast manifest is the package manifest, its CLI builds and publishes the extension, and the current `@raycast/api@1.104.23` declares Node `>=22.22.2`. The current Raycast ESLint configuration accepts TypeScript `<6.1`, so TypeScript 6.0.x is the newest compatible line without bypassing official lint constraints. Restricting the package to macOS reflects Finder integration and the product specification.

**Alternatives considered**:

- Node 24: rejected because it exceeds the current Raycast API package's declared baseline and adds no product value.
- TypeScript 7: rejected because the current Raycast ESLint peer range excludes it.
- A nested package or monorepo: rejected by the constitution and unnecessary for three commands.
- Electron, Tauri, Swift, Python, Java, or native addons: prohibited by the product boundary.

## 2. Command Surface and File Intake

**Decision**: Expose exactly one `view` command, `Send Book to Kindle`. It first calls `getSelectedFinderItems()`, validates a stable EPUB/PDF snapshot, and renders a multi-select `Form.FilePicker` fallback when Finder is unavailable or yields no supported file. EPUB inspection and repair are internal stages.

**Rationale**: `getSelectedFinderItems()` is the official Finder-selection API but can reject when Finder is not frontmost. `Form.FilePicker` is the native multi-file fallback; it does not provide a documented EPUB type filter, so extension and regular-file validation must occur after selection. Revalidation at submit time handles files removed or changed after picking.

**Alternatives considered**:

- AppleScript or `NSOpenPanel`: rejected as an unnecessary helper-process/platform workaround.
- Text fields for paths: rejected for usability and accessibility.
- Separate intake logic in each command: rejected because inconsistent validation would violate the shared product contract.

## 3. Native Raycast Interaction

**Decision**: Use `List` with detail previews for batch state, `Detail` for full reports/plans/confirmation, `Form` for fallback selection, and `ActionPanel` native actions. Use `isLoading`, animated toasts, progress icons, phase labels, and an explicit cancel action backed by one `AbortController` per operation.

**Rationale**: These are native, keyboard-first Raycast patterns and avoid reproducing a desktop application. Raycast has no universal percentage-progress API; progress must reflect known phases or entries rather than guessed elapsed time. Cancel UI only requests cancellation, so application and adapter checkpoints must observe the signal.

**Alternatives considered**:

- A custom dashboard or settings screen: rejected as desktop-app imitation.
- Time-derived progress percentages: rejected as misleading.
- Assuming component unmount hard-cancels work: rejected because streams and network operations require explicit teardown.

## 4. ZIP Reader and Writer

**Decision**: Use `yauzl` for lazy central-directory inspection and one-entry-at-a-time reads, and `yazl` for ordered streaming reconstruction. Add direct CRC verification and actual-byte counters around streams. Do not extract the archive to a directory.

**Rationale**: The pair is small, pure JavaScript, uses Node streams and built-in zlib, exposes declared compressed and expanded sizes before content reads, preserves explicit addition order, supports STORE for `mimetype`, and avoids materializing a 200 MB archive or 1 GB expanded corpus in memory. Direct stream counters defend against false metadata; CRC checks detect corruption not covered by size validation.

**Alternatives considered**:

- `@zip.js/zip.js`: capable and stricter in some areas, but larger and includes worker/WASM paths that increase bundling and Store-review risk.
- `fflate`: compact, but central-directory preflight and ZIP64 handling are less suitable for hostile inputs.
- JSZip or `adm-zip`: rejected because common APIs load the archive or entries into memory and normalize adversarial cases.
- `unzipper`: rejected because it adds more dependencies and provides less explicit safety control.
- System `zip`/`unzip`: prohibited external processes.

## 5. ZIP Safety and EPUB Packaging

**Decision**: Complete metadata preflight before parsing content. Reject unsafe names, exact and Unicode-folded duplicates, file/directory conflicts, symlinks and special entries, encryption, unsupported methods, multi-disk archives, invalid ZIP64 values, and all stated count/size/ratio limits. During reconstruction, emit canonical `mimetype` first with STORE and no local-header extra fields, then stream remaining entries in original relative order.

**Rationale**: EPUB is an untrusted ZIP container. Central-directory checks prevent unsafe work early, while streamed counters enforce the same limits against lying headers. Reconstruction rather than in-place mutation provides a deterministic EPUB package and preserves original bytes. A same-directory temporary output allows final atomic promotion without cross-volume behavior.

**Alternatives considered**:

- Deduplicating entries by first or last value: rejected because ambiguity is unsafe.
- Normalizing dangerous paths and continuing: rejected because this can redirect references and hide malicious intent.
- Extracting into a temporary directory: rejected due to traversal, symlink, cleanup, disk-amplification, and file-permission risks.
- Preserving ZIP bytes exactly: impossible after repairs and unnecessary; semantic resources and unaffected entry bytes are preserved instead.

## 6. XML Parsing and Normalization

**Decision**: Use `saxes` incrementally with namespaces enabled. Decode only bounded UTF-8, UTF-16LE, or UTF-16BE input, reject XML 1.1, every `DOCTYPE`, external entities, malformed encoding, and depth above 64, and compare expanded names by namespace URI and local name. Build only the projections needed for container, package, navigation, and content-reference rules.

**Rationale**: A SAX parser supports cancellation, depth enforcement, bounded memory, and EPUB namespace correctness without fetching external resources. A strict no-DTD policy is deterministic and safer than attempting to distinguish benign from malicious legacy declarations. Projected models avoid retaining full document trees.

**Alternatives considered**:

- DOM parsing: rejected for higher memory and weaker incremental cancellation.
- Regular expressions or string matching: rejected as incorrect for XML namespaces, encoding, entities, and malformed structures.
- `fast-xml-parser`: rejected because full-object parsing and namespace/depth control are less suitable here.
- Allowlisted external DTD identifiers: rejected for v1 simplicity and safety; no external fetch is ever permitted.

## 7. Path and Reference Resolution

**Decision**: Represent archive paths as validated POSIX paths only. Resolve OPF, manifest, spine, XHTML, CSS, image, font, and fragment references relative to the owning internal document; strip query/fragment only for resource lookup; percent-decode once where the standard permits; and reject any absolute, local-file, remote, malformed, escaping, or multiply ambiguous result. Repair case or equivalent-path mismatches only with exactly one canonical target.

**Rationale**: Filesystem path helpers can accidentally adopt host semantics or permit escape. A single normalized internal namespace makes archive lookup deterministic and supports case-mismatch findings without touching the local filesystem.

**Alternatives considered**:

- Host filesystem resolution: rejected because EPUB paths are archive URLs, not macOS paths.
- Case-insensitive lookup without reporting: rejected because ZIP names are case-sensitive and arbitrary choice can alter meaning.
- Repairing when multiple folded targets exist: rejected as ambiguous.

## 8. Health and Finding Semantics

**Decision**: Use a closed v1 finding catalog with stable codes in [contracts/findings.md](./contracts/findings.md). Derive health using `Unsafe > Unsupported > Needs Review > Repairable > Healthy`. Informational findings may remain Healthy; every unresolved Warning or above must be either fully repairable or produce Needs Review/higher.

**Rationale**: A closed catalog makes “complete inspection” testable without claiming full EPUB specification or Kindle renderer equivalence. Stable identity supports before/after comparison, docs, fixtures, and UI grouping.

**Alternatives considered**:

- Numeric health score: rejected because it obscures evidence.
- Treating warnings as Healthy: rejected by the accepted specification.
- Reusing prior `ready/needs_fixes/blocked` states or `fixable` severity: rejected because they conflict with the new domain.

## 9. Repair Planning and Output Commit

**Decision**: Generate operations only from the permitted repair allowlist and require user review. Predict `<base>-kindle-ready.epub`, then `-2`, `-3`, and so on without creating a visible file. Write a random same-directory temporary file, close it, inspect it through a verified read-only descriptor, compare findings, and promote only a passing output through an atomic no-clobber hard link. If the predicted name races, select the next suffix and report the actual result.

**Rationale**: The plan explains every mutation before bytes are written and shows a predicted path without exposing an empty final file. On-disk reinspection validates the actual artifact rather than an in-memory representation. Same-directory no-clobber linking makes a complete file visible atomically and cannot overwrite a racing destination.

**Alternatives considered**:

- Overwrite confirmation: explicitly prohibited.
- Timestamp suffixes: collision-safe but less predictable and readable.
- Validate only in memory: rejected because it does not prove the final archive bytes are readable.
- Keep a failed output under the final Kindle-ready name: rejected as misleading.

## 10. SMTP Delivery

**Decision**: Use `nodemailer` with direct object configuration, no pooling, implicit TLS or mandatory STARTTLS only, certificate validation enabled, TLS 1.2 minimum, bounded DNS/connection/greeting/socket timeouts, and a controlled attachment stream. Keep manifest preference fields optional so the command can render its setup gate, require a valid configuration before intake, and store the application password as type `password`. Submit one EPUB per message and map raw errors to a small sanitized result taxonomy.

**Rationale**: Nodemailer is pure JavaScript, mature, stream-capable, dependency-free at runtime, and supports secure SMTP modes without implementing MIME, SASL, STARTTLS, or multiline protocol handling manually. Preferences are validated before book intake so setup failures remain separate from book results. One attachment per message satisfies explicit selection and isolates provider failures.

**Alternatives considered**:

- Raw `net`/`tls`: rejected due to protocol and security complexity.
- Gmail or Microsoft APIs/OAuth: rejected as provider-specific scope expansion.
- Mail.app compose: rejected because it depends on another configured application and is not the requested explicit SMTP path.
- Project backend: prohibited by privacy and self-containment.
- Plaintext or opportunistic TLS: rejected as unsafe.

## 11. Delivery Cancellation and Truthful Status

**Decision**: Cancellation before SMTP begins is `cancelled`. During attachment reading, destroy the stream and connection best-effort. If message data may have been accepted but confirmation is absent, return `delivery_unknown` and never retry automatically. A server `2xx` result is `submitted`, not “delivered to Kindle.”

**Rationale**: Nodemailer does not expose a general `AbortSignal` contract, and SMTP cannot provide transactional revocation after DATA. Claiming cancellation or retrying after an uncertain response risks false status or duplicate books.

**Alternatives considered**:

- Promise race against timeout: rejected because it abandons work without closing resources and can report a false failure.
- Automatic retry: rejected because SMTP submission may already have succeeded.
- Claiming Kindle delivery from SMTP acceptance: rejected because Amazon can reject or delay ingestion later.

## 12. Testing and Fixtures

**Decision**: Use Vitest with V8 coverage in a Node environment. Keep fixtures small and deterministic. Generate hostile ZIP structures with a dedicated TypeScript fixture builder capable of writing raw local headers, central directory records, flags, methods, external attributes, CRCs, duplicate names, and inconsistent sizes. Commit readable valid/minimal fixtures or their source definitions; create oversized logical cases through metadata rather than giant files.

**Rationale**: Vitest provides direct TypeScript testing and coverage without requiring a production build. High-level ZIP fixture libraries sanitize precisely the cases under test. Raw deterministic generation provides coverage without storing bombs or allocating dangerous payloads.

**Alternatives considered**:

- Jest: rejected as heavier for a pure TypeScript domain.
- Node test runner alone: viable but less convenient for TypeScript and coverage under the selected toolchain.
- External fixture generators: rejected because they introduce prohibited installed tools.
- Committing real ZIP bombs or huge files: rejected as unsafe and unnecessary.

## 13. Repository Migration

**Decision**: Preserve `.specify/`, `.agents/`, and `specs/004-raycast-epub-workflow/`; replace the product at root with the single npm package; rewrite README, AGENTS, ignore rules, and CI; remove the Swift/Xcode app, Swift tests, Python legacy tree, Calibre code, appcast, desktop install/update scripts, old release workflow, old product docs/specs/assets, and generated artifacts after their useful scenarios are represented in contracts and fixtures.

**Rationale**: Keeping an obsolete implementation or documentation conflicts with the constitution and creates two products. Git history remains the archive. Extracting rule names and scenarios before deletion prevents useful domain knowledge from being lost without retaining forbidden code.

**Alternatives considered**:

- Keep legacy code under `legacy/`: explicitly rejected by the specification.
- Create a new nested Raycast project beside Swift: rejected because it leaves two products.
- Port old implementations directly: rejected because they use forbidden runtimes, unbounded memory, unsafe XML approaches, and conflicting states.

## 14. Publication and Operational Boundary

**Decision**: Prepare Store metadata, a 512x512 owned PNG icon, MIT license, privacy/repair/finding documentation, package validation, lint, type checking, tests, coverage, build, and CI. Treat existing GitHub releases, appcast clients, external install links, and repository metadata as a deprecation follow-up, not as code retained in the new extension.

**Rationale**: Raycast Store review requires a complete, reviewable package and does not use the previous desktop update channel. Operational deprecation matters to existing users but must not preserve the old app in the source tree.

**Alternatives considered**:

- Continue Sparkle alongside Raycast: rejected as a second distributed application.
- Publish to npm: rejected because distribution is through Raycast Store.
- Automate Amazon login or upload: rejected by scope and Store risk.

## Sources

- [Raycast Manifest](https://developers.raycast.com/information/manifest.md)
- [Raycast CLI](https://developers.raycast.com/information/developer-tools/cli.md)
- [Raycast Security](https://developers.raycast.com/information/security.md)
- [Raycast Preferences](https://developers.raycast.com/api-reference/preferences.md)
- [Raycast Forms](https://developers.raycast.com/api-reference/user-interface/form.md)
- [Raycast Store Preparation](https://developers.raycast.com/basics/prepare-an-extension-for-store.md)
- [EPUB 3.3 OCF ZIP Container](https://www.w3.org/TR/epub-33/#sec-container-zip)
- [yauzl](https://github.com/thejoshwolfe/yauzl)
- [yazl](https://github.com/thejoshwolfe/yazl)
- [saxes](https://github.com/lddubeau/saxes)
- [Nodemailer SMTP](https://nodemailer.com/smtp)
- [Nodemailer Attachments](https://nodemailer.com/message/attachments)
- [Amazon Send to Kindle](https://www.amazon.com/sendtokindle)
- [Vitest Coverage](https://vitest.dev/guide/coverage)
- npm package metadata checked on 2026-07-20 for `@raycast/api`, `@raycast/eslint-config`, TypeScript, Vitest, Nodemailer, yauzl, yazl, and saxes
