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

Read the bundled index: `plugins/shesha-developer/skills/clean-form-config/assets/component-properties.json` (v2 format).

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

## Step 4d: Validate `values` item shape for dropdown components

For every component where **`type === 'dropdown'`** and **`dataSourceType === 'values'`**:

1. Skip if `values` is absent, `null`, or not an array.
2. For each item in the array, check:
   - **Required keys present**: `label` (string), `value` (string).
   - **Known keys**: `label`, `value`, `color` (string), `icon` (string), `id` (string). Any other key is an **unknown key**.
   - **Type check**: `label` and `value` must be strings. `color` and `icon`, if present, must be strings.
3. Classify each issue:
   - Missing `label` or `value` → **[MANUAL REVIEW]**
   - Missing `color` → **[AUTO-FIXABLE]** — add `"color": ""`
   - Wrong type for `label`, `value`, `color`, or `icon` → **[MANUAL REVIEW]**
   - Unknown extra key on an item → **[MANUAL REVIEW]**
4. Report issues grouped by component under "Step 5d". Track auto-fixable vs manual.

---

## Step 4e: Run layout checks

Read [layout-checks.md](layout-checks.md) and run all checks (L1, L2, …) against the full component tree and `formSettings`. Collect results into two lists: **auto-fixable layout issues** and **manual-review layout issues**. Report under Steps 5e and 5f.

---

## Step 4f: Scan scripts for label used instead of propertyName

Build a lookup of every component that has **both** a non-empty `label` (string) **and** a non-empty `propertyName` (string) where `label !== propertyName`.

Walk all JS code strings in the form config (same strings scanned in Step 4b). For each label in the lookup, search the string for the label appearing in data-access patterns:

```
// bracket notation (works for labels with spaces)
(?:data|formData|initialValues|values|form)\s*(?:\?\.)?\s*\[\s*['"]LABEL['"]\s*\]

// dot notation (only relevant when label has no spaces)
(?:data|formData|initialValues|values|form)\s*(?:\?\.)?\s*\.LABEL\b
```

For each match, record:
- The component id and property key where the script lives
- The label string found
- The correct `propertyName` to use instead

These are **never auto-fixable** — script replacements could change logic. Report under Step 5f.

---

## Step 4g: Validate JavaScript syntax of code strings

**Scope:** Collect all JS code strings from the component tree:
- `IPropertySetting` objects where `_mode === 'code'` — use the `_code` string.
- Standalone string values that contain JS indicators: `function`, `=>`, `return `, `if(`, `var `, `let `, `const `.

For each code string, check for these syntax problems:

