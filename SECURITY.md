# Security Policy

**English** · [Español](SECURITY.es.md)

OpenVault stores secrets, so we take any vulnerability seriously.

## Reporting a vulnerability

**Do not open a public issue.** Report it privately via
[Security → Report a vulnerability](https://github.com/Im-Fran/openvault/security/advisories/new).

If you can, include:
- The affected version or commit.
- Steps to reproduce it and the impact (e.g. reading secrets without the master password).
- A minimal proof of concept.

We will respond within 7 days and keep you updated until the fix is released. We're happy to credit you in the advisory if you wish.

## Supported versions

Only the latest version of the `dev` branch receives security fixes.

## Scope

In scope: vault encryption and format, the macOS app, the `ovault` CLI, and key handling (Keychain, clipboard, temporary files).

Out of scope: attacks that require the Mac to already be compromised with the user's privileges while the vault is unlocked.
