# Contributing

Thank you for helping improve the Concert Operate Demo Reservation Board.

This is the RHEL VM / OpenShift edition. A sister repo, `concert-demo-reservations-cloud`, runs on
IBM Cloud Code Engine. Features that apply to both are ported by hand, so mention in your PR if the
other edition needs the same change.

## Table of contents

1. [Local development setup](#1-local-development-setup)
2. [Branch and pull-request workflow](#2-branch-and-pull-request-workflow)
3. [Commit message format](#3-commit-message-format)
4. [Versioning and changelog](#4-versioning-and-changelog)
5. [Code style guidelines](#5-code-style-guidelines)
6. [Reporting bugs and requesting features](#6-reporting-bugs-and-requesting-features)

---

## 1. Local development setup

**Requirements:** Python 3.6 or newer and `git`. No other dependencies: the app uses the standard
library only. (`openssl` is only needed if you turn on the built-in HTTPS.)

```bash
git clone https://github.com/raghuhulgundi/concert-demo-reservations.git
cd concert-demo-reservations

# Local config: plain HTTP on port 8080, sign-in off
cp config.example.json config.json
# then edit config.json and set:  "port": 8080,  "tls": false

python3 server.py
# Open http://localhost:8080
```

Reservations are stored in `data/reservations.db` (ignored by git). Delete it to start fresh.
`config.json` is also ignored by git, so your local settings are never committed.

**Syntax check (run before every commit):**

```bash
python3 -m py_compile server.py && echo "OK"
```

---

## 2. Branch and pull-request workflow

`main` is always deployable. **Never push directly to `main`.**

```bash
# 1. Start from the latest main
git checkout main
git pull

# 2. Create a short-lived branch
git checkout -b fix/login-report-times   # or feature/..., docs/..., chore/...

# 3. Make your changes, then commit (see section 3 for message format)
git add <files>
git commit -m "fix: show time of last login in the report"

# 4. Push the branch
git push origin fix/login-report-times

# 5. Open a Pull Request on GitHub and wait for the CI check
# 6. After approval, merge with "Squash and merge" to keep main history clean
# 7. Delete the branch after merging
```

**Branch naming:**

| Prefix | Use for |
|---|---|
| `feature/` | New user-visible functionality |
| `fix/` | Bug fix |
| `docs/` | Documentation only |
| `refactor/` | Code change with no behaviour change |
| `chore/` | Build, CI, dependency, or config updates |

---

## 3. Commit message format

This repo follows [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<optional scope>): <short summary>

<optional body: explain what changed and why, not how>

<optional footer, for example: Closes #42>
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `chore`, `test`

**Examples:**

```
feat(auth): record every successful sign-in
fix(deploy): reserve disk for the OpenShift build
docs: document the JWT signature decision
chore: add CI workflow for syntax checks
```

Keep the summary under 72 characters.

---

## 4. Versioning and changelog

This project follows [Semantic Versioning](https://semver.org/):

- **PATCH** (`1.4.x`): bug fixes and documentation
- **MINOR** (`1.x.0`): new features, backwards-compatible
- **MAJOR** (`x.0.0`): breaking changes

**In a PR that changes behaviour:** add a bullet under `## Unreleased` in `CHANGELOG.md`.

**When cutting a release** (the maintainer does this after merging):

1. Rename `## Unreleased` to `## vX.Y.Z (YYYY-MM-DD)`.
2. Update **both** the `VERSION` file and `__version__` in `server.py`. They must match.
3. Tag the merge commit: `git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin vX.Y.Z`

---

## 5. Code style guidelines

- **Standard library only.** Do not add third-party dependencies.
- **Python 3.6 compatible.** The README promises 3.6 or newer, because that is what some RHEL VMs
  ship. Avoid `dict | dict` (3.9), the walrus operator (3.8), `match` (3.10) and
  `str.removeprefix()` (3.9).
- Follow the existing style: 4-space indent, `%`-formatting for log messages.
- Use `def` instead of `lambda` for named helpers.
- Add docstrings to new public functions and comments for non-obvious decisions.
- All user input goes through `clean_text()`, `clean_multiline()` or `clean_links()`.
- All writes to the database hold `WRITE_LOCK`.
- All secret comparisons use `secrets.compare_digest()` or `hmac.compare_digest()`.
- Never commit `config.json`, `config.openshift.json`, `.env`, `data/` or `certs/`.

---

## 6. Reporting bugs and requesting features

Use the GitHub Issues templates.

- **Bug:** say what you did, what you expected and what happened. Include the `/healthz` output and
  relevant log lines (`journalctl -u demo-reserve` on a VM, `oc logs deployment/demo-reserve` on OpenShift).
- **Feature request:** describe the problem you are trying to solve, not only the solution.

For security issues, **do not open a public issue**. Contact the repo owner directly.
