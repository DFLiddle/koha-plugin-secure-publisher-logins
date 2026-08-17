# GitHub Repository Guide (non-developers)

Repository: **https://github.com/DFLiddle/koha-erm-publisher-credentials** (create this repo and push this project)

## Development environment (WSL / Debian)

Teamwork Library builds and publishes the plugin from **WSL (Debian)** on a Windows PC. Koha itself runs on remote Linux servers (OVH dev, Digital Ocean production); those servers do **not** need Node.js or Git for normal plugin installation.

| Role | Where |
|------|--------|
| Edit source, `git`, `npm run build` | WSL Debian |
| Install `.kpz`, configure Koha | Koha servers via staff UI + SSH |

**Project path in WSL** (files created on the Windows side are visible here):

```bash
cd /mnt/c/Users/dflid/Projects/koha-erm-publisher-credentials
```

If `nvm` is not loaded in a new shell:

```bash
source ~/.nvm/nvm.sh
node --version
```

Build the installable package:

```bash
npm install
npm run build
# Output: dist/koha-plugin-secure-publisher-logins.kpz
```

**Optional:** If `npm install` is slow on `/mnt/c/`, clone or copy the repo to the Linux filesystem (e.g. `~/Projects/koha-erm-publisher-credentials`), build there, and copy the `.kpz` back to Windows or upload directly.

**GitHub authentication from WSL:** Use HTTPS with a Personal Access Token, or SSH (`git@github.com:DFLiddle/koha-erm-publisher-credentials.git`) if you have keys configured in WSL.

## Initial setup (one time)

1. Create a new **public** or **private** repository on GitHub named `koha-erm-publisher-credentials`
2. In **WSL**, from the project directory (see path above):

```bash
git init
git add .
git commit -m "Initial release: Secure Publisher Credentials plugin v1.1.0"
git branch -M main
git remote add origin https://github.com/DFLiddle/koha-erm-publisher-credentials.git
git push -u origin main
```

## Releasing a new `.kpz` version

1. Edit version in `package.json` and `Koha/Plugin/DFLiddle/SecurePublisherCredentials.pm` (`$VERSION`)
2. Build:

```bash
npm install
npm run build
```

3. Commit and tag:

```bash
git add -A
git commit -m "Release v1.0.1"
git tag v1.0.1
git push origin main --tags
```

4. On GitHub: **Releases → Draft a new release**
   - Choose tag `v1.0.1`
   - Attach `dist/koha-plugin-secure-publisher-logins.kpz`
   - Publish

## Branching (optional)

| Branch | Use |
|--------|-----|
| `main` | Stable releases |
| `develop` | Testing on OVH dev instance |

## What not to commit

- `.env` or secrets
- Local Koha config with encryption keys
- `node_modules/` (listed in `.gitignore`)

## Installing from GitHub on a server

Staff with server access only need the **Release `.kpz` file**, not the full Git history. Use [INSTALLATION.md](INSTALLATION.md).
