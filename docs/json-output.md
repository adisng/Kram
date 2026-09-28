# JSON output

`--json` emits a single JSON document for machine-readable dry-run output. The current dry-run schema is:

```json
{
  "mode": "dry-run",
  "directory": "/path/to/folder",
  "scanned": 1,
  "toMove": 1,
  "skipped": 0,
  "operations": [
    { "source": "/path/file.pdf", "destination": "/path/Documents/file.pdf", "category": "Documents" }
  ]
}
```

`--json --apply` requires `--yes`.
