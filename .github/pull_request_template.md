## What this changes

<!-- One or two sentences. What behaviour is different after this PR? -->

## Why

<!-- The problem being solved. Link the issue: Closes #123 -->

## How

<!-- The approach, and anything a reviewer would otherwise have to reverse-engineer. -->

## Testing

- [ ] `make test` passes
- [ ] `make cli` builds
- [ ] `make app` builds, and I checked the affected screens
- [ ] Checked on iPhone/iPad (simulator or device), if the change touches the iOS app

## Screenshots

<!-- Required for UI changes. Light and dark mode if the change is visual. -->

## Checklist

- [ ] Commits follow [Conventional Commits](https://www.conventionalcommits.org)
- [ ] Changes to `OpenVaultCore` (encryption, vault format, `.env` parser, `.ovaultrc`) are covered by a test
- [ ] New user-facing strings are in English with their `es-419` translation in `Localizable.xcstrings`
- [ ] Docs updated if behaviour changed, with their `.es.md` twins in sync
- [ ] No secrets, real `.env` files or vault files in the diff
