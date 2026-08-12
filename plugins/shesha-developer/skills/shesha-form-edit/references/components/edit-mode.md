# editMode, visibility, enabled, permissions

---

## editMode rule (non-negotiable) — decided PER FORM TYPE

There is no single correct value. Both blanket rules caused real production bugs: blanket `"editable"` made detail-form fields editable before the user clicked Edit; blanket `"inherited"` rendered dead inputs on action pages and dialogs tested standalone. Decide by the form's type:

| Form type | Interactive inputs (`textField`, `dropdown`, `autocomplete`, …) | Why |
|---|---|---|
| **Entity detail form** with a Start Edit / Submit / Cancel Edit lifecycle | `"inherited"` | The form-level mode governs; the lifecycle buttons toggle it. Explicit `"editable"` makes fields editable while the form is still in read mode. |
| **Create / edit dialog** (opened via Show Dialog with `formMode: "edit"`) | `"editable"` | A dialog is always an edit context; proven canon across 33 production create forms. Also keeps the dialog testable standalone. |
| **Action / anonymous pages** (`dataLoaderType: "none"`, login, OTP, search forms, custom toolbars) and inline `link`s | `"editable"` | The effective mode resolves read-only, so `"inherited"` renders fields that won't accept input and buttons that swallow clicks. |
| **Pure visual / display** (`text`, `image`, `container`, `columns`, `card`, `refListStatus`) | `"inherited"` or omit | No interactive surface. |
| **Detail-header lifecycle `buttonGroup`** (Edit/Save/Cancel) | copy the canonical seed verbatim | The seeds encode the working config; don't restamp. |

Never blanket-stamp either value across a whole form. When validating an edit: walk the tree and assert each interactive component's `editMode` matches the **form-type rule above** — flag mismatches per form type, not against a single absolute.

### Buttons: `"inherited"` renders `disabled`, with no visual cue

Worth its own warning because nothing tells you. A `button` / `buttonGroup` item left on `editMode: "inherited"` inside a read-only display context (a `datalist` row template being the common case) is rendered with the DOM attribute **`disabled`** — there is no HTML `readonly` for `<button>`, so the framework substitutes `disabled`. The button looks completely normal, clicks do nothing, and no console message appears. Schema and guardrail validation both pass clean.

Set `editMode: "editable"` explicitly on **both** the `buttonGroup` and the item, on any interactive control whose parent context you have not positively confirmed is editable. If the button is inside a datalist row template, fixing `editMode` only gets you as far as a button that is *enabled* — its action still won't fire from that scope, which is a separate problem with its own fix in [data-tables.md](data-tables.md) "Card click-through".

---

## Visibility / enabled — four properties

| Property | Meaning |
|---|---|
| `hidden` | Boolean OR `IPropertySetting` with `_mode: 'code'` returning bool. When true, the component is removed from the DOM. |
| `customVisibility` | Pure JS expression returning bool (legacy form of `hidden`). Prefer `hidden` with the code-mode wrapper for new code. |
| `editMode` | `'editable'` \| `'readOnly'` \| `'inherited'`. **Set per the form-type rule above** (detail forms `inherited`, dialogs/action pages `editable`). |
| `customEnabled` | JS expression returning bool. When false, the component renders but is disabled (greyed out). |

Use `hidden` (with code-mode wrapper) over `customVisibility` for new code — same effect, better DX:

```json
"hidden": {
  "_mode": "code",
  "_code": "formMode === 'create' && !data.parent"
}
```

Interaction rules: `editMode === 'readOnly'` always wins. `editMode === 'editable'` lets `customEnabled` decide. `editMode === 'inherited'` resolves against the form's effective mode and is risky on forms with no data loader (see the editMode rule above).

---

## Conditional containers

A `hidden` container hides itself AND its children. Don't combine with per-child `hidden` unless deliberately layered — the child rules don't override the parent's.

---

## Permissions

```json
"permissions": ["app:Members.View", "app:Members.Edit"]
```

The component is hidden if the user lacks **all** listed permissions. To require ALL, list them. To require ANY, use a single hook permission and group via roles.

Form-level permissions live on the FormConfiguration record itself (set via the designer or the API), not in markup.
