---
name: test-entity-crud-api
description: Test all domain entity CRUD GET endpoints and optionally auto-fix failures
argument-hint: "[--no-fix] [--update-entities] [--start-server]"
allowed-tools:
  - Bash(powershell *)
  - Bash(dotnet *)
  - Read
  - Edit
  - Glob
  - Grep
---

# Test Entity CRUD API Endpoints

This skill runs endpoint tests for all domain entities in any Shesha-based project and can automatically attempt to fix failures.

## Supported Project Structure

The skill auto-detects project files based on standard Shesha conventions:
- **Solution file:** `backend/*.sln`
- **Web.Host project:** `backend/**/*.Web.Host.csproj`
- **Domain folder:** `backend/**/*.Domain/Domain/`

## Arguments

- `--no-fix` - Disable auto-fix (default: auto-fix is enabled)
- `--update-entities` - Scan domain folder for new entities before testing
- `--start-server` - Build the solution and auto-start the backend server if not running

## Instructions

### Step 1: Parse Arguments

Check if the user passed `--no-fix` in `$ARGUMENTS`. If not present, auto-fix mode is enabled.

Arguments received: `$ARGUMENTS`

### Step 2: Run the Endpoint Tests

The scripts run directly from the skill's `scripts/` folder. Use the `-RepoRoot` parameter to point at the current project. **Always include `-UpdateEntities`** so the entity list stays in sync with the current domain model.

Execute from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-base-dir>/scripts/Run-EndpointTests.ps1" -RepoRoot "<repo-root>" -FullErrors -UpdateEntities
```

Replace `<skill-base-dir>` with this skill's base directory and `<repo-root>` with the project's repository root (the working directory).

Add `-StartServer` if `--start-server` was passed. Before running the test script, follow the server startup procedure below.

#### Server Startup Procedure (when `-StartServer` is used)

1. **Auto-detect the Web.Host project:** Find `backend/**/*.Web.Host.csproj`
2. **Ensure a `Project` launch profile exists** so the server binds to the correct port:
   - Locate `Properties/launchSettings.json` in the Web.Host project directory.
   - If the file does not exist, create `Properties/launchSettings.json` with a `Project` profile:
     ```json
     {
       "profiles": {
         "Project": {
           "commandName": "Project",
           "launchBrowser": false,
           "applicationUrl": "http://localhost:21021"
         }
       }
     }
     ```
   - If the file exists but has no `Project` profile, add one under `profiles` with the same shape.
   - If a `Project` profile already exists, leave it as-is.
   - Extract the port from the `applicationUrl` value (e.g. `21021`) and use it as the `BaseUrl` for the test scripts (`http://localhost:{port}`).
3. **Build the solution:**
   ```powershell
   dotnet build "<path-to-sln>" -c Debug
   ```
4. **Start the server in the background with output visible** so startup errors and logs can be diagnosed:
   ```powershell
   $ServerProcess = Start-Process -FilePath "dotnet" -ArgumentList "run","--project","<path-to-Web.Host.csproj>","--no-build","--launch-profile","Project" -PassThru -NoNewWindow
   ```
   Using `-NoNewWindow` keeps the server's stdout/stderr in the current console so you can see startup errors, migration failures, binding issues, etc. The `-PassThru` flag returns the process object for later cleanup. The `--launch-profile Project` ensures the server starts on the port defined in `launchSettings.json`.
5. **Wait for the server to become ready** by polling the base URL (up to 60 seconds):
   ```powershell
   $Ready = $false
   for ($i = 0; $i -lt 30; $i++) {
       Start-Sleep -Seconds 2
       try { Invoke-WebRequest -Uri "$BaseUrl/api/services/app/Session/GetCurrentLoginInformations" -UseBasicParsing -ErrorAction Stop | Out-Null; $Ready = $true; break } catch {}
   }
   if (-not $Ready) { Write-Host "ERROR: Server did not start within 60 seconds. Check the output above for errors." -ForegroundColor Red; exit 1 }
   ```
6. **After tests complete**, stop the server:
   ```powershell
   if ($ServerProcess -and -not $ServerProcess.HasExited) { Stop-Process -Id $ServerProcess.Id -Force }
   ```

**IMPORTANT:** Always use `-NoNewWindow` (not `-RedirectStandardOutput` to a file or `-WindowStyle Hidden`) so that server output is immediately visible in the console for diagnosing startup failures.

### Step 3: Analyze Results

After running the tests, analyze the output for failures. Common error types include:

| Error Type | Description | Typical Fix |
|------------|-------------|-------------|
| **GraphQL Field Conflict** | Property name conflicts with inherited field | Rename the property or add `[GraphQLIgnore]` attribute |
| **Missing DB Column** | Entity property doesn't have corresponding database column | Add a migration to create the column |
| **Entity Not Found** | Entity class not properly registered | Check `[Entity]` attribute and namespace |
| **API Error** | Generic API failure | Check full error details for root cause |

### Step 4: Auto-Fix (if enabled)

If auto-fix is enabled (no `--no-fix` flag), attempt to fix the identified issues:

1. **For GraphQL Field Conflicts:**
   - Search for the conflicting property in the entity file
   - Either rename the property to avoid conflict, or add `[GraphQLIgnore]` attribute if the field shouldn't be exposed

2. **For Missing DB Columns:**
   - Identify the missing column from the error message
   - Create a new migration file in the project's Migrations folder
   - Follow the existing migration pattern (use FluentMigrator)

3. **For Entity Not Found:**
   - Verify the entity has the `[Entity]` attribute with correct TypeShortAlias
   - Check the namespace matches expected pattern

After making fixes, re-run the tests to verify the fix worked.

### Step 5: Report Results

Summarize:
- Total entities tested
- Passed/failed counts
- What was fixed (if auto-fix was enabled)
- Any remaining issues that require manual intervention

## File Locations

- **Skill Scripts:** `<skill-base-dir>/scripts/` (run directly from the skill cache — no project copy needed)
  - `Run-EndpointTests.ps1` - Main test runner (auto-detects project structure, accepts `-RepoRoot`)
  - `Test-Endpoints.ps1` - Endpoint test logic (entity list auto-populated by `-UpdateEntities`)
  - `test-api.cmd` - Batch file wrapper
- **Domain Entities:** Auto-detected from `*.Domain/Domain/` folder
- **Migrations:** Located in the Domain project's `Migrations/` folder

## Example Usage

```
/test-entity-crud-api                           # Run tests with auto-fix enabled
/test-entity-crud-api --no-fix                  # Run tests without auto-fix
/test-entity-crud-api --start-server            # Build, start server, and run tests with auto-fix
/test-entity-crud-api --update-entities         # Scan for new entities, then test with auto-fix
/test-entity-crud-api --no-fix --start-server   # Build, start server, run tests, no auto-fix
```
