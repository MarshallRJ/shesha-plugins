# Shesha API — Authentication and Form Fetch

Used by Step 2 of the `clean-form-config` skill to fetch a form configuration directly from a running Shesha backend.

---

## 1. Resolve the base URL

Check these sources in order, stopping at the first match:

1. `.env` in the project root — look for `NEXT_PUBLIC_BASE_URL`, `REACT_APP_BASE_URL`, or `BASE_URL`.
2. `appsettings.json` in the backend project — look for `Kestrel:Endpoints:Http:Url`.
3. Ask the user:
   > What is the base URL for your Shesha backend? (e.g. `http://localhost:21021`)

Strip any trailing slash from the resolved URL. Store as `BASE_URL`.

---

## 2. Authenticate

Ask the user:

> Please enter your Shesha username (or email) and password to fetch the form via the API.
> Leave blank to provide a local file path instead.

If the user leaves credentials blank → skip to Option B in Step 2 of `SKILL.md`.

If credentials are provided, run:

```bash
curl -s -X POST "{BASE_URL}/api/TokenAuth/Authenticate" \
  -H "Content-Type: application/json" \
  -d "{\"userNameOrEmailAddress\":\"{USERNAME}\",\"password\":\"{PASSWORD}\"}"
```

The response shape is:

```json
{
  "accessToken": "eyJ...",
  "encryptedAccessToken": "...",
  "expireInSeconds": 86400,
  "expireOn": "2026-03-10T13:00:00.000Z",
  "userId": 1,
  "personId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "resultType": 1
}
```

Extract `accessToken` and store it as `ACCESS_TOKEN`.

If the response has no `accessToken`, or `curl` returns a non-zero exit code, show the raw response to the user and fall back to Option B (local file path).

---

## 3. Fetch form by module + name

Ask the user:

> Enter the form **module** name and **form** name.
> (e.g. module: `Shesha`, name: `user-create`)

```bash
curl -s -G "{BASE_URL}/api/services/Shesha/FormConfiguration/GetByName" \
  --data-urlencode "module={MODULE}" \
  --data-urlencode "name={NAME}" \
  -H "Authorization: Bearer {ACCESS_TOKEN}"
```

The response shape is:

```json
{
  "result": {
    "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "module": { "name": "Shesha" },
    "name": "user-create",
    "markup": "{...}"
  }
}
```

Extract `result.id` and store it as `FORM_ID`. If the call fails or `result` is absent, show the error and stop.

> ⚠ **0.43 lifecycle note:** `GetByName` resolves the **Live** version, which is **immutable** on 0.43 —
> you must never push cleaned markup back to this id. `FORM_ID` here is only a *resolution anchor*: before
> pushing (§5) you resolve the lifecycle context (latest version per Origin) and edit a **Draft**, not this
> Live id. `GetByName` also hides any in-flight Draft/Ready for the same Origin — use `GetAll` with
> `isLast==true` to find one. See [../shesha-form-edit/references/version-lifecycle.md](../shesha-form-edit/references/version-lifecycle.md) for the full model.

---

## 4. Fetch the form JSON

```bash
curl -s -G "{BASE_URL}/api/services/Shesha/FormConfiguration/GetJson" \
  --data-urlencode "id={FORM_ID}" \
  -H "Authorization: Bearer {ACCESS_TOKEN}"
```

