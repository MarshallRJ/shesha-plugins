# Domain Layer Workflow Artifacts

## §1. Workflow Instance

**File:** `{WorkflowName}Workflow.cs` in `Domain/{WorkflowName}Workflows/`

```csharp
using Shesha.Domain.Attributes;
using Shesha.Workflow.Domain;
using System.ComponentModel.DataAnnotations;

namespace {ModuleNamespace}.Domain.{WorkflowName}Workflows
{
    [JoinedProperty("{TablePrefix}_{WorkflowName}Workflows")]
    [Prefix(UsePrefixes = false)]
    [Entity(TypeShortAlias = "{ModuleNamespace}.Domain.{WorkflowName}Workflow")]
    public class {WorkflowName}Workflow : WorkflowInstanceWithTypedDefinition<{WorkflowName}WorkflowDefinition>
    {
        public virtual {ModelEntity} Model { get; set; }
    }
}
```

**With multiple entity references** (e.g. owner + model + related entities):

```csharp
[JoinedProperty("{TablePrefix}_{WorkflowName}Workflows")]
[Prefix(UsePrefixes = false)]
[Entity(TypeShortAlias = "{ModuleNamespace}.Domain.{WorkflowName}Workflow")]
public class {WorkflowName}Workflow : WorkflowInstanceWithTypedDefinition<{WorkflowName}WorkflowDefinition>
{
    public virtual {OwnerEntity} PartOf { get; set; }
    public virtual {ModelEntity} Model { get; set; }
    public virtual {RelatedEntity1} Lead { get; set; }
    public virtual {RelatedEntity2} Opportunity { get; set; }
}
```

**With extra state** (e.g. cancellation context):

```csharp
[JoinedProperty("{TablePrefix}_{WorkflowName}Workflows")]
[Prefix(UsePrefixes = false)]
[Entity(TypeShortAlias = "{ModuleNamespace}.Domain.{WorkflowName}Workflow")]
public class {WorkflowName}Workflow : WorkflowInstanceWithTypedDefinition<{WorkflowName}WorkflowDefinition>
{
    public virtual {ModelEntity} Model { get; set; }
    public virtual bool ApplicationWasRecommended { get; set; }
    public virtual bool ApplicationWasApproved { get; set; }

    [StringLength(4000)]
    public virtual string Comments { get; set; }
}
```

**Key rules:**
- `Model` links to the entity being processed — it is the primary required FK
- Additional FK references (`PartOf`, `Lead`, `Opportunity`, etc.) are allowed when the workflow needs to track multiple related entities
- Do NOT add tracking dates, flags, or notes to the workflow instance; state is managed via `SubStatus`, gateway conditions, and the `Model` entity itself
- Add extra non-FK properties only for workflow-engine state that cannot live on the model (e.g. a single `Comments` string or a recommended/approved flag needed by gateway conditions)
- `[JoinedProperty]` maps to a dedicated DB table (joined subclass)
- `[Prefix(UsePrefixes = false)]` disables column prefix generation
- All properties must be `virtual`

---

## §2. Workflow Definition

**File:** `{WorkflowName}WorkflowDefinition.cs` in `Domain/{WorkflowName}Workflows/`

Always generated alongside a Workflow Instance — they are a mandatory pair.

```csharp
using Shesha.Domain.Attributes;
using Shesha.Workflow.Domain;
using System.ComponentModel.DataAnnotations;

namespace {ModuleNamespace}.Domain.{WorkflowName}Workflows
{
    [DiscriminatorValue("{discriminator-slug}")]
    [JoinedProperty("{TablePrefix}_{WorkflowName}WorkflowDefinitions")]
    [Display(Name = "{Friendly Name} workflow definition")]
    public class {WorkflowName}WorkflowDefinition : WorkflowDefinition
    {
        public override WorkflowInstance CreateInstance()
        {
            return new {WorkflowName}Workflow
            {
                WorkflowDefinition = this,
                RefNumber = AssignReferenceNumber(),
                SubStatus = (long){RefListStatusEnum}.Draft,
                Model = new {ModelEntity}()
            };
        }
    }
}
```

**With session-based initialization** (when model creation needs the current user):

```csharp
public override WorkflowInstance CreateInstance()
{
    var abpSession = StaticContext.IocManager.Resolve<IAbpSession>();
    var userId = abpSession.GetUserId();

    return new {WorkflowName}Workflow
    {
        WorkflowDefinition = this,
        RefNumber = AssignReferenceNumber(),
        Model = new {ModelEntity}
        {
            CreatorUserId = userId,
            // ... other initialization
        }
    };
}
```

