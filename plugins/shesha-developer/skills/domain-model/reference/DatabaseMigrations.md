# Database Migration Guidelines

## Contents
- [Creating Database Migrations](#creating-database-migrations)
- [Domain to DB Object Naming Mappings](#domain-to-db-object-naming-mappings)
- [Creating Tables](#creating-tables)
- [Adding Discriminator Columns for Inheritance](#adding-discriminator-columns-for-inheritance)
- [Adding Columns for GenericEntityReference](#adding-columns-for-genericentityreference)
- [Adding Foreign Key Columns](#adding-foreign-key-columns)
- [Altering Existing Tables](#altering-existing-tables)
- [Custom SQL Queries](#custom-sql-queries)

The Shesha framework persists its domain using NHibernate as its ORM. Whenever the domain is updated, the underlying database model also needs to be updated.

Updating the database model is done through Database Migrations based on Fluent Migrator with Shesha-specific extensions.

## Creating Database Migrations

To ensure that your new entity can be persisted to the database, the database should be updated to match the domain model whenever the domain model is updated through the creation of database migration classes.
Shesha uses Fluent Migrator for database migrations with additional Shesha-specific extensions.

### Migration ID Naming Convention

The migration number must be unique across all migrations in the application and usually follows the format: `YYYYMMDDHHMMSS` (Year, Month, Day, Hour, Minute, Second). This ensures migrations are executed in the correct order.

### Important Guidelines

1. **Always inherit from `OneWayMigration`**, not from `Migration`, unless there's a specific requirement to implement the `Down` method.
2. **Always make properties nullable in database migrations** unless specifically required to be not null.
3. **Do not create database migration logic for enum-based Reference Lists** as the Shesha framework automatically adds the relevant values in the database during the bootstrapping process.
4. Always make sure to include the `Shesha.FluentMigrator` and `Shesha.Domain` namespace to access Shesha-specific migration features.
5. Create one database migration class per aggregate when implementing new entities.
6. Pay attention to the dependencies between entities and database tables when creating migration classes. Start with migrations for entities at the bottom of the dependency hierarchy and work your way up. For example, if you have a `Order` entity that depends on a `Customer` entity, you should create the migration for the `Customer` entity first.
7. **Always include a description of the migration** in the class-level comment to provide context for future developers.

<example>

```csharp
using System;
using FluentMigrator;
using Shesha.Domain;
using Shesha.FluentMigrator;

namespace MyNamespace.Migrations
{
    [Migration(20250508101500)]     // The migration number must be unique across all migrations in the application
    public class M20250508101500 : OneWayMigration  // Always inherit from OneWayMigration
    {
        public override void Up()
        {
            // Migration logic goes here
        }
    }
}
```

</example>


## Domain to DB Object Naming Mappings
When creating database migrations, use the following naming conventions to ensure that database objects correctly correspond to your domain model:

**CRITICAL: Always Check the Module's Table Prefix First**
Before creating any migration, you MUST check the module's configured table prefix:
1. **Read the AssemblyInfo.cs file** in the Domain project's Properties folder
2. Look for: `[assembly: TablePrefix("PREFIX_")]`
3. **Use this exact prefix** for all new tables and columns on inherited entities

Example: If AssemblyInfo.cs contains `[assembly: TablePrefix("LB_")]`, then:
- ✅ Correct: `Create.Table("LB_ElectronicApprovals")`
- ❌ Wrong: `Create.Table("Crm_ElectronicApprovals")`
- ❌ Wrong: `Create.Table("ElectronicApprovals")`

**Entity to Table:**
- New entity → Table name = [ModuleDBPrefix]_[PluralizedEntityName]
- Inherited entity → No new table; map to base entity's table

**Property to Column:**
- Regular property → Column name = [PropertyName]
- Foreign key property → Column name = [PropertyName]Id
- Reference list property → Column name = [PropertyName]Lkp
- TimeSpan property → Column name = [PropertyName]Ticks (Type: bigint)
- Property added to inherited entity → Column name = [ModuleDBPrefix]_[PropertyName]
- FK property added to inherited entity → Column name = [ModuleDBPrefix]_[PropertyName]Id
- FK property in [JoinedProperty] table → Column name = [ModuleDBPrefix]_[PropertyName]Id (ALL columns in joined tables MUST be prefixed)

**IMPORTANT: FK columns on inherited/joined tables:**
When adding FK columns to an inherited entity's table (via `Alter.Table`) or to a `[JoinedProperty]` table (used by `ConfigurationItemBase` subclasses), the FK column name MUST include the module prefix. NHibernate expects ALL custom columns on these tables to use the prefix.
- ✅ Correct: `.AddForeignKeyColumn("LB_RelatedEntityId", "Target_Table")`
- ❌ Wrong: `.AddForeignKeyColumn("RelatedEntityId", "Target_Table")`

**Module DB Prefix:**
All tables/columns for a module must use its prefix (e.g., LB_, Core_, Frwk_)
The prefix is defined in AssemblyInfo.cs with [assembly: TablePrefix("PREFIX_")]

**Common Prefixes:**
- `Core_` - Shesha.Core framework tables (Person, Organisation, Account, OtpAuditItem)
- `LB_` - LandBank.Crm module tables (example)
- `MyApp_` - Your custom module tables

**Practical Workflow for Finding the Correct Prefix:**

1. Read the Domain project's `Properties/AssemblyInfo.cs` file
2. Find the line: `[assembly: TablePrefix("PREFIX_")]`
3. Use that exact prefix in your migrations

<example>

**Step 1: Check AssemblyInfo.cs**
```csharp
// File: src/MyCompany.MyApp.Domain/Properties/AssemblyInfo.cs
using Shesha.Domain.Attributes;

[assembly: TablePrefix("LB_")]  // ← This is the prefix to use!
```

**Step 2: Use the prefix in migrations**
```csharp
// ✅ CORRECT - Uses LB_ prefix from AssemblyInfo.cs
Create.Table("LB_ElectronicApprovals")
    .WithIdAsGuid()
    .WithFullAuditColumns();

// ❌ WRONG - Using wrong prefix
Create.Table("Crm_ElectronicApprovals")  // Don't guess!
    .WithIdAsGuid();

// ❌ WRONG - Missing prefix entirely
Create.Table("ElectronicApprovals")  // Prefix is required!
    .WithIdAsGuid();
```

</example>

## Creating Tables

Here's an example of creating a new table:

<example>

```csharp
Create.Table("MyModule_MyEntities")
    .WithIdAsGuid()                 // Creates Id column of type uniqueidentifier
    .WithFullAuditColumns()         // Adds the standard audit columns
    .WithColumn("Name").AsString(200).Nullable()
    .WithColumn("Description").AsString(500).Nullable()
    .WithColumn("Amount").AsDecimal().Nullable()
    .WithColumn("CategoryLkp").AsInt64().Nullable()   // Reference list property
    .WithColumn("StartTimeTicks").AsInt64().Nullable();  // Maps to a property called StartTime of type TimeSpan
```

</example>


## Adding Discriminator Columns for Inheritance

When an entity class has the `[Discriminator]` attribute (indicating it supports inheritance), you must add a discriminator column in the migration:

### When Creating a New Table:

<example>

```csharp
Create.Table("MyModule_BaseEntities")
    .WithIdAsGuid()
    .WithFullAuditColumns()
    .WithColumn("Name").AsString(200).Nullable()
    .WithColumn(SheshaDatabaseConsts.DiscriminatorColumn).AsString(SheshaDatabaseConsts.DiscriminatorMaxSize);
```

</example>

### When Altering an Existing Table:

<example>

```csharp
if (!Schema.Table("MyModule_BaseEntities").Column(SheshaDatabaseConsts.DiscriminatorColumn).Exists())
{
    Alter.Table("MyModule_BaseEntities")
        .AddColumn(SheshaDatabaseConsts.DiscriminatorColumn).AsString(SheshaDatabaseConsts.DiscriminatorMaxSize);
}
```

</example>


## Adding Columns for GenericEntityReference

When adding a GenericEntityReference property in an entity, you need to create three columns in the database migration:

<example>

```csharp
Alter.Table("MyModule_Entities")
    .AddColumn("HasMemberId").AsString().Nullable()
    .AddColumn("HasMemberClassName").AsString().Nullable()
    .AddColumn("HasMemberDisplayName").AsString().Nullable();
```

</example>

These three columns work together to store:
1. The ID of the referenced entity
2. The class/type name of the referenced entity
3. A display name for the referenced entity

This allows for polymorphic references where a property can point to entities of different types.

## Adding Foreign Key Columns

To add a foreign key column to a table:

<example>

```csharp
Alter.Table("MyModule_Orders")
    .AddForeignKeyColumn("CustomerId", "Core_Persons").Nullable()
    .AddForeignKeyColumn("ProductId", "MyModule_Products").Nullable();
```

</example>

## Altering Existing Tables

To modify an existing table:

<example>

```csharp
// First check if the column exists to avoid errors on re-running migrations
if (!Schema.Table("MyModule_Entities").Column("NewProperty").Exists())
{
    Alter.Table("MyModule_Entities")
        .AddColumn("NewProperty").AsString(100).Nullable();
}

// To add a foreign key to an existing table
Alter.Table("MyModule_Entities")
    .AddForeignKeyColumn("NewEntityId", "MyModule_OtherEntities").Nullable();
```
</example>


Here's a complete example of a migration that creates two related tables:

<example>

```csharp
using System;
using FluentMigrator;
using Shesha.Domain;
using Shesha.FluentMigrator;

namespace MyModule.Migrations
{
    [Migration(20250114101300)]
    public class M20250114101300 : OneWayMigration
    {
        public override void Up()
        {
            Create.Table("MyModule_Orders")
             .WithIdAsGuid()
             .WithFullAuditColumns()
             .WithColumn("OrderNo").AsString().Nullable()
             .WithColumn("DeliveryDate").AsDateTime().Nullable()
             .WithColumn("Comment").AsString().Nullable()
             .WithColumn("StatusLkp").AsInt64().Nullable()
             .WithColumn(SheshaDatabaseConsts.DiscriminatorColumn).AsString(SheshaDatabaseConsts.DiscriminatorMaxSize);

             Alter.Table("MyModule_Orders").AddForeignKeyColumn("CustomerId", "Core_Accounts").Nullable();

            Create.Table("MyModule_OrderLines")
             .WithIdAsGuid()
             .WithFullAuditColumns()
             .WithColumn("Description").AsString(400).Nullable()
             .WithColumn("Price").AsDecimal().Nullable()
             .WithColumn("Quantity").AsInt32().Nullable()
             .WithColumn("SubTotal").AsDecimal().Nullable();

             Alter.Table("MyModule_OrderLines").AddForeignKeyColumn("PartOfId", "MyModule_Orders").Nullable();
             Alter.Table("MyModule_OrderLines").AddForeignKeyColumn("ProductId", "MyModule_Products").Nullable();
        }
    }
}
```

</example>

## Custom SQL Queries

You can also use the `Execute.Sql` method to run custom SQL queries:

<example>

```csharp
if (Schema.Table("MyModule_Entities").Exists())
{
    Execute.Sql(@"
        UPDATE MyModule_Entities
        SET Status = 2
        WHERE Status = 1 AND CreationTime < GETDATE()
    ");
}
```

</example>
