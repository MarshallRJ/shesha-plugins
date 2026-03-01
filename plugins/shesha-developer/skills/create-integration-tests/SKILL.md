---
name: create-integration-tests
description: Creates and scaffolds integration test projects for Shesha framework .NET applications. Sets up xUnit test infrastructure with NHibernate, database fixtures, test modules, and base classes. Detects whether Shesha.Testing NuGet package is available and adapts accordingly — using the package when present, or scaffolding local infrastructure when not. Use when the user asks to create, add, scaffold, implement, or set up integration tests, test projects, or test infrastructure for a Shesha project.
---

# Shesha Integration Tests

Scaffolds integration test infrastructure and creates integration tests for Shesha framework applications.

## Step 0: Check for Existing Infrastructure

Before scaffolding, check if a test project already exists:

```
# Look for existing test project
find backend/test/ -name "*Tests.csproj" -type f
# Look for existing test module
grep -rn "SheshaModule" backend/test/ --include="*.cs" -l
# Look for existing test base class
grep -rn "SheshaNhTestBase" backend/test/ --include="*.cs" -l
```

**If test infrastructure already exists**: skip to [Test Generation](#test-generation) (step 9 in Workflow). Read the existing test module and base class to understand the project's patterns, then create new test classes following those patterns.

**If NO test infrastructure exists**: proceed with scaffolding below.

## Step 1: Shesha.Testing Available?

Before generating scaffolding code, determine which path to follow:

1. Check if the project references `Shesha.Testing` as a NuGet package or project reference
2. Check if `Shesha.Testing` namespace is resolvable (grep for `Shesha.Testing` in `.csproj` files)
3. Check if `SheshaTestModuleHelper.ConfigureForTesting` exists in referenced packages

**If Shesha.Testing IS available** (framework version with the package): use the **Framework Path**. See [references/framework-path.md](references/framework-path.md).

**If Shesha.Testing is NOT available** (older framework version): use the **Standalone Path**. See [references/standalone-path.md](references/standalone-path.md).

## Detection Script

```
# Check in the .csproj files of the solution
grep -r "Shesha.Testing" --include="*.csproj" backend/
# Also check NuGet package cache
grep -r "SheshaTestModuleHelper" --include="*.cs" backend/
```

If neither grep returns results, use the Standalone Path.

## Project Structure (both paths)

```
backend/test/{Product}.Common.Domain.Tests/
├── {Product}CommonDomainTestModule.cs   ← SheshaModule, test configuration
├── appsettings.Test.json                ← DB connection + DBMS type
├── log4net.config                       ← Logging config
├── Fixtures/
│   ├── LocalSqlServerCollection.cs      ← xUnit collection definition
│   └── (Standalone only: IDatabaseFixture.cs, LocalSqlServerFixture.cs)
├── DependencyInjection/
│   └── ServiceCollectionRegistrar.cs    ← Identity bridge (standalone only)
├── (Standalone only infrastructure files)
└── *_Tests.cs                           ← Actual test classes
```

## Core Conventions

### Naming
- Test project: `{Product}.Common.Domain.Tests`
- Test module: `{Product}CommonDomainTestModule`
- Namespace: `{Product}.Common.Tests` (infrastructure), `{Product}.Common.Domain.Tests` (test classes)
- Test DB name: `{ProductShort}-IntegrationTest`

### Test Class Pattern
```csharp
[Collection(LocalSqlServerCollection.Name)]
public class {Entity}_Tests : SheshaNhTestBase
{
    private readonly IRepository<{Entity}, Guid> _repo;
    private readonly IUnitOfWorkManager _uowManager;

    public {Entity}_Tests(LocalSqlServerFixture fixture) : base(fixture)
    {
        _repo = Resolve<IRepository<{Entity}, Guid>>();
        _uowManager = Resolve<IUnitOfWorkManager>();
    }

    [Fact]
    public async Task GetAll_Should_Return_{Entities}()
    {
        var id = Guid.NewGuid();

        // Arrange
        using (var uow = _uowManager.Begin())
        {
            await _repo.InsertAsync(new {Entity} { Id = id, /* ... */ });
            await uow.CompleteAsync();
        }

        // Act + Assert
        using (var uow = _uowManager.Begin())
        {
            var all = await _repo.GetAllListAsync();
            all.ShouldContain(e => e.Id == id);
            await uow.CompleteAsync();
        }

        // Cleanup
        using (var uow = _uowManager.Begin())
        {
            await _repo.DeleteAsync(id);
            await uow.CompleteAsync();
        }
    }
}
```

### Key Rules
- Each DB operation in its own `using (var uow = _uowManager.Begin())` block
- Always `await uow.CompleteAsync()` to flush NHibernate
- Use `try/finally` for cleanup when test data has relationships
- Resolve services in constructor via `Resolve<T>()`
- Use `Shouldly` assertions (`ShouldBe`, `ShouldNotBeNull`, `ShouldContain`)
- Unique test data names: `$"{prefix}_{Guid.NewGuid():N}"`

### Test Module DependsOn (minimum)
```csharp
[DependsOn(
    typeof({Product}ApplicationModule),  // Your app module
    typeof({Product}Module),             // Your domain module
    typeof(AbpKernelModule),
    typeof(AbpTestBaseModule),
    typeof(AbpAspNetCoreModule),
    typeof(SheshaApplicationModule),
    typeof(SheshaNHibernateModule),
    typeof(SheshaFrameworkModule),
    typeof(SheshaWorkflowModule)         // Required if any entities reference workflow types
)]
```

**Important:** Include `SheshaWorkflowModule` if domain entities reference any types from `Shesha.Workflow` (e.g. workflow-related entities, approval processes). Without it, NHibernate mapping fails with: `The given key 'Shesha.Workflow, Version=...' was not present in the dictionary`.

### appsettings.Test.json
```json
{
  "DbmsType": "SQLServer",
  "ConnectionStrings": {
    "Default": "Data Source=.;Initial Catalog={ProductShort}-IntegrationTest;Integrated Security=True;TrustServerCertificate=True",
    "TestDB": "Data Source=.;Initial Catalog={ProductShort}-IntegrationTest;Integrated Security=True;TrustServerCertificate=True"
  }
}
```

Both `Default` and `TestDB` keys must be present and identical.

### csproj Essentials
```xml
<PackageReference Include="Abp.Castle.Log4Net" Version="9.0.0" />
<PackageReference Include="Abp.TestBase" Version="9.0.0" />
<PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />
<PackageReference Include="Moq" Version="4.20.70" />
<PackageReference Include="NSubstitute" Version="5.1.0" />
<PackageReference Include="Shouldly" Version="4.2.1" />
<PackageReference Include="xunit" Version="2.6.3" />
<PackageReference Include="xunit.extensibility.execution" Version="2.6.3" />
<PackageReference Include="xunit.runner.visualstudio" Version="2.5.5" />
```

Plus project references to the Application and Domain projects.

### Notification Channel Senders

If the code under test sends notifications (e.g. approval workflows, notification services), you must register concrete `INotificationChannelSender` implementations in `ServiceCollectionRegistrar`. Without this, tests fail with: `NotificationSender waiting for INotificationChannelSender`.

```csharp
// Add to ServiceCollectionRegistrar.Register() before WindsorRegistrationHelper call
services.AddTransient<INotificationChannelSender, EmailChannelSender>();
services.AddTransient<INotificationChannelSender, SmsChannelSender>();
```

Use concrete implementations (not mocks) for integration tests — the goal is to verify the full code path works end-to-end.

## Workflow

### Phase 1: Infrastructure (skip if test project already exists)

1. Check for existing test infrastructure (Step 0 above)
2. Detect Shesha.Testing availability (Step 1 above)
3. Read [references/framework-path.md](references/framework-path.md) or [references/standalone-path.md](references/standalone-path.md)
4. Create the test project directory and csproj
5. Create appsettings.Test.json and log4net.config (copy from [assets/log4net.config](assets/log4net.config))
6. Create the test module class
7. Create fixture and collection classes
8. Create infrastructure files (standalone path only)
9. Add the test project to the solution
10. Build to verify infrastructure compiles

### Phase 2: Test Generation (ALWAYS execute this phase)

This phase runs whether infrastructure was just scaffolded or already existed.

11. **Discover testable targets** — read [references/test-generation.md](references/test-generation.md) for discovery commands and patterns
12. **Scan domain entities** — glob `backend/src/*Domain*/**/*.cs`, grep for entity base classes
13. **Scan application services** — glob `backend/src/*Application*/**/*AppService.cs`
14. **Check existing coverage** — grep for `*_Tests.cs` in the test project, skip entities/services already tested
15. **Create entity CRUD test classes** — one `{Entity}_Tests.cs` per untested entity with at least a `GetAll` test
16. **Create service test classes** — one `{Service}_Tests.cs` per untested service with custom methods
17. **Build and verify** — `dotnet build` the test project to confirm all tests compile

## Test Generation

After infrastructure is confirmed or scaffolded, **always** generate actual test classes. See [references/test-generation.md](references/test-generation.md) for:
- How to discover entities and services to test
- Entity CRUD test template
- Handling entities with required foreign key relationships
- Parent-child cleanup patterns
- Test naming conventions

Key principle: every domain entity gets at least one test class verifying CRUD via repository. Every application service with custom business logic gets a test class exercising its methods.

## Service-Level Test Pattern

For testing application services (not just repositories):

```csharp
[Collection(LocalSqlServerCollection.Name)]
public class Dashboard_Tests : SheshaNhTestBase
{
    private readonly DashboardAppService _dashboardService;
    private readonly IRepository<TestCase, Guid> _testCaseRepo;
    private readonly IUnitOfWorkManager _uowManager;

    public Dashboard_Tests(LocalSqlServerFixture fixture) : base(fixture)
    {
        _dashboardService = Resolve<DashboardAppService>();
        _testCaseRepo = Resolve<IRepository<TestCase, Guid>>();
        _uowManager = Resolve<IUnitOfWorkManager>();
    }

    private string Unique(string prefix) => $"{prefix}_{Guid.NewGuid():N}";

    [Fact]
    public async Task GetKpis_Should_Return_Dashboard_Data()
    {
        Entity entity = null;
        try
        {
            using (var uow = _uowManager.Begin())
            {
                entity = new Entity { Name = Unique("Test"), /* ... */ };
                await _repo.InsertAsync(entity);
                await uow.CompleteAsync();
            }

            using (var uow = _uowManager.Begin())
            {
                var result = await _dashboardService.GetKpis();
                result.ShouldNotBeNull();
                // assertions...
                await uow.CompleteAsync();
            }
        }
        finally
        {
            using (var uow = _uowManager.Begin())
            {
                if (entity != null) await _repo.DeleteAsync(entity);
                await uow.CompleteAsync();
            }
        }
    }
}
```
