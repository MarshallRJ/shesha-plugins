# Domain Modelling Guidelines

## Contents
- [Solution Structure](#solution-structure)
- [Reuse Existing Framework Capabilities](#reuse-existing-framework-capabilities)
- [Reuse Existing Entities](#reuse-existing-entities)
- [Choosing the Right Base Class](#choosing-the-right-base-class-for-new-entities)
- [Entity Class Attributes](#entity-class-attributes)
- [Entity Class Property Attributes](#entity-class-property-attributes)
- [String Property Length Guidelines](#string-property-length-guidelines)
- [The virtual Keyword](#the-virtual-keyword)
- [Child Entities](#child-entities)
- [Sample Entity Class](#sample-entity-class)
- [Placement of Files](#placement-of-files)

## Solution Structure
- All domain related classes should be placed under the Domain folder and organized into appropriate namespaces and folders to reflect their purpose and usage within the application.
- Only classes and enums that are shared across a number of different entities and purposes should be placed directly in the Domain folder.
- All enums, value objects and JSONEntities specific to an entity should be placed within the same namespace as the entity.
- All child entities belonging to an aggregate should be placed within the same namespace as the aggregate root.

## Shesha Domain Modelling Best Practices and Guidelines

### Reuse Existing Framework Capabilities
The Shesha framework already contains rich capabilities for audit logging and role based access control (RBAC) which should be leveraged when considering the design of a new domain instead of reinventing the wheel. Any proposed system design should therefore seek to leverage the following capabilities rather than including additional entities for the purposes:

#### Role and Permission Based Access Control
The following entities are provided by the Shesha framework to enforce Role and Permission Based Access Control and should not be duplicated in any domain designs.

| Entity Name | Description |
| --- | --- |
| `ShaRole` | Defines a system role. |
| `ShaPermission` | Defines a permission. |
| `ShaRolePermission` | Specifies which permissions are associated with which Role. |
| `ShaRoleAppointedPerson` | Specifies which Roles are appointed to which Person or User. |

Since the Shesha framework already supports role based security and access control you should not model any additional entities to support this.

### Reuse Existing Entities
The Shesha framework provides various standard entities around which important functionality is already built. When designing a domain model you should see if these entities and capabilities may be reused and extended rather than duplicating them.

#### Shesha.Core Entities
The base `Shesha.Core` domain model includes the following entities that may be reused and extended:

| Entity Name | Description |
| --- | --- |
| `Account` | Represents a customer account, whether on behalf of a person or organisation. |
| `Address` | Represents an address. |
| `Organisation` | Represents an organizational unit, organisation/company, team or similar. |
| `Person` | Represents a person in the application such as employee, customer, contact, etc. A Person is not necessarily a system user as this will depend on whether there is a corresponding `User` for Person. |
| `Note` | Represents a user note or comment. A list of notes may be associated with any parent entity. |
| `ReferenceList` and `ReferenceListItem` | Represents a standard list of values. |
| `Site` | Represents a geographic location or physical structure such as location, area, buildings, room etc. |
| `StoredFile` | Represents a file stored in the system. |

##### Extending the Person Entity
If the Shesha application or module is intended to be built for reuse by other developers, it is often preferable not to extend the `Person` entity by sub-classing it to include role-specific properties. Instead, a separate Profile entity referencing the `Person` entity should be created, where the profile entity would include the relevant properties.

```csharp
public class LeaveProfile : FullAuditedEntity<Guid>
{
    public virtual Person PartOf { get; set; }
    public virtual int AvailableLeaveDays { get; set; }
}
```

#### Reusing entities from other modules
To avoid duplicating in your design, entities which may already be provided for in other modules already included in the solution you are intended to help design. If the user has not indicated the modules that the solution requires, do ask and clarify whether any other modules are included that should be considered incorporated into the design.
If modules are specified, do encourage the user to upload the domain model of those modules, so that you do not duplicate any such entity or other reference.

### Choosing the Right Base Class for new Entities
Any new entities that need to be defined ultimately need to inherit from `Entity<TId>` where TId is the type of the Id property and should be `Guid` by default.
- You may however also inherit from other pre-existing sub-classes of `Entity` depending of the level of auditing required:
 - Entities that do not generally get updated after the initial creation should inherit from `CreationAuditedEntity<TId>`.
 - Entities that may get updated but not deleted should inherit from `AuditedEntity<TId>` as it will track modification timestamp and user
 - Most entities should inherit from `FullAuditedEntity<TId>` which will track creation, update and deletion users and timestamps.

### Entity Class Attributes

The following class level attributes should be added to entity classes where relevant.

| **Attribute** | **Description**  |
| --- | --- |
| `[Audited]` | Add to any entity class to enable auditing. When applied at the class level, all properties on the entity will be audited, meaning that any changes to their values will be logged. |
| `[Discriminator]` | Add to any entity that you expect to inherit from so that a Discriminator column can be added at the database layer. By default, Shesha uses a 'Table per Hierarchy' inheritance strategy. This means that all entity subclasses will be stored in the same table as the base class, and a discriminator column will be used to identify the type of entity being stored. |
| `[DiscriminatorValue("DiscriminatorName")]` | Add this attribute to entities that inherit from another entity class and where you want to explicitly specify your own discriminator value. If omitted, Shesha will use the entity class's namespace and name, e.g., `MyOrg.MyApp.` |
| `[Entity]` | Provides parameters to add additional metadata to the entity and control additional aspects of the behavior of the entity: <br/> **`GenerateApplicationService`** - Specifies whether CRUD APIs for this entity should be generated. <br/> **`ApplicationServiceName`** - The name of the application service to be generated for the entity. This will be reflected in the URL of the dynamically generated CRUD API. If not specified, the name of the entity will be used. <br/> **`FriendlyName`** - A more user-friendly name for the entity to be used in the UI. If not specified, the name of the entity will be used. <br/> |
| `[Table("TableName")]` | Add this attribute if the Database table the entity maps to deviates from standard naming conventions. |
| `[AddToMetadata]` | This attribute can mainly be used to forcibly add a DTO that has not been utilized on any service in the application to the list of models available to be used on the frontend. |

### Entity Class Property Attributes
The following property level attributes should be added to entity class properties where relevant.

| **Attribute** | **Description** |
| --- | --- |
| `[Audited]` | Add this attribute to any property that you want to be audited. |
| `[CascadeUpdateRules]` | Applies to properties that reference other entities to specify if updates and create actions should be cascaded to the referenced entity. |
| `[Description("Description of Property name")]` | Description of Class/Property Name. |
| `[Encrypt]` | Add to properties that should be persisted in the database as an encrypted string. |
| `[EntityDisplayName]` | Specifies the property that represents the entity's display name to users. If not explicitly defined, the framework defaults to using a property named 'Name,' if it exists. |
| `[InverseProperty("ColumnName")]` | Specifies the name of the DB column on the other side of a one-to-many relationship. Add this attribute on any property listing entities that reference it. For example, if you have a `Customer` entity with a collection of `Orders`, you would use this attribute on the `Orders` property to specify the `Customer` property on the `Order` entity, e.g., `[InverseProperty("CustomerId")]` or `[InverseProperty(nameof(Order.Customer) + "Id")]` is more robust. |
| `[NotMapped]` | Identifies properties that Shesha should not attempt to map to the database for read or write purposes. Add this attribute for calculated properties at the application level. |
| `[ReadonlyProperty]` | Add this attribute to any properties that map to the database but should not be updated by the application layer such as calculated columns at the database level. |
| `[ReferenceList("RefListName", optional moduleName)]` | Add this to `int` or `long` properties that are associated with a reference list. DO NOT add this attribute when the property returns an enum based reference list as it is redundant. |
| `[Required]` | Add to properties that are mandatory. |
| `[StringLength(maxLength)] / [StringLength(minLength, maxLength)]` | Used to specify a field length (in number of bytes required to store the string) that needs to be limited to a maximum length or both minimum and maximum lengths. Its default parameter is maxLength and is used by properties with the _string_ data type. |
| `[SaveAsJson]` | Applies to properties that reference child objects and causes them to be saved in the database as a JSON string rather than as a regular entity. |

### String Property Length Guidelines

When defining string properties, choose the appropriate length constraint based on the expected content:

| Scenario | Entity Attribute | Migration Column | Example Properties |
| --- | --- | --- | --- |
| **Standard text** (names, titles, codes) | No length constraint | `.AsString().Nullable()` | `Name`, `Title`, `Code` |
| **Longer text** (descriptions, comments) | `[StringLength(5000)]` | `.AsString(5000).Nullable()` | `Description`, `Content`, `Comment` |
| **Unlimited text** (document bodies, large JSON) | `[MaxLength]` | `.AsString(int.MaxValue).Nullable()` | `DocumentBody`, `RawPayload` |

Prefer specific lengths over `[MaxLength]` for better database performance, storage efficiency, and clearer validation boundaries. Only use `[MaxLength]` when content genuinely requires unlimited length.

### The virtual Keyword

All entity properties MUST be declared `virtual`. This is required by NHibernate (Shesha's ORM) to enable lazy loading and change tracking via runtime proxies. Omitting `virtual` will cause runtime errors.

```csharp
// Correct
public virtual string Name { get; set; }
public virtual Person AssignedTo { get; set; }

// Wrong - will cause NHibernate runtime errors
public string Name { get; set; }
public Person AssignedTo { get; set; }
```

### Child Entities
Child entities belonging to an aggregate should:
 - Be placed in the same namespace and folder location as its aggregate
 - Have a property called `PartOf` at the top of the class referencing its parent entity

### Special Child Entities
Because it is such a common requirement to allow attachments and notes to be associated with any entity, the Shesha framework supports this out of the box.
As such it is NOT necessary to add `IList<StoredFile>` or `IList<Note>` or similar collections to any entity to indicate that attachments or notes may be added to a specific entity.

### File and Document Management

The Shesha framework provides comprehensive built-in file management through the `StoredFile` entity, `StoredFileVersion` entity, `IStoredFileService`, and `StoredFileController`. **You MUST leverage these framework capabilities** instead of implementing custom file storage, upload/download endpoints, or file tracking entities.

#### Why Use the Framework's File Management

- **Storage-agnostic**: Automatically works with whatever storage backend is configured (local filesystem, Azure Blob Storage, etc.) — no code changes needed when switching.
- **Versioning and audit trails**: Built-in support for file version history and full audit logging (created/modified by/when).
- **Thumbnail generation**: Built-in endpoint for generating image thumbnails with configurable fit options.
- **UI integration**: Native support on Shesha forms through `File` and `FileList` components that bind directly to `StoredFile` entity properties.
- **Download tracking**: Built-in tracking of which users have downloaded which file versions.
- **Multi-tenant isolation**: Automatic tenant isolation on all file entities.
- **Soft delete**: Full soft-delete support with the ability to restore.

#### Pattern 1: Single File Property (Direct Reference)

When an entity needs a single associated file (e.g. a profile photo, a signed document), add a `StoredFile` property directly on the entity and decorate it with the `[StoredFile]` attribute.

```csharp
using Shesha.Domain;
using Shesha.Domain.Attributes;

public class Employee : FullAuditedEntity<Guid>
{
    [StoredFile(IsVersionControlled = true)]
    public virtual StoredFile Photo { get; set; }

    [StoredFile]
    public virtual StoredFile SignedContract { get; set; }
}
```

The `[StoredFile]` attribute accepts the following parameters:

| Parameter | Description |
| --- | --- |
| `IsVersionControlled` | If `true`, full version history is maintained. If `false` (default), only the current version is kept. |
| `IsEncrypted` | If `true`, the file content is stored encrypted. |
| `Accept` | MIME type restrictions (e.g. `"image/*"`, `"application/pdf"`). |

The framework's `StoredFileController` Upload and CreateOrUpdate endpoints handle uploading to these properties automatically — the caller specifies the `ownerType`, `ownerId`, and `propertyName` and the framework resolves the property, creates/updates the `StoredFile`, and persists the content.

**Database migration for a StoredFile property:**

```csharp
// StoredFile is a separate entity — add a foreign key column
Create.Column("PhotoId").OnTable("MyModule_Employees").AsGuid().Nullable()
    .ForeignKey("FK_MyModule_Employees_PhotoId", "frwk.stored_files", "Id");
```

#### Pattern 2: Multiple File Attachments (Owner-Based)

When an entity needs a list of file attachments (e.g. supporting documents on an application, photos on an inspection), use the framework's **Owner** pattern. No collection property is needed on the entity.

The `StoredFile` entity has an `Owner` property (`GenericEntityReference`) that links any file to any entity via `OwnerType` (the entity's full class name) and `OwnerId` (the entity's ID). Files can optionally be organized into categories via the `Category` property.

**No entity changes required** — simply use the existing `StoredFileController` endpoints:

| Endpoint | Purpose |
| --- | --- |
| `PUT /api/StoredFile` | Upload/create a file linked to an owner entity |
| `POST /api/StoredFile/Upload` | Upload a file as an attachment to an owner |
| `GET /api/StoredFile/FilesList` | Get all files attached to an entity (optionally filtered by category) |
| `GET /api/StoredFile/Download` | Download a file by ID |
| `GET /api/StoredFile/DownloadZip` | Download all attachments for an entity as a zip archive |
| `GET /api/StoredFile/DownloadThumbnail` | Download a resized thumbnail of an image file |
| `DELETE /api/StoredFile` | Delete a file by ID |
| `DELETE /api/StoredFile/Delete` | Delete a file by owner reference |
| `POST /api/StoredFile/UploadNewVersion` | Upload a new version of an existing file |
| `GET /api/StoredFile/StoredFile/{fileId}/Versions` | Get version history for a file |

**Using categories to organize attachments:**

```csharp
// No changes to the entity — files are linked via Owner and categorized
// The frontend FileList component handles category-based grouping automatically

// In a service, query attachments by category using IStoredFileService:
var supportingDocs = await _storedFileService.GetAttachmentsOfCategoryAsync(
    entity.Id, entity.GetType().StripCastleProxyType().GetRequiredFullName(), "supportingDocuments");
```

#### Pattern 3: Child Entity Referencing StoredFile

When you need additional metadata about a file beyond what `StoredFile` provides (e.g. a specific relationship context), create a child entity that references `StoredFile` rather than duplicating file storage:

```csharp
// From Shesha.Core — NotificationMessageAttachment references StoredFile
public class NotificationMessageAttachment : FullAuditedEntity<Guid>
{
    /// <summary>
    /// Name override for the file
    /// </summary>
    [MaxLength(300)]
    public virtual string FileName { get; set; }

    /// <summary>
    /// Reference to the stored file (managed by the framework)
    /// </summary>
    public virtual StoredFile File { get; set; }

    /// <summary>
    /// Parent message this attachment belongs to
    /// </summary>
    public virtual NotificationMessage Message { get; set; }
}
```

#### What NOT to Do

- **Do NOT** create custom entities to store file metadata (file name, file size, file type, upload date, etc.) — `StoredFile` and `StoredFileVersion` already track all of this.
- **Do NOT** create custom upload/download API endpoints — use the framework's `StoredFileController`.
- **Do NOT** add `IList<StoredFile>` collection properties to entities — use the Owner-based pattern instead.
- **Do NOT** implement custom file storage logic (writing to disk, Azure blobs, etc.) — `IStoredFileService` handles this based on configuration.
- **Do NOT** implement custom file versioning — set `IsVersionControlled = true` on the `StoredFile` and use `UploadNewVersion`.
- **Do NOT** implement custom thumbnail generation — use the `DownloadThumbnail` endpoint.

#### When Custom File Handling Is Acceptable

Custom file management should **only** be implemented if the framework's capabilities genuinely cannot support the use case, such as:

- Integrating with an external document management system (e.g. SharePoint, Google Drive) that requires its own API.
- Processing files in a format or workflow not supported by the framework (e.g. real-time streaming, chunk-based uploads for very large files).
- Bulk file import/export with custom transformation logic.

Even in these cases, consider storing the resulting files back into `StoredFile` for consistency and UI integration.

### Sample Entity Class

The sample below illustrates a typical entity class following the guidelines.

<example>

```csharp
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using Abp.Domain.Entities.Auditing;
using Shesha.Domain;
using Shesha.Domain.Attributes;

namespace MyApp.AccountsPayable.Domain.PaymentBatches
{
    /// <summary>
    /// A Payment made to a supplier belonging to a batch.
    /// </summary>
    [Discriminator]
    public class Payment: FullAuditedEntity<Guid>
    {
        public virtual PaymentBatch PartOf { get; set; }

        public virtual Account Supplier { get; set; }

        [Audited]
        public virtual decimal Amount { get; set; }

        [ReferenceList("PaymentServiceCategory")]
        public virtual long? ServiceCategory { get; set; }

        [Audited]
        public virtual RefListPaymentStatus Status { get; set; }

        [StringLength(2000)]
        [Audited]
        public virtual string Description { get; set; }

        [EntityDisplayName]
        [ReadonlyProperty]
        [Description("DB calculated property concatenating the Category and Description")]
        public virtual string CategoryWithDescription { get; set; }

    }
}

```
</example>

The example below demonstrates a standard entity class that adheres to our development guidelines, including the use of the GenerateApplicationService parameter on the Entity attribute (possible values: UseConfiguration, AlwaysGenerateApplicationService, DisableGenerateApplicationService) controlling where the CRUD operations are generated.

<example>

```csharp
using System;
using Abp.Domain.Entities.Auditing;
using Shesha.Domain.Attributes;

namespace MyApp.AccountsPayable.Domain.PaymentBatches
{
    /// <summary>
    /// A Payment made to a supplier belonging to a batch.
    /// </summary>
    [Discriminator]
    [Entity(GenerateApplicationService = GenerateApplicationServiceState.AlwaysGenerateApplicationService, FriendlyName = "Payment Gateway")]
    public class PaymentGateway: FullAuditedEntity<Guid>
    {

    }
}
```

</example>

This allows developers to control whether an application service should always be generated, follow the default configuration, or be explicitly disabled.

## Placement of Files
- Aggregate roots should be placed within their own namespace and folder under the Domain folder.
  - The name of the folder should be a pluralized version of the entity
  - For example, the `Vehicle` entity in a solution where the root namespace is `MyOrg.MyApp` would be placed in the namespace `MyOrg.MyApp.Domain.Vehicles` and corresponding folder.
- Child entities should be placed in the same namespace and folder as their parent entity.
  - For example, if `Wheel` is a child entity of `Vehicle` in the previous example, it should also be placed under `MyOrg.MyApp.Domain.Vehicles`.
- Reference List enums should be placed in the same folder as the entity that uses them.
- Database migration classes should be placed in a folder named `Migrations` within the module that contains the entity.
