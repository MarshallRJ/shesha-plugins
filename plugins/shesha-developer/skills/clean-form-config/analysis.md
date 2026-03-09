# Analysis Steps

Steps 2–8 of the `clean-form-config` skill.

---

## Normalisation

Load the file provided by the user with the `Read` tool. Extract `{ components, formSettings }` from the various input shapes:

| Input shape | How to extract |
|---|---|
| `{ "Markup": "...", "Name": "..." }` (exported file) | `JSON.parse(obj.Markup)` |
| `{ "result": { "markup": "..." } }` (ABP API response) | `JSON.parse(obj.result.markup)` |
| `{ "markup": "..." }` (raw DTO) | `JSON.parse(obj.markup)` |
| `{ "components": [...], "formSettings": {} }` | use directly |

Verify you have an object with a `components` array before continuing.

---

## Step 3: Load the component properties index

Read `.claude/shesha/component-properties.json` (v2 format).

Structure:
- `_meta` — skip.
- `base.props` — property keys valid on **every** component.
- `base.types` — expected value type for base properties with known types.
- `_formSettings.props` — valid keys for the `formSettings` object (from `IFormSettings`).
- `_formSettings.types` — expected value types for `formSettings` properties.
- Per component type entry (e.g. `textField`) — `{ props: [...], types: {...} }`.
  - `props` — component-specific additional property keys.
  - `types` — expected value types for those properties (only those with known types).

For each component being analyzed, build:

```
allowedKeys = new Set([...data.base.props, ...(data[component.type]?.props ?? [])])
typeMap = { ...data.base.types, ...(data[component.type]?.types ?? {}) }
```

For the `formSettings` object:

```
formSettingsAllowedKeys = new Set(data._formSettings.props)
formSettingsTypeMap = data._formSettings.types
```

Properties in `allowedKeys`/`formSettingsAllowedKeys` but absent from the type map have ambiguous/union types — skip type-checking for those.

---

## Step 4: Walk the component tree and identify dead properties

The `components` array is a **nested tree** — each component may have a child `components` array. Walk it recursively.

For each component:

1. Get `component.type`.
2. Build `allowedKeys` and `typeMap` as described in Step 3.
3. For each key on the component object:
   - Skip keys starting with `_` or `shesha:`.
   - Skip the key `components`.
   - If the key is **not in `allowedKeys`** → dead property candidate.
4. If the type is **not in the index at all** (unknown/custom type):
   - Only check against `base.props`.
   - Tag results with `[TYPE UNKNOWN — manual review]`.
   - Do **not** include these in the auto-clean list.

**Also validate `formSettings`:**

For each key in the `formSettings` object:
- Skip keys starting with `_`.
- If the key is **not in `formSettingsAllowedKeys`** → dead formSettings property.
- Report these separately under "Dead formSettings properties".

---

## Step 4b: Scan for console.log calls in string properties

Walk the **entire** parsed JSON object recursively (not just component top-level keys). For every `string` value encountered, check whether it contains `console.log`. This catches values nested in `IPropertySetting` wrappers (`{ _mode, _value, _code }`) and any other nested structure automatically.

Use this regex to find and remove console.log calls from each matching string:

```
/console\.log\s*\((?:[^)(]|\((?:[^)(]|\([^)(]*\))*\))*\)\s*;?\s*/g
```

Replace each match with `''`. After replacement, collapse excess blank lines: replace `/\n{3,}/g` with `\n\n`.

Track each removal:
- Which component it belongs to (look up the nearest ancestor component by `id`)
- Which property key the string was found in (e.g. `onChangeCustom`, or `customVisibility._code` for nested wrappers)
- How many `console.log` calls were removed from that string

---

## Step 4c: Type validation for known properties

Also type-check the `formSettings` object: for each key in `formSettings` that IS in `formSettingsAllowedKeys`, apply the same type-check logic using `formSettingsTypeMap[key]`. Report these under "formSettings type mismatches".

For each component, for each key that IS in `allowedKeys` (valid properties):

1. `expectedType = typeMap[key]` — if not present → skip (ambiguous type).
2. `rawValue = component[key]`
3. Unwrap `IPropertySetting` wrapper if present:
   - If `rawValue` is an object with `_mode === 'code'` → skip (JS expression, runtime type unknown).
   - If `rawValue` is an object with `_mode === 'value'` → `checkValue = rawValue._value`.
   - Otherwise → `checkValue = rawValue`.
