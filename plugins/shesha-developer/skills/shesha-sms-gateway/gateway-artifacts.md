# SMS Gateway Artifacts

## §1. Gateway Settings Class

**File:** `{GatewayName}Settings.cs` in `{GatewayName}/`

Stores the persisted configuration values. This is the class stored via `ISetting<T>`.

```csharp
using System.ComponentModel.DataAnnotations;

namespace {Namespace}.Sms.{GatewayName}
{
    /// <summary>
    /// {GatewayName} gateway stored settings
    /// </summary>
    public class {GatewayName}Settings
    {
        [Display(Name = "API Key")]
        public string ApiKey { get; set; }

        [Display(Name = "API URL")]
        public string ApiUrl { get; set; }

        // Add provider-specific fields here
    }
}
```

**Key rules:**
- Plain POCO — no `virtual`, no ABP base class.
- Field names are internal; use `[Display(Name)]` for UI labels.
- Must be JSON-serializable (no circular refs).

---

## §2. Settings DTO

**File:** `{GatewayName}SettingDto.cs` in `{GatewayName}/`

The API-facing shape returned and accepted by the app service endpoints.

```csharp
using System.ComponentModel.DataAnnotations;

namespace {Namespace}.Sms.{GatewayName}
{
    /// <summary>
    /// {GatewayName} settings DTO
    /// </summary>
    public class {GatewayName}SettingDto
    {
        [Display(Name = "API Key")]
        public string ApiKey { get; set; }

        [Display(Name = "API URL")]
        public string ApiUrl { get; set; }

        // Mirror fields from {GatewayName}Settings
    }
}
```

**Key rules:**
- Properties should mirror `{GatewayName}Settings` fields.
- Can omit or rename fields for security (e.g., mask password).
- No base class required.

---

## §3. Setting Name Constants

**File:** `{GatewayName}SettingNames.cs` in `{GatewayName}/`

String constants used in `[Setting(…)]` attributes to avoid magic strings.

```csharp
namespace {Namespace}.Sms.{GatewayName}
{
    /// <summary>
    /// Names of the {GatewayName} gateway settings
    /// </summary>
    public static class {GatewayName}SettingNames
    {
        public const string GatewaySettings = "GatewaySettings";
    }
}
```

**Key rules:**
- `static` class with `const string` fields.
- The value `"GatewaySettings"` is a convention — use a meaningful key if multiple setting groups exist.

---

## §4. Settings Accessor Interface

**File:** `I{GatewayName}Settings.cs` in `{GatewayName}/`

Provides strongly-typed property access to the gateway's stored setting. Injected into the gateway class.

```csharp
using Shesha.Settings;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace {Namespace}.Sms.{GatewayName}
{
    /// <summary>
    /// {GatewayName} settings accessor
    /// </summary>
    [Category("SMS")]
    public interface I{GatewayName}Settings : ISettingAccessors
    {
        /// <summary>
        /// {GatewayName} Gateway settings
        /// </summary>
        [Display(Name = "{GatewayName} Gateway")]
        [Setting({GatewayName}SettingNames.GatewaySettings, EditorFormName = "gateway-settings")]
        ISettingAccessor<{GatewayName}Settings> {GatewayName}Gateway { get; }
    }
}
```

**Key rules:**
- Must extend `ISettingAccessors`.
- `[Category("SMS")]` groups it with other SMS settings in the admin.
- `EditorFormName` references a Shesha form for editing in the admin UI (create the form separately if needed).

---

## §5. Gateway Marker Interface

**File:** `I{GatewayName}SmsGateway.cs` in `{GatewayName}/`

Empty marker used for typed DI resolution (avoids resolving the concrete class directly).

```csharp
using Shesha.Sms;

namespace {Namespace}.Sms.{GatewayName}
{
    /// <summary>
    /// Marker interface for {GatewayName} SMS gateway
    /// </summary>
    public interface I{GatewayName}SmsGateway : IConfigurableSmsGateway<{GatewayName}SettingDto>
    {
    }
}
```

