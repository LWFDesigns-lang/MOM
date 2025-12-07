# Versioning Policy

## Semantic Versioning
This project follows [Semantic Versioning 2.0.0](https://semver.org/): **MAJOR.MINOR.PATCH**
- MAJOR: Breaking changes or incompatible API changes
- MINOR: New features, backward compatible
- PATCH: Bug fixes, backward compatible

## Components
- Skills: version in `SKILL.md` frontmatter; breaking interface changes require MAJOR.
- MCP servers: follow semantic versioning; pin exact versions in `.mcp.json`.
<!-- DEPRECATED: Docker images (Enterprise phase only - not used in current Lean Agent MVP) -->
- Dependencies: maintain `package-lock.json` once npm packages are resolved; review monthly.

## Release Process
1. Update `CHANGELOG.md`.
2. Bump version in `package.json`.
3. Tag release: `git tag -a vX.Y.Z -m "Release X.Y.Z"`.
4. Generate release notes from changelog.
5. Deploy after tests pass.

## Lifecycle
- Active support: latest 2 major versions.
- Security fixes: latest 3 major versions.
- EOL: announce 6 months in advance.