4. If `checkValue === null` or `checkValue === undefined` → skip.
5. Determine `actualType`:
   - `Array.isArray(checkValue)` → `'array'`
   - `typeof checkValue === 'object' && checkValue !== null` → `'object'`
   - Otherwise → `typeof checkValue` (string/boolean/number)
6. Compare `actualType` vs `expectedType`. If mismatch:
   - **Auto-fixable**:
     - boolean expected, got string `"true"` or `"false"` → auto-fixable
     - number expected, got string matching `/^\d+(\.\d+)?$/` → auto-fixable
   - **Manual review**: all other mismatches

---

## Step 5: Present the dead property findings

If no dead properties are found in either components or `formSettings`, skip this section.

Otherwise show `formSettings` dead properties first (if any):

```
Dead formSettings properties (if any):
  - onBeforeData:  "console.log(data)"  [DEAD — not in IFormSettings]
  - postUrl:       "https://..."        [LEGACY — replaced by dataSubmittersSettings]
```

Then component dead properties:

```
Found N dead properties across M components:

Component                    | Type         | Dead Properties
-----------------------------|--------------|-----------------------------
"First Name" (id: abc…)      | textField    | fontColor, borderRadius
"Submit" (id: def…)          | button       | backgroundColor

Details:
  • "First Name" (textField)
      - fontColor:     "#333333"
      - borderRadius:  4

  • "Submit" (button)
      - backgroundColor:  "#0070f3"
```

For each dead property value, truncate strings longer than 60 characters with `…`.

---

## Step 5b: Present console.log findings

If no console.log calls were found, skip this section.

Otherwise show:

```
console.log cleanup:
  • "My Component" (textField) → onChangeCustom: removed 2 console.log call(s)
  • "Submit" (button) → customVisibility._code: removed 1 console.log call(s)

Total: 3 console.log calls removed from 2 components
```

---

## Step 5c: Present type mismatch findings

If no type mismatches were found, skip this section.

Otherwise show:

```
Type mismatches:
  • "First Name" (textField) → spellCheck: expected boolean, got string ("true") [AUTO-FIXABLE]
  • "Age" (numberField) → max: expected number, got string ("100") [AUTO-FIXABLE]
  • "Container" (container) → alignItems: expected string, got object [MANUAL REVIEW]

Total: N mismatches (X auto-fixable, Y need manual review)
```

---

## Step 6: Confirm removal

Ask the user a **single** confirm prompt covering all findings:

> Apply N cleanups:
>   - X dead properties removed
>   - Y console.log calls removed
>   - Z type fixes (W items need manual review — listed above)
>
> Proceed? (yes / no / skip-type-fixes)

Adjust to omit whichever counts are zero. If there is nothing to clean, tell the user and stop.

- **no** → stop, output nothing.
- **yes** → apply everything (dead props + console.log + all auto-fixable type fixes).
- **skip-type-fixes** → apply dead props and console.log only.

---

## Step 7: Output the cleaned form

1. Deep-clone the markup object.
2. Walk the component tree. For each component flagged in Step 4, delete the dead property keys.
3. Delete dead keys from `formSettings`.
4. Apply console.log cleanup: for every string value that contained `console.log`, replace with the regex-stripped, blank-lines-collapsed version.
5. Apply auto-fixable type fixes (components and `formSettings`):
   - `"true"` → `true`, `"false"` → `false` for boolean properties.
   - `"123"` → `parseFloat("123")` for number properties.
   - If the value was wrapped (`_mode: 'value'`), fix `_value` rather than the outer key.
   - Do **not** modify `[MANUAL REVIEW]` items.
6. Do **not** modify component structure or any valid non-flagged properties.
7. Output the cleaned `{ components, formSettings }` object as a formatted JSON code block.

---

## Step 8: Summary

```
Cleaned form — N changes applied:

Dead properties removed:
  • "First Name" (textField): fontColor, borderRadius
  • "Submit" (button): backgroundColor

console.log calls removed:
  • "My Component" (textField) → onChangeCustom: 2 call(s)
  • "Submit" (button) → customVisibility._code: 1 call(s)

Type fixes applied:
  • "First Name" (textField) → spellCheck: "true" → true
  • "Age" (numberField) → max: "100" → 100

Items needing manual review (not changed):
  • "Container" (container) → alignItems: expected string, got object

Original size:  XX,XXX chars
Cleaned size:   YY,YYY chars
Reduction:      ZZZ chars (P%)
```

Omit whichever sections have no entries.
