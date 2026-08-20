# Component cheat-sheet — read THIS before opening any seed

A compact `type → current version → minimal shape` table so you don't read 4,000-line seeds or
run a dozen probes just to discover a version. **Versions are framework-version-specific** — the
numbers below are for `@shesha-io/reactjs 0.45.x`; if the running app differs, resolve once (see
bottom) and trust that.

> Every component must carry its integer `version` (a versionless component re-runs the whole
> legacy migration chain at render and can throw `e.match` / `reading 'migrator'` / `reading 'version'`).
> `parentId` is mandatory on every node (root-level → `"root"`). `id` must be unique, opaque and
> stable — mint with `crypto.randomUUID()`; short sequential placeholders (`btn1`) render blank.

## Versions (0.45.x)

**Mirrored from `assets/components-kb/_index.json`, which is the authority.** This table is a
convenience copy so you don't open a file for one integer; `scripts/check-references.mjs` fails
if it drifts. For anything not listed: `grep -A2 '"<type>"' assets/components-kb/_index.json`.

| type | version | type | version |
|---|---|---|---|
| `container` | 7 | `datatable` | 29 |
| `columns` | 5 | `dataContext` | 8 |
| `text` | 5 | `datalist` | 11 |
| `textField` | 6 | `datatable.pager` | 4 |
| `textArea` | 5 | `datatable.quickSearch` | 3 |
| `numberField` | 5 | `tableViewSelector` | 2 |
| `dateField` | 7 | `button` | 9 |
| `dropdown` | 11 | `buttonGroup` | 15 |
| `autocomplete` | 8 | `alert` | 2 |
| `checkbox` | 5 | `collapsiblePanel` | 9 |
| `checkboxGroup` | 5 | `refListStatus` | 6 |
| `card` | 3 | `progress` | 3 |
| `sectionSeparator` | 5 | `notes` | 4 |

> Four of these were wrong until 2026-08-12 (`numberField` 3→5, `dropdown` 7→11,
> `refListStatus` 3→6, `collapsiblePanel` 7→9). A too-low version doesn't just risk a migration
> throw — it **silently drops the component's entire `desktop` style block** (`numberField` at v3
> ignored its style block; at v5 the same block applied). This file is the one you're told to read
> first, so the stale numbers were producing exactly the unstyled forms the pipeline exists to fix.

## Minimal shapes (omit styling — the renderer applies defaults)

```jsonc
// input (string). number→numberField(v5), date→dateField(v7); same skeleton.
{ "id": "<uuid>", "type": "textField", "version": 6, "parentId": "<pid>",
  "propertyName": "name", "componentName": "name", "label": "Name", "editMode": "inherited", "textType": "text" }

// reference-list dropdown
{ "id": "<uuid>", "type": "dropdown", "version": 11, "parentId": "<pid>", "propertyName": "status", "label": "Status",
  "editMode": "inherited", "dataSourceType": "referenceList",
  "referenceListId": { "module": "<mod>", "name": "<ReflistName>" }, "valueFormat": "simple", "mode": "single" }

// entity FK autocomplete
{ "id": "<uuid>", "type": "autocomplete", "version": 8, "parentId": "<pid>", "propertyName": "assignedTo", "label": "Assigned To",
  "editMode": "inherited", "dataSourceType": "entitiesList", "entityType": { "name": "Person", "module": "Shesha" }, "mode": "single" }

// checkboxGroup (hardcoded) — items, NOT values; each {label,value}
{ "id": "<uuid>", "type": "checkboxGroup", "version": 5, "parentId": "<pid>", "propertyName": "tags", "label": "Tags",
  "dataSourceType": "values", "mode": "multiple", "referenceListId": null, "container": {}, "validate": {},
  "items": [ { "label": "A", "value": "a" } ] }

// dataContext (wrapper for datatable/datalist — needs explicit entityType + sourceType)
{ "id": "<uuid>", "type": "dataContext", "version": 8, "parentId": "<pid>",
  "entityType": "<exact modelType>", "sourceType": "Entity", "dataFetchingMode": "paging",
  "defaultPageSize": 10, "uniqueStateId": "<name>", "componentName": "<name>", "propertyName": "<name>" }

// buttonGroup (action buttons NEVER as standalone `button` in a toolbar)
{ "id": "<uuid>", "type": "buttonGroup", "version": 15, "parentId": "<pid>", "isInline": true, "editMode": "editable",
  "items": [ { "id": "<uuid>", "itemType": "item", "itemSubType": "button", "label": "Add", "buttonType": "primary",
    "actionConfiguration": { "_type": "action-config", "actionName": "Show Dialog", "actionOwner": "shesha.common",
      "actionArguments": { "formId": { "name": "<create-form>", "module": "<mod>" }, "modalWidth": "60%" } } } ] }
```

## Resolve versions for THIS app in ONE probe (if not 0.45.x)

```bash
# dumps every component type → version seen in the running backend's forms, in one call
TOKEN=...; curl -s "$BASE/api/services/Shesha/FormConfiguration/GetAll?MaxResultCount=1000" -H "Authorization: Bearer $TOKEN" \
 | python -c "import sys,json,collections; seen={}; \
def w(o):\n  import collections\n  pass"  # in practice: walk each form's stringified markup, record max version per type
```

Prefer this over reading large seed files. **Do not** read `employee-table.json`,
`rs-detail-with-header.json`, or other multi-thousand-line seeds wholesale — open them only with
`Grep`/offset for one specific fragment.
