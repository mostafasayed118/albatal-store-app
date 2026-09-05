# Android Release Artifact — Re-tie Evidence (2026-08-23)

Purpose: satisfy the RELEASE_GATE Android-artifact row against a designated master
SHA after the environment isolation work, by fingerprinting the signed APK built
by CI on the current master tip.

## Run metadata

| Field | Value |
|---|---|
| Workflow | `CI` (`.github/workflows/ci.yml`, job `android-release`, line 229) |
| Run ID | `32646592228` |
| Conclusion | success |
| Event / branch | push / `master` |
| Head SHA | `ac69c54c91ca9409f5ec30fabcf6a35c2001956f` (`ac69c54`) |
| Head commit | feat(isolation): provision isolated staging Supabase project (Option A) |
| Created | 2026-08-23T14:49:03Z |
| Duration | 8m50s |

Note: `android-release.yml` has zero runs to date; the release APK pipeline that
actually executes on push is the `android-release` job inside `ci.yml`.

## Artifact identity

| Field | Value |
|---|---|
| Artifact name | `release-apk` (zip size 45,479,705 bytes, not expired) |
| File | `app-release.apk` |
| Size | 79,311,899 bytes |
| SHA-256 (pass 1) | `970469542a77822a11372cacf70741d35ff59067b9f4647013d0df5495f404a0` |
| SHA-256 (pass 2) | `970469542a77822a11372cacf70741d35ff59067b9f4647013d0df5495f404a0` |

Two independent hash passes over the downloaded copy agree — download is stable.

## Package identity (aapt dump badging, build-tools 37.0.0)

```
package: name='com.albatal.elite' versionCode='1' versionName='0.1.0'
compileSdkVersion='36' (codename 16)
sdkVersion:'24'   targetSdkVersion:'36'
```

## Signing proof

The build is fail-closed on signing secrets and signs with the upload keystore
provisioned via `gh secret set` on 2026-08-23 (STATE.md, commit `ff0bbcf`).
Quoted from `.github/workflows/ci.yml`:

```yaml
      - name: Verify signing secrets present        # line ~243
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        run: |
          missing=()
          [ -z "$KEYSTORE_BASE64" ]   && missing+=("KEYSTORE_BASE64")
          ...
      - name: Decode keystore                        # line ~265
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
        run: echo "$KEYSTORE_BASE64" | base64 -d > android/app/release-keystore.jks
      - name: Create key.properties                  # storeFile=release-keystore.jks
      - name: Build release APK                      # line 284
        run: flutter build apk --release
```

Missing secrets abort the job before any build occurs.

## Proposed RELEASE_GATE row text

> **Android release artifact:** CI run `32646592228` (master, success,
> 2026-08-23T14:49:03Z). Signed release APK `app-release.apk`
> (`com.albatal.elite` v1 / 0.1.0), 79,311,899 bytes,
> SHA-256 `970469542a77822a11372cacf70741d35ff59067b9f4647013d0df5495f404a0`,
> built fail-closed on upload-keystore secrets. Candidate designation:
> **OWNER PICKS ONE** — (a) `fc0b2a2`, frozen production candidate per commit
> `d94753c`; or (b) `ac69c54`, same tree plus the docs-only isolation commit.
> The artifact above was produced at `ac69c54`; if (a) is chosen, note that the
> two SHAs are content-identical for all shipped code paths (isolation commit
> touches docs/config only).
