# P0 — Android Release Identity and Signing

## Objective
Produce a publishable Android artifact with a unique branded identity and protected release signing.

## Requirements
- Choose and record an approved reverse-domain application ID; do not use `com.example.*`.
- Update Android namespace/application ID and all references required by the project.
- Inspect iOS bundle identifier and align it with the approved brand identity if iOS is in scope.
- Create or import the production keystore outside the repository.
- Configure release signing through local secure configuration and CI secrets; never commit keystore files, passwords, or signing properties.
- Keep debug signing for debug builds only.
- Add CI checks that fail when a release build uses debug signing or the placeholder application ID.
- Document key ownership, backup, rotation, and recovery procedures.

## Acceptance criteria
- `flutter build apk --release` succeeds in a clean environment.
- `apksigner verify --verbose` confirms a valid signed artifact.
- Artifact package identity equals the approved ID.
- Debug keystore fingerprints are absent from the release artifact.
- CI can produce the artifact without exposing signing secrets in logs.
- Reinstall/upgrade behavior is tested for the chosen package identity.

## Evidence
Record package ID, signing certificate fingerprint, build command, artifact checksum, and CI run. Never record private key material.
