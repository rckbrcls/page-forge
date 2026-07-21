# Quickstart: Book Sender

## Verify

```bash
npm ci
npm test
npx tsc --noEmit
npm run lint
npm run format:check
npm run build
```

## Interactive Test

1. Run `npm run dev`.
2. Select an EPUB or PDF in Finder, or use the picker fallback.
3. Run `Send Book to Kindle`.
4. Verify checks and safe EPUB repairs finish before delivery confirmation.
5. Confirm SMTP delivery, or open the official Send to Kindle handoff.
6. Verify the original file is unchanged and the Kindle attachment keeps its original name.
