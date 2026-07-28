# Build-time configuration

> **P0 security remediation:** the Flutter app no longer packages `.env`
> as an asset and no longer reads `.env` at runtime. All client
> configuration is injected at **build time** via
> `--dart-define-from-file`. See [`config/README.md`](../config/README.md)
> for the placeholder templates.

## Trust boundary

The Flutter client is a **public** artifact. Anything baked into the APK
can be extracted by anyone who installs it. Therefore the client may only
receive values that are safe to publish.

### Safe to ship (client-side)

| Variable            | Why it's safe                            |
|---------------------|------------------------------------------|
| `SUPABASE_URL`      | Public project endpoint. RLS enforces access. |
| `SUPABASE_ANON_KEY` | Public key designed for clients. RLS is the boundary, not the key. |
| `SENTRY_DSN`        | Public project identifier, not a secret. Only set when Sentry is approved. |

### NEVER shipped to the client (server-only)

These live **only** in Supabase Edge Function secrets
(`supabase functions secrets set <NAME>=<value>`):

- `PAYMOB_API_KEY`
- `PAYMOB_INTEGRATION_ID`
- `PAYMOB_HMAC_SECRET`
- `PAYMOB_IFRAME_ID`
- `SUPABASE_SERVICE_ROLE_KEY` (bypasses RLS — server only)
- `SCHEDULER_SECRET`
- any other Edge Function secret

## How values reach the app

`EnvConfig` (`lib/shared/services/env_config.dart`) reads values via
`String.fromEnvironment(...)`. These are **compile-time constants**
resolved by the Dart compiler from `--dart-define` flags. There is no
runtime file read, no asset load, and no `flutter_dotenv` dependency.

## Setup (one-time)

```bash
# Staging — create a local override (gitignored) from the placeholder template
cp config/env.staging.json config/env.staging.local.json
# Edit config/env.staging.local.json and fill in real SUPABASE_URL / SUPABASE_ANON_KEY

# Production — same pattern
cp config/env.production.json config/env.production.local.json
# Edit config/env.production.local.json with production values
```

`config/env.*.local.json` and `config/env.*.secret.json` are gitignored
(see `.gitignore`). The committed `env.staging.json` / `env.production.json`
contain only placeholders.

## Run / build commands

### Staging

```bash
# Debug run
flutter run --dart-define-from-file=config/env.staging.local.json

# Release APK
flutter build apk --release \
  --dart-define-from-file=config/env.staging.local.json

# Release App Bundle (Play Store)
flutter build appbundle --release \
  --dart-define-from-file=config/env.staging.local.json
```

### Production

```bash
flutter build apk --release \
  --dart-define-from-file=config/env.production.local.json

flutter build appbundle --release \
  --dart-define-from-file=config/env.production.local.json

# iOS
flutter build ipa --release \
  --dart-define-from-file=config/env.production.local.json
```

## Verification checklist

Run these after every release build to confirm no secrets leaked into
the artifact.

### 1. Static analysis & tests

```bash
flutter analyze
flutter test
```

### 2. Release build

```bash
flutter build apk --release \
  --dart-define-from-file=config/env.staging.local.json
```

### 3. Confirm `.env` is NOT in the APK

```bash
# List APK contents; the grep should find nothing.
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -E "\.env$" \
  && echo "FAIL: .env found in APK" || echo "OK: no .env in APK"
```

On Windows PowerShell (no `unzip`):

```powershell
$apk = "build\app\outputs\flutter-apk\app-release.apk"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $apk))
$bad = $zip.Entries | Where-Object { $_.FullName -like "*.env" -or $_.FullName -like "assets/.env" }
if ($bad) { Write-Host "FAIL: .env found in APK:"; $bad | ForEach-Object { Write-Host "  $($_.FullName)" } }
else { Write-Host "OK: no .env in APK" }
$zip.Dispose()
```

### 4. Confirm no `PAYMOB_` / service-role strings in the artifact

```bash
# Should print "OK: no PAYMOB_ strings in APK"
unzip -p build/app/outputs/flutter-apk/app-release.apk \
  | grep -a "PAYMOB_" | head \
  && echo "FAIL: PAYMOB_ string found" || echo "OK: no PAYMOB_ strings in APK"

unzip -p build/app/outputs/flutter-apk/app-release.apk \
  | grep -a "SUPABASE_SERVICE_ROLE_KEY" | head \
  && echo "FAIL: service-role key string found" || echo "OK: no service-role string in APK"
```

### 5. Confirm `flutter_dotenv` is gone

```bash
grep -n "flutter_dotenv" pubspec.yaml pubspec.lock \
  && echo "FAIL: flutter_dotenv still referenced" || echo "OK: flutter_dotenv removed"
```

## Rotating exposed secrets (historical)

If a previous build shipped `.env` containing Paymob keys, treat those
keys as compromised and rotate them in the Supabase dashboard / Paymob
dashboard, then re-set Edge Function secrets:

```bash
supabase functions secrets set PAYMOB_API_KEY=<new>
supabase functions secrets set PAYMOB_HMAC_SECRET=<new>
```

The anon key does not need rotation — it is public by design and RLS
protects the data.
