# Prompt versioning

LLM / Consult OG prompts use a semver **variant**:

```text
<major>.<date>.<minor>
```

Example: `1.20260718.0`

## Rules

1. **major** — Breaking or large intent change. **Ask before bumping.**
2. **date** — Always today’s date as `YYYYMMDD` (no hyphens).
3. **minor** — If not major, increment minor (and set date to today).

Agent skill: `.cursor/skills/prompt-versioning/SKILL.md`.