Use `StaticContext.IocManager.Resolve<T>()` (not `IocManager.Instance`) inside `WorkflowDefinition.CreateInstance()` — `IocManager.Instance` is for static extension methods.

**With linked owner entity creation** (when the model is owned by a parent entity that must also be created):

```csharp
public override WorkflowInstance CreateInstance()
{
    var abpSession = StaticContext.IocManager.Resolve<IAbpSession>();
    var userId = abpSession.GetUserId();

    var owner = new {OwnerEntity}
    {
        Name = $"{Descriptive name}"
    };

    return new {WorkflowName}Workflow
    {
        WorkflowDefinition = this,
        RefNumber = AssignReferenceNumber(),
        Model = new {ModelEntity}
        {
            PartOf = owner
        }
    };
}
```

Use this when the model entity requires a parent/owner entity (`PartOf`) that is created in the same transaction as the workflow. The owner entity is instantiated first, then referenced on the model — NHibernate will cascade-insert both when the unit of work flushes.

**With processor-based initialization** (complex model setup):

```csharp
public override WorkflowInstance CreateInstance()
{
    var processor = IocManager.Instance.Resolve<{ModelEntity}Processor>();
    var model = AsyncHelper.RunSync(() => processor.InitialiseAsync<{ModelEntity}>());

    return new {WorkflowName}Workflow
    {
        WorkflowDefinition = this,
        RefNumber = AssignReferenceNumber(),
        SubStatus = (long){RefListStatusEnum}.Draft,
        Model = model
    };
}
```

**`CreateInstance()` is ALWAYS required** — it is how the Shesha workflow engine instantiates a new workflow run. Never omit it.

**Rules:**
1. Create the matching Workflow Instance type
2. Set `WorkflowDefinition = this`
3. Assign reference number via `AssignReferenceNumber()`
4. Optionally set `SubStatus` to the initial status (e.g. Draft) if a status RefList exists

**With configuration properties** (SLA settings, feature flags — combined with `CreateInstance()`):

```csharp
[DiscriminatorValue("{discriminator-slug}")]
[JoinedProperty("{TablePrefix}_{WorkflowName}WorkflowDefinitions")]
[Display(Name = "{Friendly Name} Workflow", Description = "{Description}")]
public class {WorkflowName}WorkflowDefinition : WorkflowDefinition
{
    public override WorkflowInstance CreateInstance()
    {
        return new {WorkflowName}Workflow
        {
            WorkflowDefinition = this,
            RefNumber = AssignReferenceNumber()
        };
    }

    // SLA / timeout settings
    public virtual int {TimeoutName}Days { get; set; } = {DefaultDays};
    public virtual int {SLAName}Days { get; set; } = {DefaultDays};

    // Feature flags
    public virtual bool {FeatureFlag} { get; set; } = true;

    // Notification settings
    public virtual bool Send{NotificationType}Notifications { get; set; } = true;
    public virtual int {NotificationType}NotificationDays { get; set; } = {DefaultDays};
}
```

Configuration properties are referenced from service tasks via `workflow.Definition?.{PropertyName}`.

---

## §3. Workflow Manager

**File:** `{WorkflowName}WorkflowManager.cs` in `Domain/{WorkflowName}Workflows/`

Generate when user needs workflow orchestration, status management, or cross-workflow coordination.

```csharp
using Abp.Domain.Repositories;
using Abp.Domain.Services;
using Abp.Domain.Uow;
using Abp.Runtime.Session;
using Abp.UI;
using Shesha.NHibernate;
using Shesha.Workflow.Domain;
using Shesha.Workflow.Domain.Enums;
using Shesha.Workflow.DomainServices;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace {ModuleNamespace}.Domain.{WorkflowName}Workflows
{
    public class {WorkflowName}WorkflowManager : DomainService
    {
        private readonly IRepository<{WorkflowName}Workflow, Guid> _workflowRepository;
        private readonly IRepository<{ModelEntity}, Guid> _modelRepository;
        private readonly IAbpSession _abpSession;
        private readonly ISessionProvider _sessionProvider;
        private readonly IProcessDomainService _processDomainService;

        public {WorkflowName}WorkflowManager(
            IRepository<{WorkflowName}Workflow, Guid> workflowRepository,
            IRepository<{ModelEntity}, Guid> modelRepository,
            IAbpSession abpSession,
            ISessionProvider sessionProvider,
            IProcessDomainService processDomainService)
        {
            _workflowRepository = workflowRepository;
            _modelRepository = modelRepository;
            _abpSession = abpSession;
            _sessionProvider = sessionProvider;
            _processDomainService = processDomainService;
        }

        public async Task<string> CreateSubjectAsync(Guid workflowId)
        {
            var workflow = await _workflowRepository.GetAsync(workflowId);
            var model = workflow.Model
                ?? throw new ArgumentNullException(nameof(workflow.Model));
            return $"{model.Name} — {model.Person?.FullName}";
        }

        public async Task UpdateStatusesAsync(
            Guid workflowId,
            {RefListStatusEnum} subStatus,
            {RefListStatusEnum} modelStatus)
        {
            try
            {
                var workflow = await _workflowRepository.GetAsync(workflowId);
                workflow.SubStatus = (long?)subStatus;
                workflow.Model.Status = modelStatus;
                await _workflowRepository.UpdateAsync(workflow);
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to update statuses for workflow {workflowId}", ex);
                throw;
            }
        }

        public void RefreshWorkflow({WorkflowName}Workflow workflow)
        {
            _sessionProvider.Session.Refresh(workflow);
        }
    }
}
```

