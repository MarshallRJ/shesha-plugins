---
name: shesha-workflow
description: Generates Shesha workflow artifacts for .NET applications using ABP framework with NHibernate. Creates workflow instances, definitions, managers, service tasks, extension methods, and FluentMigrator database migrations. Use when the user asks to create, scaffold, or update workflow-related classes, workflow steps, workflow conditions, or workflow database tables in a Shesha project.
---

# Shesha Workflow Code Generation

Generate workflow artifacts for a Shesha/.NET/ABP/NHibernate application based on $ARGUMENTS.

## Instructions

- Inspect nearby files to determine the correct namespace root.
- Use `Guid` as entity ID type. All domain properties must be `virtual`.
- Every workflow requires at minimum: Workflow Instance + Workflow Definition (domain layer).
- Generate a new GUID for `[DiscriminatorValue]` attributes.
- Place files according to the folder structure below.

## Artifact catalog

| # | Artifact | Layer | Template |
|---|----------|-------|----------|
| 1 | Workflow Instance | Domain | [domain-artifacts.md](domain-artifacts.md) §1 |
| 2 | Workflow Definition | Domain | [domain-artifacts.md](domain-artifacts.md) §2 |
| 3 | Workflow Manager | Domain | [domain-artifacts.md](domain-artifacts.md) §3 |
| 4 | Service Task | Application | [service-tasks.md](service-tasks.md) §1 |
| 5 | Generic Base Service Task | Application | [service-tasks.md](service-tasks.md) §2 |
| 6 | Workflow Extensions | Application | [service-tasks.md](service-tasks.md) §3 |
| 7 | Database Migration | Domain | [migrations.md](migrations.md) |

**When generating multiple artifacts**, always create the Instance + Definition pair first, then add Service Tasks per workflow step.

## Folder structure

```
{Module}.Domain/
  Domain/{WorkflowName}Workflows/
    {WorkflowName}Workflow.cs
    {WorkflowName}WorkflowDefinition.cs
    {WorkflowName}WorkflowManager.cs
  Migrations/
    M{YYYYMMDDHHmmss}.cs

{Module}.Application/
  Workflows/
    Common/
      {TaskName}ServiceTaskBase.cs
    {WorkflowNamePlural}/
      {TaskName}ServiceTask.cs
      {WorkflowName}WorkflowExtensions.cs
```

## Quick reference

### Base classes

| Artifact | Base Class |
|----------|-----------|
| Workflow Instance | `WorkflowInstanceWithTypedDefinition<TDefinition>` (`Shesha.Workflow.Domain`) |
| Workflow Definition | `WorkflowDefinition` |
| Workflow Manager | `DomainService` |
| Service Task | `AsyncServiceTask<TWorkflow>` + `ITransientDependency` |
| Generic Base Task | `AsyncServiceTask<TWorkflow> where TWorkflow : WorkflowInstance` |
| Gateway condition ext. | `static class` on `WorkflowInstance` → returns `bool` |
| Action ext. methods | `static class` on typed `{WorkflowName}Workflow` → returns `Task` |
| DB Migration | `Migration` or `OneWayMigration` |

### Key dependencies

| Interface | Namespace | Use |
|-----------|-----------|-----|
| `IWfRunArguments` | `Shesha.Workflow.Services` | Service task `ExecuteAsync` parameter |
| `IWorkflowInstanceRepository` | `Shesha.Workflow.Helpers` | Manager manual instance creation |
| `IProcessDomainService` | `Shesha.Workflow.DomainServices` | Complete user tasks |
| `ILogger<T>` | `Microsoft.Extensions.Logging` | Structured logging in service tasks |

### Key attributes

| Attribute | Used On |
|-----------|---------|
| `[JoinedProperty("TableName")]` | Instance, Definition |
| `[Prefix(UsePrefixes = false)]` | Instance |
| `[Entity(TypeShortAlias = "...")]` | Instance |
| `[DiscriminatorValue("slug")]` | Definition |
| `[Display(Name, Description)]` | Definition, Service Task |
| `[Migration(YYYYMMDDHHmmss)]` | Migration class |

### Service task method signature

```csharp
// CORRECT — returns Task<bool>; workflow passed directly
public override async Task<bool> ExecuteAsync({WorkflowName}Workflow workflow, IWfRunArguments wfRunArguments)
{
    // ... logic ...
    await _workflowRepository.UpdateAsync(workflow);
    return true;
}
// IWfRunArguments from Shesha.Workflow.Services
```

### Common patterns

**Refresh workflow (NHibernate stale state fix):**
```csharp
var sessionProvider = StaticContext.IocManager.Resolve<ISessionProvider>();
sessionProvider.Session.Refresh(workflow);
```

**Sync SubStatus to Model Status:**
```csharp
workflow.Model.Status = ({RefListStatusEnum}?)workflow.SubStatus;
```

**Resolve dependency in extension methods:**
```csharp
var repo = IocManager.Instance.Resolve<IRepository<{Entity}, Guid>>();
```

**Check definition config in a service task:**
```csharp
if (workflow.Definition?.{ConfigFlag} != true)
    return true; // feature disabled — skip silently
```

**Complete a user task programmatically:**
```csharp
var args = new CompleteUserTaskArgs<{WorkflowName}Workflow>
{
    WorkflowTodoItemId = todoItem.Id,
    Comments = comments,
    DecisionUid = decisionUid
};
await _processDomainService.CompleteUserTaskAsync(args);
```

## Migration table naming

| Artifact | Table Name | FK Target |
|----------|-----------|-----------|
| Instance | `{Prefix}_{WorkflowName}Workflows` | `workflow.workflow_instances` |
| Definition | `{Prefix}_{WorkflowName}WorkflowDefinitions` | `workflow.workflow_definitions` |

Module prefixes: `SaGov_`, `Leave_`, `Pmds_`, `Hcm_`, `LB_`

Now generate the requested workflow artifact(s) based on: $ARGUMENTS
