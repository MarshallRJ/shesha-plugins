---
name: shesha-sms-gateway
description: Creates and registers a custom ISmsGateway implementation in a Shesha .NET application. Scaffolds all required artifacts: gateway class, settings class, settings DTO, setting name constants, settings accessor interface, marker interface, app service, and module registration. Use when the user asks to add, create, implement, register, or scaffold a new SMS gateway, SMS provider, SMS integration, or ISmsGateway in a Shesha project.
---

# Shesha SMS Gateway

Generate all artifacts to add a new `ISmsGateway` implementation to a Shesha .NET application based on $ARGUMENTS.

## Instructions

- Inspect nearby files to determine the correct namespace root and project name.
- The `[ClassUid]` on the gateway class **must** be a newly generated GUID — generate one with `Guid.NewGuid()` or use a UUID tool.
- The `[Display(Name = "...")]` value on the gateway class is what appears in the Shesha admin UI gateway selector.
- All settings properties are plain classes (not entities) — no `virtual` keyword needed.
- Register the module with `[DependsOn(typeof(SheshaFrameworkModule), typeof(SheshaApplicationModule), typeof(AbpAspNetCoreModule))]`.
- The module **must** call `IocManager.RegisterAssemblyByConvention` and register the gateway via `Component.For<I{GatewayName}SmsGateway>().Forward<{GatewayName}SmsGateway>()`.
- The gateway is selected at runtime via `[ClassUid]` — the UID stored in `SmsSettings.SmsGateway` must match the GUID on the class.
- Implement `ConfigurableSmsGateway<TSettings>` (not `ISmsGateway` directly) unless the gateway has no configurable settings.
- Use `ITransientDependency` is NOT required — Castle Windsor picks up the gateway via `RegisterAssemblyByConvention`.

## Artifact catalog

| # | Artifact | Layer | Template |
|---|----------|-------|----------|
| 1 | Gateway settings class | Application | [gateway-artifacts.md](gateway-artifacts.md) §1 |
| 2 | Settings DTO | Application | [gateway-artifacts.md](gateway-artifacts.md) §2 |
| 3 | Setting name constants | Application | [gateway-artifacts.md](gateway-artifacts.md) §3 |
| 4 | Settings accessor interface | Application | [gateway-artifacts.md](gateway-artifacts.md) §4 |
| 5 | Gateway marker interface | Application | [gateway-artifacts.md](gateway-artifacts.md) §5 |
| 6 | Gateway implementation | Application | [gateway-artifacts.md](gateway-artifacts.md) §6 |
| 7 | App service interface | Application | [gateway-artifacts.md](gateway-artifacts.md) §7 |
| 8 | App service | Application | [gateway-artifacts.md](gateway-artifacts.md) §8 |
| 9 | Module | Application | [gateway-artifacts.md](gateway-artifacts.md) §9 |

## Folder structure

```
{ModuleName}.Sms.{GatewayName}/          ← new project or folder in Application
  {GatewayName}/
    {GatewayName}Settings.cs             §1  stored settings (persisted via ISetting)
    {GatewayName}SettingDto.cs           §2  API-facing DTO
    {GatewayName}SettingNames.cs         §3  string constants
    I{GatewayName}Settings.cs            §4  setting accessor interface
    I{GatewayName}SmsGateway.cs          §5  marker interface
    {GatewayName}SmsGateway.cs           §6  gateway implementation
    I{GatewayName}AppService.cs          §7  app service interface
    {GatewayName}AppService.cs           §8  app service (get/set settings)
    Shesha{GatewayName}Module.cs         §9  ABP module + IoC registration
```

## Quick reference

### Key base classes and interfaces

| Type | Purpose |
|------|---------|
| `ConfigurableSmsGateway<TSettings>` | Base for gateways with settings; implements `ISmsGateway` |
| `ISmsGateway` | Raw interface if no settings needed |
| `IConfigurableSmsGateway<TSettings>` | Extended interface adding typed get/set settings |
| `ISettingAccessors` | Base for setting accessor interfaces |
| `ISettingAccessor<T>` | Per-setting accessor property type |
| `SheshaModule` | Base for ABP modules |
| `IApplicationService` | Marker for app service interfaces |

### Key attributes

| Attribute | Target | Purpose |
|-----------|--------|---------|
| `[ClassUid("…guid…")]` | Gateway class | Unique ID for runtime gateway selection |
| `[Display(Name = "…")]` | Gateway class | Label shown in admin UI |
| `[Category("SMS")]` | Settings interface | Groups settings in admin |
| `[Setting(name, EditorFormName = "…")]` | Accessor property | Maps to a Shesha setting |
| `[DependsOn(…)]` | Module class | ABP module dependency declaration |

### How gateway selection works

1. Admin sets `SmsSettings.SmsGateway` to the gateway's `ClassUid` GUID string.
2. At resolve time, `SheshaApplicationModule` uses `ITypeFinder` to find the `ISmsGateway` type whose `[ClassUid]` matches that string.
3. It resolves that type from IoC — so the gateway **must** be registered as its concrete type.

Now generate the requested SMS gateway artifact(s) based on: $ARGUMENTS
