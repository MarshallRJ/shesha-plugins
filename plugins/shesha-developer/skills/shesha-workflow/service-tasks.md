# Application Layer Workflow Artifacts

## §1. Service Task

**File:** `{TaskName}ServiceTask.cs` in `Workflows/{WorkflowNamePlural}/`

A single automated step in a workflow. The engine instantiates and executes it when reaching the matching node.

```csharp
using Abp.Dependency;
using Abp.Domain.Repositories;
using Microsoft.Extensions.Logging;
using Shesha.Workflow.Domain;
using Shesha.Workflow.Services;
using System;
using System.ComponentModel.DataAnnotations;
using System.Threading.Tasks;

namespace {ModuleNamespace}.Application.Workflows.{WorkflowNamePlural}
{
    [Display(Name = "{Friendly Task Name}",
             Description = "{Brief description}")]
    public class {TaskName}ServiceTask : AsyncServiceTask<{WorkflowName}Workflow>, ITransientDependency
    {
        private readonly IRepository<{WorkflowName}Workflow, Guid> _workflowRepository;
        private readonly ILogger<{TaskName}ServiceTask> _logger;

        public {TaskName}ServiceTask(
            IRepository<{WorkflowName}Workflow, Guid> workflowRepository,
            ILogger<{TaskName}ServiceTask> logger)
        {
            _workflowRepository = workflowRepository;
            _logger = logger;
        }

        public override async Task<bool> ExecuteAsync({WorkflowName}Workflow workflow, IWfRunArguments wfRunArguments)
        {
            // Task logic here

            await _workflowRepository.UpdateAsync(workflow);
            return true;
        }
    }
}
```

**Key rules:**
- Override `ExecuteAsync`, NOT `RunAsync` — return `Task<bool>` (`true` = success)
- `IWfRunArguments` comes from `Shesha.Workflow.Services`
- The workflow instance is passed directly — no `context.WorkflowInstance` indirection
- Inject `ILogger<T>` for structured logging

### Common task patterns

**(a) Update Model Status:**
```csharp
public override async Task<bool> ExecuteAsync({WorkflowName}Workflow workflow, IWfRunArguments wfRunArguments)
{
    RefreshWorkflow(workflow);
    workflow.Model.Status = ({RefListStatusEnum}?)workflow.SubStatus;
    await _workflowRepository.UpdateAsync(workflow);
    return true;
}
```

**(b) Update Subject:**
```csharp
public override async Task<bool> ExecuteAsync({WorkflowName}Workflow workflow, IWfRunArguments wfRunArguments)
{
    RefreshWorkflow(workflow);
    if (workflow.Subject == null)
        workflow.Subject = await _workflowManager.CreateSubjectAsync(workflow.Id);
    await _workflowRepository.UpdateAsync(workflow);
    return true;
}
```

**(c) Business Logic Delegation:**
```csharp
public override async Task<bool> ExecuteAsync({WorkflowName}Workflow workflow, IWfRunArguments wfRunArguments)
{
    var model = workflow.Model
        ?? throw new InvalidOperationException("Workflow model is null");
    await _businessManager.ProcessAsync(model.Id);
    return true;
}
```

**(d) Cross-Workflow Action:**
```csharp
public override async Task<bool> ExecuteAsync({CancellationWorkflow}Workflow workflow, IWfRunArguments wfRunArguments)
{
    var originalWorkflow = await _originalWorkflowRepository.GetAll()
        .Where(w => w.Model.Id == workflow.Model.Parent.Id
                  && w.Model.RequestType == RefListRequestType.Application)
        .FirstOrDefaultAsync()
        ?? throw new ArgumentNullException("Original workflow not found");

    await _manager.CancelAsync(originalWorkflow.Id);
    await _workflowManager.UpdateStatusesAsync(
        originalWorkflow.Id, RefListStatus.Cancelled, RefListStatus.Cancelled);
    return true;
}
```

