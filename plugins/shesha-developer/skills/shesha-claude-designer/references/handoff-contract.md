# Handoff contract — roles, inputs/outputs, sequencing

The conductor (`shesha-claude-designer`) coordinates three specialists. This is the contract between them.

**Every handoff carries file paths, never file contents.** All of them are relative to `$RUN_DIR`, the single run directory created in [SKILL.md](../SKILL.md) Step 0 (`.claude/shesha/runs/<run-slug>/`) — older text saying `<workdir>` means this. Each dispatch prompt must state `$RUN_DIR` explicitly; an agent left to invent a scratch location writes somewhere nobody reads. Returning a large JSON blob through the conductor's context instead of a path is the single easiest context saving in the pipeline, and it also means the artifact still exists after a compaction.

## Roles

| Skill | Owns | Must NOT |
|---|---|---|
| `shesha-claude-designer` | ingest design, comprehend→plan, sequence, gate, verify end-to-end | author form JSON, pick hexes, push |
| `shesha-design-comprehension` | per-screen measured layout blueprint + placement verification (the probe + the diff) | author form JSON, pick hexes, push |
| `shesha-form-edit` | structure, CRUD wiring, validation, push, publish; **splits via flex `container` rows (never `columns`), sized via `desktop.dimensions.width`** | apply v7 appearance blocks itself; author `columns`; pick tokens/hexes |
| `shesha-design-system` | **all appearance**: app theme + per-component v7 style blocks + the v7 mechanics/channels docs + the capability matrix; audit | author structure, wire CRUD, push, or author `columns` |

## Contracts

**Designer → comprehension (Step 2, per screen)**
- Parent provides: `$RUN_DIR`, design source(s) + detected fidelity tier + screen name + (Tier A) repo/source paths + pinned viewport.
- Comprehension returns: **paths only** — `$RUN_DIR/blueprints/<screen>.blueprint.md` (archetype + `layout-tree` + `bindings` + `assertions`) and the saved probe `$RUN_DIR/probes/<screen>.design.layout.json`.

**Designer → shesha-form-edit (Step 4a, per screen) — "Contract A"**
- Parent provides: `$RUN_DIR`, the screen's **`blueprint.md` path**, the entity modelType (or "resolve from module"), the form identity (module + name), and the target backend context (if headless).
- shesha-form-edit returns: form created/edited (module + name + id), the detected version-profile facts, the resolved modelType, pushed/published state, the staged markup path under `$RUN_DIR/staged/`, **and a structural-integrity confirmation** — plus enough to run the placement probe (it builds the form `shesha-design-comprehension` will re-measure).
- **The conductor verifies the disk before accepting any of it:** `node <SKILL_ROOT>/shesha-form-edit/scripts/verify-artifact.mjs <staged-path> --backend <url> --token $RUN_DIR/access-token --json`. Exit `0` pass · `1` fail · `2` unreadable · `3` partial. Agents in this pipeline have twice reported a completed form that was absent or referenced forms that did not exist; a returned verdict is a claim, the file is the evidence.

**Designer → shesha-design-system (Step 3 theme + Step 4b style)**
- Parent provides: `$RUN_DIR`, token set / theme name, the **path** to the built form under `$RUN_DIR/staged/`, version-profile facts, recipe list.
- shesha-design-system returns: **the path** `$RUN_DIR/staged/<screen>.styled.form.json` (style blocks only, structure untouched), plus app-theme changes, a role→colour trace and audit findings as compact data. It does NOT push, and it does NOT return the styled JSON inline — the parent routes the path through `shesha-form-edit`.

**Comprehension ↔ form-edit (Step 5a.5, per screen)**
- After build+publish, comprehension re-probes the rendered form into `$RUN_DIR/probes/<screen>.built-r<n>.layout.json` and diffs against the blueprint `assertions`; each mismatch is a routed fix phrased in `shesha-form-edit`'s vocabulary (move node into the right flex `container` row, give the child its `desktop.dimensions.width`, add `display:"flex"` to a stacking row, wrap rows 2-cell, assign to the right tab). Loop until all assertions pass.

## Sequencing rules

1. **Token/app theme first, once** — establish the theme + set app-level primary/font/radius before per-screen styling.
2. **Comprehend before build** — every screen has a `blueprint.md` (Step 2) before `shesha-form-edit` is invoked.
3. **Structure before style, per screen.**
4. **Gate order: 5a structural integrity → 5a.5 PLACEMENT diff → 5b visual audit.** Placement is checked *before* styling; a form that fails placement is routed back to `shesha-form-edit`, never styled over.
5. **One push path** — all writes through `shesha-form-edit`.
6. **Multi-screen** — `shesha-form-edit` may dispatch one form-author per distinct new form; `shesha-design-system` styles centrally to keep the look coherent; comprehension verifies each screen's placement independently.
