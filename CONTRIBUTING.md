# Contributing to Ramjet

Thank you for helping improve Ramjet. Bug reports, compatibility findings,
tests, documentation and code are all welcome.

## Clean-room rule

Ramjet is an independent implementation. Contributions must not contain code,
comments or format details copied or translated from proprietary RAR, WinRAR or
UnRAR source code, decompiled or disassembled binaries, or undisclosed sources.

Code adapted from another open-source project may be accepted only when its
license is compatible with GPL-3.0-only and the source, license and changes are
explicitly disclosed. Preserve all required attribution and license notices.
This includes open-source RAR implementations with compatible licenses.
Proprietary, confidential or incompatibly licensed sources remain prohibited.

Public specifications, public standards, independently observed program
behaviour and suitably licensed implementations may be used as references.
Describe every source used in the pull request. Changes that add format
knowledge should also update `docs/provenance-notes.md` with what was learned
and how it was verified.

## Branches and pull requests

- `main` is the release-ready branch.
- `dev` is the integration branch. Open normal pull requests against `dev`.
- Keep a pull request focused on one fix or feature.
- Add or update tests for behaviour changes.
- Update user-facing documentation when commands or compatibility change.
- Explain which operating systems and architectures you tested.

Before opening a pull request, run `mach test .` and any relevant integration
tests.

By contributing, you agree that your contribution is licensed under the
project's GPL-3.0-only license.
