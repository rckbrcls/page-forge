# Book Sender

Book Sender is a focused Raycast extension for sending local books to Kindle.

It exposes one command:

```text
Send Book to Kindle
```

## Workflow

```text
Select EPUB or PDF
-> Check locally
-> Apply safe EPUB repairs when needed
-> Revalidate the repaired copy
-> Confirm delivery
-> Send to Kindle
```

- EPUB files receive structural inspection and deterministic safe repairs.
- PDF files are validated and sent without conversion.
- Originals are never modified.
- Repaired EPUBs retain the original book name when attached to Kindle delivery.
- SMTP is optional; without it, Book Sender opens Amazon's official Send to Kindle page.
- Amazon login and web upload are never automated.
- DRM removal and ebook conversion are out of scope.

## Requirements

- macOS
- Raycast
- Node.js `>=22.22.2 <23` for development

## Development

```bash
npm ci
npm run dev
```

## Verification

```bash
npm test
npx tsc --noEmit
npm run lint
npm run format:check
npm run build
```