**Manager with manual instance creation** (when definition has no `CreateInstance()` — uses `IWorkflowInstanceRepository`):

```csharp
using Shesha.Workflow.Helpers;
...
public class {WorkflowName}WorkflowManager : DomainService
{
    private readonly IRepository<{WorkflowName}Workflow, Guid> _workflowRepository;
    private readonly IRepository<{WorkflowName}WorkflowDefinition, Guid> _definitionRepository;
    private readonly IRepository<{ModelEntity}, Guid> _modelRepository;
    private readonly IWorkflowInstanceRepository _workflowInstanceRepository;

    public {WorkflowName}WorkflowManager(
        IRepository<{WorkflowName}Workflow, Guid> workflowRepository,
        IRepository<{WorkflowName}WorkflowDefinition, Guid> definitionRepository,
        IRepository<{ModelEntity}, Guid> modelRepository,
        IWorkflowInstanceRepository workflowInstanceRepository)
    {
        _workflowRepository = workflowRepository;
        _definitionRepository = definitionRepository;
        _modelRepository = modelRepository;
        _workflowInstanceRepository = workflowInstanceRepository;
    }

    public virtual async Task<{WorkflowName}Workflow> StartAsync(Guid modelId)
    {
        var model = await _modelRepository.GetAsync(modelId);

        // Guard: no duplicate active workflow
        var existing = _workflowRepository.GetAll()
            .Where(w => w.Model.Id == modelId
                     && w.Status != WorkflowStatus.Cancelled
                     && w.Status != WorkflowStatus.Completed)
            .FirstOrDefault();
        if (existing != null)
            throw new UserFriendlyException($"Active workflow already exists for '{model.Name}'.");

        var definition = await _definitionRepository.GetAll()
            .Where(d => d.IsLast)
            .FirstOrDefaultAsync()
            ?? throw new UserFriendlyException("{WorkflowName} workflow definition not configured.");

        var workflow = new {WorkflowName}Workflow
        {
            Model = model,
            Definition = definition,
            Status = WorkflowStatus.InProgress,
            Name = $"{Friendly Name} - {model.Name}"
        };

        await _workflowRepository.InsertAsync(workflow);
        await CurrentUnitOfWork.SaveChangesAsync();
        return workflow;
    }

    public virtual async Task<{WorkflowName}Workflow> GetActiveAsync(Guid modelId)
    {
        return _workflowRepository.GetAll()
            .Where(w => w.Model.Id == modelId
                     && w.Status == WorkflowStatus.InProgress)
            .OrderByDescending(w => w.CreationTime)
            .FirstOrDefault();
    }

    public virtual async Task EnsureNoActiveWorkflowAsync(Guid modelId)
    {
        if (await GetActiveAsync(modelId) != null)
            throw new UserFriendlyException("An active workflow already exists.");
    }
}
```

**For generic/reusable managers** (extending a framework base):

```csharp
public class {WorkflowName}WorkflowManager
    : FrameworkWorkflowManager<{WorkflowName}WorkflowDefinition, {WorkflowName}Workflow, {ModelEntity}>
{
    public {WorkflowName}WorkflowManager(/* base params */) : base(/* pass through */) { }
}
```

**Manager responsibilities:** subject generation, status sync between `SubStatus` and model `Status`, NHibernate session refresh, cross-workflow coordination, duplicate active workflow guard, completing user tasks via `IProcessDomainService`.
