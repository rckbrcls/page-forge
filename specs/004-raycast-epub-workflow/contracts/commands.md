# Command Contract: Book Sender

## `Send Book to Kindle`

- Mode: `view`
- Input: stable Finder selection, falling back to a multi-select EPUB/PDF picker
- Processing: sequential per-file checks; EPUB-only deterministic repair and revalidation
- Confirmation: required before the first SMTP connection
- Delivery: one attachment per SMTP message, preserving the original display name
- Fallback: open the official Amazon Send to Kindle page and reveal the prepared file
- Safety: never modify an original, never automate Amazon login/upload, never expose secrets or raw transport errors

The extension exposes no separate inspection or preparation commands.