| Heuristic | How to detect |
|---|---|
| Unmatched braces/parens/brackets | Count opens vs closes for `{`, `[`, `(` — flag if the totals differ |
| Unclosed string literal | Count unescaped `'`, `"`, `` ` `` occurrences — flag if any count is odd |
| Template literal `${` without closing `}` | Count `${` vs `}` inside template literals — flag mismatch |
| `function` missing closing `)` or `{` | Check that each `function(` or `function name(` has a matching `)` followed by `{` |

These are heuristics — reason about the script content to identify the most likely issue. When a script is too long to analyze fully, check the first and last 300 characters for obvious unclosed constructs.

Severity: **`[CRITICAL]`** — invalid scripts throw runtime errors and break form functionality.
**Never auto-fixable** — repair requires developer intent.

Output format per finding:
```
[CRITICAL] Script syntax error
  Component: <id> (<type>)
  Property:  <key>
  Issue:     <description, e.g. "unmatched braces: 3 opens, 2 closes">
  Excerpt:   <first 120 chars of script>
```

---

## Step 4h: Detect API calls missing try-catch

Walk all JS code strings (same set as Step 4g).

**API call patterns to match (regex):**
- `axios\s*\.\s*(get|post|put|delete|patch|request)\s*\(`
- `fetch\s*\(`
- `\b(getHttp|postHttp|putHttp|deleteHttp|patchHttp)\s*\(` (Shesha HTTP helpers)
- `http\s*\.\s*(get|post|put|delete|patch)\s*\(`

For each script containing a match, check whether the call site is inside a try-catch block:
- Heuristic: scan backwards from the match position for a `try\s*{` that has not yet been closed by a matching `}`.
- If no enclosing try-catch is found → flag.

Severity: **`[MANUAL REVIEW]`** — best practice, not a crash risk on its own.
**Never auto-fixable** — the surrounding function structure varies.

Output format per finding:
```
[MANUAL REVIEW — add try-catch]
  Component: <id> (<type>)
  Property:  <key>
  API call:  <matched text excerpt>
  Suggested: wrap the call in try { ... } catch (error) { ... }
```

---

## Step 4i: Detect API calls missing async/promise handling

Walk all JS code strings (same set as Step 4g). Use the API call patterns from Step 4h.

**Async-context property keys** — these Shesha lifecycle hooks must return a Promise or be declared async:

```
onFinish, onSubmit, getData, postData, customValidators,
onValuesChange, onInitialized, onComplete
```

Flag the following two scenarios as **`[CRITICAL]`**:

**Scenario A — `await` used outside an `async` function:**
- Script contains `await ` (with trailing space or opening paren) **and**
- The containing function is NOT declared `async`: none of `async function`, `async (`, `async\s+\w+\s*(` match.
- This is broken JavaScript — `await` in a non-async context is a syntax/runtime error.

**Scenario B — API call in an async-context property without async handling:**
- The property key matches the async-context list above **and**
- The script contains an API call pattern **and**
- The function is NOT async (no `async function` / `async (`) **and**
- The call is NOT chained with `.then\s*(` **and**
- The script does NOT contain `return new Promise\s*(`.
- Result: the hook executes the call but does not await the response — the operation silently runs in the background and any return value is lost.

**Never auto-fixable.** Report under Step 5i.

Output format per finding:
```
[CRITICAL] Missing async/promise handling
  Component: <id> (<type>)
  Property:  <key>  (async context — must return a Promise)
  Scenario:  A — await used in non-async function
             B — API call result not awaited or chained in async-context property
  API call:  <matched text excerpt>
  Fix:       declare the function async and await the call,
             or chain .then(...).catch(...)
```

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

## Step 5d: Present values shape findings

If no issues were found, skip this section.

Otherwise show:

```
values shape issues:
  • "Category" (dropdown) — item[1]: missing color [AUTO-FIXABLE]
  • "Status" (dropdown) — item[0]: label is not a string [MANUAL REVIEW]
  • "Status" (dropdown) — item[2]: unknown key "extraProp" [MANUAL REVIEW]

Total: N issues (X auto-fixable, Y manual review)
```

---

## Step 5e: Present layout findings

If no layout issues were found, skip this section.

Otherwise show auto-fixable issues first, then manual-review issues:

```
Layout issues:
  [L2 — span] formSettings: wrapperCol.span=null → set to 16 [AUTO-FIXABLE]
  [L1 — overflow] "Container1" (container) — desktop: width 200% [MANUAL REVIEW]
  [L2 — span] "First Name" (textField): 10+10=20 ≠ 24 [MANUAL REVIEW]

Total: N issues (X auto-fixable, Y manual review)
```

---

## Step 5f: Present script label reference findings

If no matches were found, skip this section.

Otherwise show:

```
Script label references (N found):
  • "Submit" (button) [customAction]: uses data['First Name'] — should be data['firstName'] [MANUAL REVIEW]
  • "Panel" (container) [onLoad]: uses data['Status'] — should be data['status'] [MANUAL REVIEW]
```

---

## Step 5g: Present script syntax error findings

If no syntax errors were found, skip this section.

Otherwise show:

```
Script syntax errors (N found — CRITICAL):
  • "Submit" (button) [customAction]
      Issue:   unmatched braces: 3 opens, 2 closes
      Excerpt: function onSubmit(data) { if (data.id) { return axios.post('/api/...
  • "Panel" (container) [onLoad]
      Issue:   unclosed string literal (odd number of " characters)
      Excerpt: const label = "First Name;
```

---

## Step 5h: Present missing try-catch findings

If no API calls without try-catch were found, skip this section.

Otherwise show:

```
API calls missing try-catch (N found — manual review recommended):
  • "Submit" (button) [onFinish]
      API call:  axios.post('/api/services/...')
      Suggested: wrap in try { ... } catch (error) { ... }
  • "Load Data" (customComponent) [getData]
      API call:  getHttp('/api/...')
      Suggested: wrap in try { ... } catch (error) { ... }
```

---

## Step 5i: Present missing async/promise findings

If no async/promise issues were found, skip this section.

Otherwise show:

```
API calls missing async/promise handling (N found — CRITICAL):
  • "Submit" (button) [onFinish]  (async context — must return a Promise)
      Scenario: B — API call not awaited or chained
      API call:  axios.post('/api/services/...')
      Fix:       declare function async and await the call, or chain .then().catch()
  • "Validator" (textField) [customValidators]  (async context — must return a Promise)
      Scenario: A — await used in non-async function
      API call:  fetch('/api/...')
      Fix:       declare function async
```

---

## Step 6: Confirm removal

Ask the user a **single** confirm prompt covering all findings:

> Apply N cleanups:
>   - X dead properties removed
>   - Y console.log calls removed
>   - Z type fixes (W items need manual review — listed above)
>   - V values shape fixes (U items need manual review — listed above)
>   - X layout fixes (Y items need manual review — listed above)
>   - N script label references (manual review only — listed above)
>   - S script syntax error(s) — CRITICAL, manual fix required
>   - T API call(s) missing try-catch — manual review recommended
>   - U API call(s) missing async handling — CRITICAL, manual fix required
>
> Proceed? (yes / no / skip-type-fixes)

Adjust to omit whichever counts are zero. If there is nothing to clean, tell the user and stop.

- **no** → stop, output nothing.
- **yes** → apply everything (dead props + console.log + all auto-fixable type/values fixes).
- **skip-type-fixes** → apply dead props and console.log only (skips both type and values auto-fixes).

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
6. Apply auto-fixable values shape fixes:
   - For each item flagged with missing `color` → add `"color": ""` to the item.
   - Do **not** modify items flagged `[MANUAL REVIEW]`.
7. Apply auto-fixable layout fixes (L2 span fixes only):
   - For each `[AUTO-FIXABLE]` L2 issue: set the absent/null span to `24 − knownSpan` on the same object (`formSettings`, `component.labelCol`, or `component.wrapperCol`).
   - Do **not** modify `[MANUAL REVIEW]` layout items.
8. Do **not** auto-fix script label references from Step 4f — these are manual review only.
9. Do **not** modify component structure or any valid non-flagged properties.
9. Output the cleaned `{ components, formSettings }` object as a formatted JSON code block.

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

Values shape fixes applied:
  • "Category" (dropdown) → item[1]: added color ""

Values items needing manual review (not changed):
  • "Status" (dropdown) → item[0]: label is not a string

Items needing manual review (not changed):
  • "Container" (container) → alignItems: expected string, got object

Layout fixes applied:
  • [L2] formSettings: wrapperCol.span set to 16

Layout issues needing manual review (not changed):
  • [L1] "Container1" (container) — desktop: width 200% (wrap enabled)
  • [L2] "First Name" (textField): labelCol=10 + wrapperCol=10 = 20

Script label references needing manual review (not changed):
  • "Submit" (button) [customAction]: uses data['First Name'] — should be data['firstName']

Script syntax errors — CRITICAL, fix required:
  • "Submit" (button) [customAction]: unmatched braces: 3 opens, 2 closes
  • "Panel" (container) [onLoad]: unclosed string literal

API calls missing try-catch (manual review recommended):
  • "Submit" (button) [onFinish]: axios.post(...)
  • "Load Data" (customComponent) [getData]: getHttp(...)

API calls missing async/promise handling — CRITICAL, fix required:
  • "Submit" (button) [onFinish]: Scenario B — API call not awaited or chained
  • "Validator" (textField) [customValidators]: Scenario A — await in non-async function

Original size:  XX,XXX chars
Cleaned size:   YY,YYY chars
Reduction:      ZZZ chars (P%)
```

Omit whichever sections have no entries.
