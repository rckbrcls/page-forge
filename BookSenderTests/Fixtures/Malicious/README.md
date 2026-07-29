# Malicious Fixtures

Traversal, absolute-path, duplicate, link, encrypted, expansion-limit,
external-entity, deep-XML, and remote-reference fixtures are generated
deterministically in isolated temporary directories. Tests never extract these
archives outside an app-owned UUID workspace.