**(e) With structured logging and error handling:**
```csharp
public override async Task<bool> ExecuteAsync({WorkflowName}Workflow workflow, IWfRunArguments wfRunArguments)
{
    try
    {
        _logger.LogInformation("Processing {ApplicationNumber}", workflow.Model?.ApplicationNumber ?? "Unknown");

        // business logic

        await _workflowRepository.UpdateAsync(workflow);
        _logger.LogInformation("Completed successfully for {ApplicationNumber}", workflow.Model?.ApplicationNumber);
        return true;
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error processing {ApplicationNumber}", workflow.Model?.ApplicationNumber);
        throw;
    }
}
```

**(f) Check definition config before acting:**
```csharp
public override async Task<bool> ExecuteAsync({WorkflowName}Workflow workflow, IWfRunArguments wfRunArguments)
{
    if (workflow.Definition?.{ConfigFlag} != true)
    {
        _logger.LogInformation("{ConfigFlag} is disabled — skipping");
        return true;
    }

    // conditional logic
    await _workflowRepository.UpdateAsync(workflow);
    return true;
}
```

---

## §2. Generic Base Service Task

**File:** `{TaskName}ServiceTaskBase.cs` in `Workflows/Common/`

Abstract base for tasks sharing logic across multiple workflow types (Template Method pattern).

```csharp
using Abp.Dependency;
using Abp.Domain.Repositories;
using Shesha.Workflow.Domain;
using Shesha.Workflow.Services;
using System;
using System.Threading.Tasks;

namespace {ModuleNamespace}.Application.Workflows.Common
{
    public abstract class {TaskName}ServiceTaskBase<TWorkflow> : AsyncServiceTask<TWorkflow>, ITransientDependency
        where TWorkflow : WorkflowInstance
    {
        private readonly IRepository<TWorkflow, Guid> _workflowRepository;
        private readonly IRepository<{ModelEntity}, Guid> _modelRepository;

        protected {TaskName}ServiceTaskBase(
            IRepository<TWorkflow, Guid> workflowRepository,
            IRepository<{ModelEntity}, Guid> modelRepository)
        {
            _workflowRepository = workflowRepository;
            _modelRepository = modelRepository;
        }

        protected abstract {ModelEntity} GetModel(TWorkflow workflow);

        public override async Task<bool> ExecuteAsync(TWorkflow workflow, IWfRunArguments wfRunArguments)
        {
            var model = GetModel(workflow)
                ?? throw new InvalidOperationException(
                    $"Model is null on workflow {workflow.Id}");

            // Shared business logic here

            return true;
        }
    }
}
```

**Concrete implementation** per workflow type:

**File:** `{TaskName}ServiceTask.cs` in `Workflows/{WorkflowNamePlural}/`

```csharp
using Abp.Domain.Repositories;
using {ModuleNamespace}.Application.Workflows.Common;
using System;

namespace {ModuleNamespace}.Application.Workflows.{WorkflowNamePlural}
{
    public class {TaskName}ServiceTask : {TaskName}ServiceTaskBase<{WorkflowName}Workflow>
    {
        public {TaskName}ServiceTask(
            IRepository<{WorkflowName}Workflow, Guid> workflowRepository,
            IRepository<{ModelEntity}, Guid> modelRepository)
            : base(workflowRepository, modelRepository)
        {
        }

        protected override {ModelEntity} GetModel({WorkflowName}Workflow workflow)
            => workflow.Model;
    }
}
```

---

## §3. Workflow Extension Methods

**File:** `{WorkflowName}WorkflowExtensions.cs` in `Workflows/{WorkflowNamePlural}/`

Two patterns — choose based on use case.

### (A) Gateway conditions — extend `WorkflowInstance`

Used by the workflow engine for routing decisions. Must extend the base `WorkflowInstance` type.

