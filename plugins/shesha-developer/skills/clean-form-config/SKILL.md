---
name: clean-form-config
description: Analyzes a Shesha form configuration JSON and removes dead/obsolete component properties, strips console.log calls from JS code strings, and validates property value types. Use when a form has been migrated, components have been refactored, or you want to clean up stale properties and debug statements.
---

# Clean Form Configuration

Identify and remove **dead properties**, **console.log debug statements**, and **type mismatches** from a Shesha form configuration.

---

## Step 1: Ensure component properties index is available

See [generate-index.md](generate-index.md) for full instructions.

Check whether `.claude/shesha/component-properties.json` already exists:

```bash
node -e "require('fs').statSync('.claude/shesha/component-properties.json')" 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

- If **EXISTS** and `data._meta?.version === 2` → proceed to Step 2.
- If the key `_baseProperties` is present (v1 format) → tell the user "Index is in old format, regenerating..." then treat as MISSING.
- If **MISSING** → follow [generate-index.md](generate-index.md) to write and run the extraction script.

---

## Step 2: Load the form config

Choose one of:

**Option A — Fetch from API**: Follow [api.md](api.md) to resolve the base URL, authenticate, and retrieve the form by module + name.

**Option B — Local file**: Ask the user for the file path, then use `Read` to load it.

In both cases normalise to `{ components, formSettings }` as described in the Normalisation section of [analysis.md](analysis.md) before continuing.

---

## Step 3–8: Analyse and clean

Follow [analysis.md](analysis.md) for:

- **Step 3** — Load and interpret the component properties index (v2 format).
- **Step 4** — Walk the component tree; identify dead properties and unknown types.
- **Step 4b** — Scan all string values for `console.log` calls.
- **Step 4c** — Type-check valid properties; flag auto-fixable and manual-review mismatches.
- **Step 5 / 5b / 5c** — Present findings (dead props, console.log, type mismatches).
- **Step 6** — Single confirmation prompt.
- **Step 7** — Apply all cleanups and output cleaned JSON.
- **Step 8** — Summary with size reduction.

---

## Notes

- **Conservative approach**: ambiguous properties go to manual review, not auto-clean.
- **Structural keys are never removed**: `id`, `type`, `parentId`, `components`.
- **Nested objects are not deep-cleaned**: only top-level component keys are checked.
- **`IPropertySetting` wrappers** (`{ _mode, _value, _code }`) are valid for any property.
- **`_mode: 'code'` values are never type-checked** — runtime expressions.
- **`null` values are never type-checked** — valid for any property type.
- To regenerate the index after upgrading shesha-reactjs, delete `.claude/shesha/component-properties.json` and re-run the skill.
