# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Update EDR submodule to 7af6784 — SystemSnapshot fields validation, FIM runtime ignores, company inference improvements, GLPI company requester improvements (#97)

### Changed
- Wire GLPI ticket creation through EDR server — pass GLPI_* env vars to edr-server in compose files, update .env.example with ticket configuration options (superseded by #97, PR #72 closed)
