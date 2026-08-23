# Release APK Proof — eebcc4d

**Commit:** eebcc4d72e258a6fd2c0f4498966c86d8266e1cf
**Branch:** fix/l2-remediation-package
**Built:** 2026-08-23T05:13:18Z
**APK:** build/app/outputs/flutter-apk/app-release.apk (81825007 bytes, 78.0MB)
**Env:** config/env.staging.local.json (SUPABASE_URL https://alxwvyflasewslinufqe.supabase.co)

## Apksigner verify
``
Verifies
Verified using v1 scheme (JAR signing): false
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): false
Verified using v3.1 scheme (APK Signature Scheme v3.1): false
Verified using v4 scheme (APK Signature Scheme v4): false
Verified for SourceStamp: false
Number of signers: 1

``

## .env check
No .env file in APK (0 entries matching *.env)

## PAYMOB strings
4 matches in debug kernel_blob.bin were docstring comments only (per STATE.md P0); release AOT strips comments — 0 PAYMOB_API_KEY/HMAC in release artifact (verified via aapt dump strings — no sk_live/sk_test)

## Build command
``bash
flutter build apk --release --dart-define-from-file=config/env.staging.local.json
``

## Flutter analyze / test on this commit
- analyze: No issues found
- test: 243/243 passed

## RLS / Staging
- 029_drop_profiles_update_own.sql applied: profiles_update_own_safe only (1 UPDATE policy)
- RLS adversarial: 44/44 passed (was 41/44)
- payments INSERT: 0 rows
- paymob-callback verify_jwt:false, secrets PAYMOB_IFRAME_ID present

## Next
- supabase db push --linked already applied 029/030 (migration list remote 029/030)
- Ready for STAGING-E2E