The response body is the raw form JSON string (same shapes as the normalisation table in [analysis.md § Normalisation](analysis.md#normalisation)). Parse and normalise to `{ components, formSettings }` using the normalisation table in [analysis.md](analysis.md) before proceeding to Step 3.

> ⚠ **0.43:** `id` here is the version whose markup you will **EDIT** — i.e. the **Draft** you will
> ultimately push to, not necessarily the Live id `GetByName` returned. For a Live form the cleaned markup
> must land on a fresh Draft (see §5). It is fine to fetch/clean from the Live markup, but the push targets
> the Draft. If a Draft/Ready is already in flight, fetch **its** id instead so you clean the in-flight version.

---

## 5. Push cleaned config to the backend (lifecycle-aware)

Used by Step 9 of the `clean-form-config` skill. `ACCESS_TOKEN` must be set (§2), and you must have a
resolution anchor for the form (`FORM_ID` from §3, or module+name).

> ⚠ **Cleaning is a real markup change → a new version.** On 0.43 you must **NEVER** push cleaned markup to
> a Live id. Editing a Live form means **clone → Draft → edit the Draft → publish**. The full model
> (status enum, endpoints, branch table, invariants, failure recovery, cache clearing) is the single source
> of truth in **[../shesha-form-edit/references/version-lifecycle.md](../shesha-form-edit/references/version-lifecycle.md)** — follow it; the steps
> below are the concrete push for this skill, not a replacement for that reference.

### 5.1 RESOLVE the current version

List the latest version per Origin (`isLast==true`) so you catch an in-flight Draft/Ready that
`GetByName` hides. Capture its `id` and `versionStatus`:

```bash
curl -s -G "{BASE_URL}/api/services/Shesha/FormConfiguration/GetAll" \
  --data-urlencode "MaxResultCount=50" \
  --data-urlencode 'Filter={"and":[{"==":[{"var":"module.name"},"{MODULE}"]},{"==":[{"var":"name"},"{NAME}"]},{"==":[{"var":"isLast"},true]}]}' \
  -H "Authorization: Bearer {ACCESS_TOKEN}"
```

The latest item's `versionStatus` is an integer: `1` Draft, `2` Ready, `3` Live, `4` Cancelled, `5` Retired.

### 5.2 BRANCH on `versionStatus` to get the Draft id you will push to

- **Live(3)** → `CreateNewVersion` to clone it to a fresh Draft, and capture the **new** id as `NEW_ID`:

  ```bash
  NEW_ID=$(curl -s -X POST "{BASE_URL}/api/services/Shesha/FormConfiguration/CreateNewVersion" \
    -H "Authorization: Bearer {ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"{FORM_ID}\"}" \
    | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const r=JSON.parse(d);console.log(r.result?.id ?? r.result);})")
  echo "New draft id: $NEW_ID"
  ```

  ⚠ `id` is mandatory — an empty `{}` body **404s**. All subsequent pushes target `$NEW_ID`, never the Live id.

- **Draft(1) or Ready(2)** → **reuse** the in-flight version's id as `NEW_ID`. Do **not** `CreateNewVersion` — a version already exists.

- **Retired(5) / Cancelled(4)** → never edit a terminal version. Resolve to the latest non-terminal version for the Origin first (usually the current Live via `GetByName`), then follow the Live branch.

### 5.3 Push the cleaned markup to the Draft (`NEW_ID`)

Build the multipart request body and POST to `ImportJson`, targeting **`NEW_ID`** (the Draft) — never a Live id.
Write the cleaned config to a temp file and build the body via Node to avoid shell-escaping issues:

```bash
# Write cleaned JSON to temp file first (replace /tmp/cleaned-form.json with the actual output path)
node -e "
const fs = require('fs');
const markup = fs.readFileSync('/tmp/cleaned-form.json', 'utf8');
const body = JSON.stringify({ itemId: process.env.NEW_ID, markup });
fs.writeFileSync('/tmp/import-body.json', body);
"

NEW_ID=$NEW_ID curl -s -X POST "{BASE_URL}/api/services/Shesha/FormConfiguration/ImportJson" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @/tmp/import-body.json
```

A successful response looks like `{ "result": true }`. (Equivalently, `UpdateMarkup` — `PUT` with
`{ "id": "$NEW_ID", "markup": "<stringified JSON>" }` — writes to the same Draft id; use whichever you prefer.)

If the call fails (non-200 status, `result` is `false`, or an `error` key is present), show the raw response
to the user and stop — do **not** retry automatically. A Draft you created but did not publish should be
abandoned via `UpdateStatus status:4` (see the reference's Failure recovery section).

### 5.4 PUBLISH the Draft → Ready → Live

Advance in two hops with `UpdateStatus` (the `filter` is **mandatory**); publishing to Live auto-retires the prior Live:

```bash
publish() {   # $1 = version id, $2 = target status int
  curl -s -X PUT "{BASE_URL}/api/services/Shesha/FormConfiguration/UpdateStatus" \
    -H "Authorization: Bearer {ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"filter\":\"{\\\"and\\\":[{\\\"==\\\":[{\\\"var\\\":\\\"id\\\"},\\\"$1\\\"]}]}\",\"status\":$2}"
}

publish "$NEW_ID" 2   # Draft(1) → Ready(2)
publish "$NEW_ID" 3   # Ready(2) → Live(3)  (auto-retires the previous Live)
```

(A version already at Ready only needs the `2→3` hop.) See the reference for the full branch table, invariants, and failure recovery.

### 5.5 Clear the frontend cache

The newly-published version renders stale from the frontend's IndexedDB until the cache is cleared. Clear
it per the reference's [Cache clearing](../shesha-form-edit/references/version-lifecycle.md#cache-clearing-mandatory-after-createpublish) recipe, then confirm:

> Form config cleaned and published as a new Live version of `{MODULE}/{NAME}` on `{BASE_URL}`.
