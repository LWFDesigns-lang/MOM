# Git Branching Strategy

## Branch Types
- `main`: production-ready, protected, tagged releases only.
- `develop`: integration branch; always deployable to staging.
- `feature/*`: new features, branched from `develop`, merged back via PR.
- `fix/*`: bug fixes, branched from `develop` or `main` for hotfixes.
- `docs/*`: documentation-only changes from `develop`.

## Workflow
1. Create branch from `develop`.
2. Implement and test.
3. Open PR to `develop`.
4. Review and merge.
5. Deploy to staging from `develop`.
6. Open release PR to `main` and tag after merge.

## Commit Messages
Follow Conventional Commits:
`<type>(<scope>): <description>`

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.

Examples:
- `feat(mcp): add data-etsy custom server`
- `fix(docker): correct network subnet configuration`
- `docs(setup): update onboarding steps`
