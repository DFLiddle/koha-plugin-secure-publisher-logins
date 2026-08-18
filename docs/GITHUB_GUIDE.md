# GitHub Repository Guide (non-developers)

Repository: **https://github.com/DFLiddle/koha-plugin-secure-publisher-logins**

## Development environment (WSL / Debian)

Teamwork Library builds and publishes the plugin from **WSL (Debian)** on a Windows PC. Koha itself runs on remote Linux servers (OVH dev, Digital Ocean production); those servers do **not** need Node.js or Git for normal plugin installation.

| Role | Where |
|------|--------|
| Edit source, `git`, `npm run build` | WSL Debian (`~/Projects/koha-plugin-secure-publisher-logins`) |
| Install `.kpz`, configure Koha | Koha servers via staff UI + SSH |

**Canonical project path in WSL:**

```bash
cd ~/Projects/koha-plugin-secure-publisher-logins
```

If `nvm` is not loaded in a new shell:

```bash
source ~/.nvm/nvm.sh
node --version
```

Build the installable package locally:

```bash
npm ci
npm run build
# Output: dist/koha-plugin-secure-publisher-logins.kpz
```

**GitHub authentication from WSL:** SSH (`git@github.com:DFLiddle/koha-plugin-secure-publisher-logins.git`) or HTTPS with a Personal Access Token.

## What is in git vs Releases

| Location | Contains |
|----------|----------|
| `main` branch | Source code only (Perl, templates, JS, docs) |
| [GitHub Releases](https://github.com/DFLiddle/koha-plugin-secure-publisher-logins/releases) | Built `.kpz` files for Koha upload |
| `dist/` locally | Build output; listed in `.gitignore` |

Do **not** commit `.kpz` files to `main`. GitHub Actions attaches them to Releases when you push a version tag.

## Releasing a new version (automated)

### 1. Bump the version in both places

Edit these to the **same** version (e.g. `1.2.5`):

- `package.json` → `"version"`
- `Koha/Plugin/DFLiddle/SecurePublisherCredentials.pm` → `our $VERSION`

Verify:

```bash
npm run version:check
```

### 2. Commit and push

```bash
git add -A
git commit -m "Release v1.2.5"
git push origin main
```

### 3. Create and push a matching tag

The tag must match `package.json` with a `v` prefix:

```bash
git tag v1.2.5
git push origin v1.2.5
```

### 4. Wait for GitHub Actions

1. Open **Actions** on GitHub
2. The **Release** workflow runs on the tag
3. When it succeeds, open **Releases** — the `.kpz` is attached automatically

### Manual release fallback

If Actions is unavailable, build locally and upload with GitHub CLI:

```bash
npm run build
gh release create v1.2.5 dist/koha-plugin-secure-publisher-logins.kpz \
  --title "Secure Publisher Logins v1.2.5"
```

## Branching (optional)

| Branch | Use |
|--------|-----|
| `main` | Stable releases |
| `develop` | Testing on OVH dev instance |

## What not to commit

- `.env` or secrets
- Local Koha config with encryption keys
- `node_modules/` and `dist/` (listed in `.gitignore`)
- Built `.kpz` files

## Installing from GitHub on a server

Koha administrators only need the **Release `.kpz` file**, not the full Git history. See [INSTALLATION.md](INSTALLATION.md).
