# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-17

First public release.

### Added

- Installed package browser: formulae & casks with versions, descriptions, outdated badges, and a detail inspector (uninstall / upgrade with confirmation)
- Live search of formulae and casks with one-click install
- Updates view: outdated list, upgrade individual / all, `brew update` metadata refresh, sidebar badge
- Services view: `brew services` status and start / stop / restart
- Bottom console drawer streaming output of every mutating command in real time
- Programmatically rendered app icon (CoreGraphics) and `.app` packaging via `make app`
- Zero-dependency check runner (`SteinCoreChecks`) covering JSON models, parsing and merge logic

[0.1.0]: https://github.com/YoungKing1212/Stein/releases/tag/v0.1.0
