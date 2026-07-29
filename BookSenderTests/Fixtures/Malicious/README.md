# Malicious Fixtures

`FixtureFactory` generates traversal, absolute-path, canonical collision,
symbolic-link, encryption, unsupported-compression, size, DTD/entity, deep XML,
excessive XML, remote-reference, cancellation, write-failure, and revalidation
fixtures from local deterministic definitions.

Archive fixtures are inspected in app-owned UUID workspaces. Tests assert that no
entry escapes its workspace, no external resource is resolved, partial files are
removed, and selected originals remain byte-for-byte unchanged.
