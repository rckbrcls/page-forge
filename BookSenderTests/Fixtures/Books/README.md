# Book Fixtures

`FixtureFactory` generates deterministic EPUB 2, EPUB 3, PDF, malformed package,
reference, media-type, encryption, active-content, and repair fixtures entirely
inside the native test target.

`fixture-manifest.json` is the source of truth for fixture IDs, definition
digests, expected health, finding codes, repair actions, and readiness. The
manifest never points to removed TypeScript sources or external downloads.

Tests create each binary in an isolated temporary directory, verify deterministic
bytes and SHA-256 digests, and remove it after the test. No generated fixture is
bundled in the production application.
