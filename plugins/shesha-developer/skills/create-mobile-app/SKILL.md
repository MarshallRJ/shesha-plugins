---
name: create-mobile-app
description: Scaffolds a new Shesha mobile application by running `npx sheshamobile-create`. Use when the user asks to create, scaffold, or generate a new mobile app using the Shesha mobile framework. Collects all required parameters via conversation with validation before running the command.
---

# Create Mobile App

Collect each parameter from the user via conversation messages, validate each response, then run `npx sheshamobile-create`.

## Workflow

Ask for **one parameter at a time** in the order below. After each response, validate it against the rule. If invalid, explain why and re-ask — do not move to the next parameter until the current one passes.

### Parameters (in order)

| # | Parameter         | What to ask                          | Validation rule                                      |
|---|-------------------|--------------------------------------|------------------------------------------------------|
| 1 | `name`            | App name                             | Non-empty, only letters, numbers, and hyphens        |
| 2 | `namespace`       | App namespace / package identifier   | Domain-like format, e.g. `com.company.app` (at least one dot, valid segments) |
| 3 | `BASE_URL`        | API base URL path                    | Must start with `/`                                  |
| 4 | `HOME_URL`        | Home screen URL                      | Must start with `http://` or `https://`              |
| 5 | `ONBOARD_URL`     | Onboarding screen URL                | Must start with `http://` or `https://`              |
| 6 | `GOOGLE_MAPS_KEY` | Google Maps API key                  | Non-empty                                            |
| 7 | `MAPBOX_ACCESS_KEY` | Mapbox access token                | Non-empty                                            |
| 8 | `npmUser`         | npm registry username                | Non-empty                                            |
| 9 | `npmPass`         | npm password or token                | Non-empty. Remind the user not to share real secrets in shared sessions. |
| 10 | `npmEmail`       | npm account email                    | Must match `x@x.x` pattern                          |
| 11 | `sdkDir`         | SDK directory path                   | Non-empty                                            |

## After All Parameters Are Collected

1. Show a summary table of all values (mask `npmPass` as `****`).
2. Ask: "Proceed with these values? (yes/no)"
3. If yes, run (passing values as comma-separated key=value pairs via stdin):

```bash
echo "name=<name>, namespace=<namespace>, BASE_URL=<BASE_URL>, HOME_URL=<HOME_URL>, ONBOARD_URL=<ONBOARD_URL>, GOOGLE_MAPS_KEY=<GOOGLE_MAPS_KEY>, MAPBOX_ACCESS_KEY=<MAPBOX_ACCESS_KEY>, npmUser=<npmUser>, npmPass=<npmPass>, npmEmail=<npmEmail>, sdkDir=<sdkDir>" | npx sheshamobile-create
```

4. Report success or surface any errors.
5. If the user says no at the confirmation step, ask which values they want to change and re-collect only those.
