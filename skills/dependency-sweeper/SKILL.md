# Dependency Sweeper — Al Batal Elite

Scans Flutter dependencies for outdated packages, security advisories, and compatibility risks.

## When to Use

- Weekly or bi-weekly dependency check
- Before major releases
- When CI shows deprecation warnings
- After Flutter SDK upgrades

## Workflow

1. **Check outdated packages**
   ```bash
   flutter pub outdated
   ```

2. **Check for security advisories**
   ```bash
   dart pub audit
   ```

3. **Analyze results**
   - Categorize: minor patch, minor version, major version
   - Flag any packages with known CVEs
   - Check compatibility with current Flutter SDK

4. **Report findings**
   - Update `STATE.md` with Watch List items
   - Create issue for major version upgrades
   - Do NOT auto-upgrade — suggest upgrades to human

## Constraints

- Never run `flutter pub upgrade` without human approval
- Never modify `pubspec.lock` directly
- Always suggest, never auto-apply dependency changes
- Major version bumps always require human approval
- Log findings to `loop-run-log.md`

## Output Format

```markdown
## Dependency Report — [date]

### Safe to upgrade (patch/minor)
- package_a: ^1.0.0 → ^1.1.0 (no breaking changes)

### Needs review (major)
- package_b: ^2.0.0 → ^3.0.0 (breaking changes: [list])

### Security advisories
- package_c: CVE-XXXX-XXXX (severity: high)

### Deprecated
- package_d: use package_e instead
```