```csharp
using Abp.Dependency;
using Abp.Domain.Repositories;
using Shesha.Workflow.Domain;
using System;
using System.Linq;

namespace {ModuleNamespace}.Application.Workflows.{WorkflowNamePlural}
{
    public static class {WorkflowName}WorkflowExtensions
    {
        public static bool {ConditionName}(this WorkflowInstance workflow)
        {
            if (workflow == null)
                throw new ArgumentNullException(nameof(workflow));

            var workflowRepo = IocManager.Instance
                .Resolve<IRepository<{WorkflowName}Workflow, Guid>>();

            var typedWorkflow = workflowRepo.FirstOrDefault(workflow.Id);
            if (typedWorkflow?.Model == null)
                return false;

            var relatedRepo = IocManager.Instance
                .Resolve<IRepository<{RelatedEntity}, Guid>>();

            return relatedRepo.GetAll()
                .Where(x => x.PartOf != null && x.PartOf.Id == typedWorkflow.Model.Id)
                .Any(x => /* condition logic */);
        }

        // Checking definition configuration:
        public static bool {ConfigFlag}(this WorkflowInstance workflow)
        {
            if (workflow == null)
                throw new ArgumentNullException(nameof(workflow));

            var workflowRepo = IocManager.Instance
                .Resolve<IRepository<{WorkflowName}Workflow, Guid>>();
            var typedWorkflow = workflowRepo.FirstOrDefault(workflow.Id)
                ?? throw new InvalidOperationException($"Workflow {workflow.Id} not found");

            var definitionRepo = IocManager.Instance
                .Resolve<IRepository<{WorkflowName}WorkflowDefinition, Guid>>();
            var definition = definitionRepo.FirstOrDefault(typedWorkflow.WorkflowDefinition.Id);

            return definition?.{ConfigFlag} ?? false;
        }
    }
}
```

### (B) Action methods and state queries — extend typed workflow

For programmatic use from service tasks, managers, or application services. Extends the specific workflow type directly.

```csharp
using Abp.Dependency;
using Abp.Domain.Repositories;
using System;
using System.Threading.Tasks;

namespace {ModuleNamespace}.Application.Workflows.{WorkflowNamePlural}
{
    public static class {WorkflowName}WorkflowExtensions
    {
        // State-mutating action (async)
        public static async Task {ActionName}Async(this {WorkflowName}Workflow workflow, string reason = null)
        {
            var repo = IocManager.Instance.Resolve<IRepository<{WorkflowName}Workflow, Guid>>();
            workflow.{StateProperty} = "{NewValue}";
            workflow.{DateProperty} = DateTime.Now;
            if (!string.IsNullOrEmpty(reason))
                workflow.Notes = $"{workflow.Notes}\n\n{DateTime.Now:yyyy-MM-dd HH:mm}: {reason}".Trim();
            await repo.UpdateAsync(workflow);
        }

        // Derived state check (bool — can also be used as gateway condition on typed workflow)
        public static bool {IsCondition}(this {WorkflowName}Workflow workflow)
        {
            if (!workflow.{DateProperty}.HasValue)
                return false;

            var thresholdDays = workflow.Definition?.{ThresholdConfig} ?? {DefaultDays};
            return DateTime.Now > workflow.{DateProperty}.Value.AddDays(thresholdDays);
        }

        // Computed value
        public static int? {ComputedValue}(this {WorkflowName}Workflow workflow)
        {
            if (!workflow.{DateProperty}.HasValue)
                return null;
            return (workflow.{DateProperty}.Value - DateTime.Now).Days;
        }
    }
}
```

**Key rules:**
- Gateway conditions (Pattern A): extend `WorkflowInstance`, return `bool`, use `IocManager.Instance.Resolve<T>()`, defensive null-checks returning `false`
- Action methods (Pattern B): extend the typed workflow, return `Task`, use `IocManager.Instance.Resolve<T>()` for repos
- Name boolean methods as questions: `IsConsentExpired`, `ShouldSendExpiryNotification`
- Name action methods as verbs: `GrantConsentAsync`, `DeclineConsentAsync`, `CompleteVerificationAsync`