**Key rules:**
- Extends `IConfigurableSmsGateway<TDto>` so app services can inject the typed interface.
- Used in the Castle Windsor registration: `Component.For<I{GatewayName}SmsGateway>().Forward<{GatewayName}SmsGateway>()`.

---

## §6. Gateway Implementation

**File:** `{GatewayName}SmsGateway.cs` in `{GatewayName}/`

The actual SMS sending logic. Selected at runtime via `[ClassUid]`.

```csharp
using Castle.Core.Logging;
using Shesha.Attributes;
using Shesha.Notifications.Dto;
using Shesha.Sms;
using System;
using System.Net.Http;
using System.Threading.Tasks;
using System.ComponentModel.DataAnnotations;

namespace {Namespace}.Sms.{GatewayName}
{
    [ClassUid("{NewGuid}")]           // ← replace with a freshly generated GUID
    [Display(Name = "{GatewayName}")] // ← label shown in the Shesha admin UI
    public class {GatewayName}SmsGateway : ConfigurableSmsGateway<{GatewayName}SettingDto>, I{GatewayName}SmsGateway
    {
        public ILogger Logger { get; set; }
        private readonly I{GatewayName}Settings _settings;

        public {GatewayName}SmsGateway(I{GatewayName}Settings settings)
        {
            Logger = NullLogger.Instance;
            _settings = settings;
        }

        public override async Task<SendStatus> SendSmsAsync(string mobileNumber, string body)
        {
            var settings = await _settings.{GatewayName}Gateway.GetValueAsync();

            try
            {
                using var httpClient = new HttpClient();
                // TODO: implement provider-specific HTTP call using settings.ApiKey, settings.ApiUrl, etc.
                // Return SendStatus.Success() on success or SendStatus.Failed(message) on failure.
                throw new NotImplementedException("Implement SMS sending logic here.");
            }
            catch (Exception ex)
            {
                Logger.ErrorFormat($"SMS send failed: {ex.Message}");
                return SendStatus.Failed($"SMS send failed: {ex.Message}");
            }
        }

        public override async Task<{GatewayName}SettingDto> GetTypedSettingsAsync()
        {
            var s = await _settings.{GatewayName}Gateway.GetValueAsync();
            return new {GatewayName}SettingDto
            {
                ApiKey = s.ApiKey,
                ApiUrl = s.ApiUrl,
            };
        }

        public override async Task SetTypedSettingsAsync({GatewayName}SettingDto dto)
        {
            await _settings.{GatewayName}Gateway.SetValueAsync(new {GatewayName}Settings
            {
                ApiKey = dto.ApiKey,
                ApiUrl = dto.ApiUrl,
            });
        }
    }
}
```

**Key rules:**
- `[ClassUid]` **must** be a unique GUID — generate a fresh one; never reuse an existing UID.
- `[Display(Name)]` controls the label shown in Shesha's SMS gateway selector UI.
- Constructor-inject `I{GatewayName}Settings` (registered by `IocManager.RegisterSettingAccessor`).
- `SendStatus.Success()` / `SendStatus.Failed(message)` are the only valid return values.
- Use `ILogger Logger { get; set; }` (Castle property injection pattern) for logging.

---

## §7. App Service Interface

**File:** `I{GatewayName}AppService.cs` in `{GatewayName}/`

Exposes HTTP endpoints for reading and writing gateway settings from the Shesha admin UI.

```csharp
using Abp.Application.Services;
using System.Threading.Tasks;

namespace {Namespace}.Sms.{GatewayName}
{
    /// <summary>
    /// {GatewayName} SMS app service — manages gateway settings
    /// </summary>
    public interface I{GatewayName}AppService : IApplicationService
    {
        Task<{GatewayName}SettingDto> GetSettingsAsync();
        Task<bool> UpdateSettingsAsync({GatewayName}SettingDto input);
    }
}
```

**Key rules:**
- Must extend `IApplicationService` for ABP controller generation.
- Keep to `GetSettingsAsync` / `UpdateSettingsAsync` convention — mirrors Clickatell pattern.

---

## §8. App Service

**File:** `{GatewayName}AppService.cs` in `{GatewayName}/`

Implementation of the settings app service.

