# Changelog

All notable changes to the Claude Code 2.0 POD Business System will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Remediation scaffolds for custom MCP servers (data-etsy, data-trends, logic-validator)
- Audit logging and token rotation service scripts
- Documentation for versioning, naming, branching, and .claude directory

### Changed
- Docker images pinned to specific versions
- Docker network subnet corrected to private range

### Security
- OAuth JIT credential scripts with rotation hooks and logging

## [1.0.0] - 2025-12-07

### Added
- Initial production candidate release
- 5-layer architecture implementation
- 18/22 Claude Code 2.0 features
- 96% test coverage
- MCP v2.0 compliance baseline
