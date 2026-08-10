# Tripory — repo notes for Claude

## Git safety

- Before running any command that can discard uncommitted work (`git checkout -- <file>`, `git restore`, `git reset --hard`, `git clean`), always run `git stash push -u` first — never `git checkout --` a file straight away, even if the resulting diff looks like a mistake or unrelated noise. Inspect via `git stash show -p` and `git stash pop`/`git stash drop` once you've confirmed what's safe to discard.
- `Tripory/Resources/Localizable.xcstrings` is auto-edited by Xcode/`xcodebuild` on every build: it marks unreferenced keys `"extractionState": "stale"` and adds empty entries for newly-found string literals in source. This is expected and often shows up as a pre-existing uncommitted diff before you've touched anything — do not assume it's noise and revert it. If you need to compare against a clean baseline, `git stash` it first rather than checking it out.
- When editing `Localizable.xcstrings` programmatically, never round-trip the whole file through `json.dump` (even preserving key order) — Xcode's own formatting/whitespace and JSON key ordering differs subtly and produces a full-file diff. Insert new keys as a text block next to a neighboring key instead, and validate with `python3 -m json.tool` (or `json.load`) afterward without rewriting the file.