```csharp
using Abp.Runtime.Session;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;

namespace {Namespace}.Sms.{GatewayName}
{
    /// <inheritdoc />
    public class {GatewayName}AppService : I{GatewayName}AppService
    {
        public IAbpSession AbpSession { get; set; }

        private readonly I{GatewayName}SmsGateway _gateway;

        public {GatewayName}AppService(I{GatewayName}SmsGateway gateway)
        {
            _gateway = gateway;
            AbpSession = NullAbpSession.Instance;
        }

        /// <inheritdoc />
        [HttpGet, Route("api/{GatewayName}/Settings")]
        public async Task<{GatewayName}SettingDto> GetSettingsAsync()
        {
            return await _gateway.GetTypedSettingsAsync();
        }

        /// <inheritdoc />
        [HttpPut, Route("api/{GatewayName}/Settings")]
        public async Task<bool> UpdateSettingsAsync({GatewayName}SettingDto input)
        {
            await _gateway.SetTypedSettingsAsync(input);
            return true;
        }
    }
}
```

**Key rules:**
- Inject `I{GatewayName}SmsGateway` (not the concrete class) — decoupled and testable.
- Route convention: `api/{GatewayName}/Settings` (GET and PUT).
- `AbpSession = NullAbpSession.Instance` is required for unauthenticated resolution fallback.

---

## §9. ABP Module

**File:** `Shesha{GatewayName}Module.cs` in the project root of `{ModuleName}.Sms.{GatewayName}/`

Wires up IoC registration, setting defaults, and controller discovery.

```csharp
using Abp.AspNetCore;
using Abp.AspNetCore.Configuration;
using Abp.Modules;
using Castle.MicroKernel.Registration;
using Shesha.Modules;
using Shesha.Settings.Ioc;
using System.Reflection;
using System.Threading.Tasks;

namespace {Namespace}.Sms.{GatewayName}
{
    [DependsOn(typeof(SheshaFrameworkModule), typeof(SheshaApplicationModule), typeof(AbpAspNetCoreModule))]
    public class Shesha{GatewayName}Module : SheshaModule
    {
        public const string ModuleName = "{Publisher}.{GatewayName}";

        public override SheshaModuleInfo ModuleInfo => new SheshaModuleInfo(ModuleName)
        {
            FriendlyName = "Shesha {GatewayName}",
            Publisher = "{Publisher}",
        };

        public override async Task<bool> InitializeConfigurationAsync()
        {
            return await ImportConfigurationAsync();
        }

        public override void PreInitialize()
        {
            Configuration.Modules.AbpAspNetCore().CreateControllersForAppServices(
                this.GetType().Assembly,
                moduleName: "Shesha{GatewayName}",
                useConventionalHttpVerbs: true);
        }

        public override void Initialize()
        {
            IocManager.RegisterAssemblyByConvention(Assembly.GetExecutingAssembly());

            IocManager.RegisterSettingAccessor<I{GatewayName}Settings>(s =>
            {
                s.{GatewayName}Gateway.WithDefaultValue(new {GatewayName}Settings
                {
                    ApiUrl = "https://api.{gatewayname}.com",  // sensible default
                });
            });

            IocManager.IocContainer.Register(
                Component.For<I{GatewayName}SmsGateway>()
                         .Forward<{GatewayName}SmsGateway>()
                         .ImplementedBy<{GatewayName}SmsGateway>()
                         .LifestyleTransient()
            );
        }
    }
}
```

**Key rules:**
- `[DependsOn]` must include `SheshaFrameworkModule`, `SheshaApplicationModule`, and `AbpAspNetCoreModule`.
- `RegisterAssemblyByConvention` scans the assembly for all `ITransientDependency` / conventional registrations.
- `RegisterSettingAccessor<I{GatewayName}Settings>` registers the settings interface and sets default values.
- Gateway registration must use `.Forward<{GatewayName}SmsGateway>()` so the concrete type is also resolvable (required by the Shesha runtime gateway factory).
- The module must be listed in the host application's `[DependsOn]` chain to take effect.
- `ModuleName` follows `"{Publisher}.{GatewayName}"` convention (e.g., `"Acme.Twilio"`).
