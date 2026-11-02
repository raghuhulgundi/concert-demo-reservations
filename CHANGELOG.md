# Changelog

Versions follow `MAJOR.MINOR.PATCH`. Each release is tagged in git as `vX.Y.Z`.

## v1.5.0 (2026-11-02)

- **Login report now counts page visits:** until now only a fresh IBMid sign-in was recorded, so someone who stayed signed in and kept opening the page showed up once. Each load of the main page or a launch page is now recorded too, with a Visits and Last visit column per person, an "Every page visit" table, and the visits in the CSV. Stored in a new `page_visits` table, about 100 bytes per visit. Background refreshes, health checks and signed-out requests are not counted.
- **Version file fixed:** `VERSION` said 1.3.0 while the app reported 1.4.0. They now match, and CI checks that they stay in sync.
- **Code hygiene:** replaced `lambda` helpers with `def`, removed a `dict | dict` merge that needs Python 3.9 (the README promises 3.6), and added comments for the SESSION_KEY global and the admin-key route for `/api/history`. The ID token signature note is now fuller.
- **GitHub collaboration setup:** added `CONTRIBUTING.md`, a PR template, bug and feature issue templates, and a CI workflow that syntax-checks and smoke-tests the server on every push.

## v1.4.0 (2026-11-02)

- **Login report for admins:** every successful sign-in is recorded (who, when, how they got in). Admins open it from the new **Login report** button, with a per-person summary, filters and CSV download. Also available at `/api/logins`. Ported from the cloud edition (v1.2.0).
- **Login times:** the report shows the time of each login and of each person's last login, not only the day.
- **Comments:** clearer notes in the code on why the ID token signature check relies on TLS (OIDC Core 3.1.3.7).

## v1.3.2 (2026-10-31)

- **Builds on busy shared clusters:** the OpenShift build now reserves 2 GiB of node disk, so the cluster places it on a worker with room and doesn't evict it first when a worker runs low. Found when deploying to a shared IBM Cloud ROKS cluster.

## v1.3.1 (2026-10-30)

- **Sign-in no longer fails with "Sign-in expired":** each sign-in attempt now keeps its own short-lived cookie, so a second tab or a background request can't overwrite the first attempt's state. Browser requests for `/favicon.ico`, touch icons and `robots.txt` return 404 instead of starting a new sign-in. Only page visits (`/` and `/env/<id>`) redirect to IBMid; other unknown paths return 404.
- **Tolerant cookie reading:** one malformed cookie from another site (for example a consent banner cookie with spaces) no longer hides the app's own cookies.
- **Friendlier repeats:** opening `/auth/login` while signed in goes straight to the page, and a repeated callback after a successful sign-in goes home instead of showing an error. Failed callbacks log which cookies arrived, to help with troubleshooting.
- **Git hygiene:** editor swap and backup files (`*.swp`, `*.bak`, `*~`) are ignored.

## v1.3.0 (2026-10-30)

- **Deploy on Red Hat OpenShift:** `deploy/openshift/` contains a UBI 9 Python Containerfile and manifests: ImageStream, binary BuildConfig, PersistentVolumeClaim, Deployment (one replica, Recreate strategy, health checks, restricted security context, rolls out on new builds), Service and an edge Route with HTTP-to-HTTPS redirect. `deploy.sh` checks your login, creates the project, stores settings in a Secret, builds from only the app files, waits for the rollout, and prints the URL and IBMid redirect URL. The README explains how to move data over from the VM.
- **No app code changes:** the same `server.py` runs on the VM and on OpenShift.

## v1.2.2 (2026-10-30)

- **Highlighted notice on launch pages:** a new "Important notice" field, edited in the Edit dialog, shows as a bold, highlighted box right below the Launch console button. Use it for the rules people must not miss, such as "Before your demo". A short first line becomes the box's heading.
- **Bold in details:** wrap text in `**double asterisks**` in the launch page details to make it bold.

## v1.2.1 (2026-10-30)

- **Reserve on the launch page:** Reserve time on Robin's or Yoda's launch page opens the booking form right there. The form suggests the next free slot and shows what's already booked that day. After booking, you stay on the launch page, with your reservation listed.
- **Cancel from the launch page:** your own upcoming reservations show a "YOU" tag and a Cancel button. Admins can cancel anyone's.
- **Status line:** it says "You have it until ..." when the current reservation is yours.

## v1.2.0 (2026-10-30)

- **Launch page per environment** (`/env/robin`, `/env/yoda`): tagline, live status, a Launch console button, longer details (with clickable links), notes, useful links, upcoming reservations and a Reserve time button. The Open buttons on the main page now go here.
- **Taglines on the main cards:** for example "App centric demo" for Robin and "Network centric demo" for Yoda.
- **Edit dialog:** admins can now edit the tagline, details and links too. Every change is logged as before.
- **Upgrading:** new database columns are added automatically on startup. Existing URLs, notes and history are kept.

## v1.1.1 (2026-10-30)

- **README examples:** sample addresses now use the documentation-only range (`203.0.113.x`) and `example.com`, so they can't be mistaken for a real VM.

## v1.1.0 (2026-10-30)

- **Edit environment links from the page:** admins get an Edit button on each card to change the console URL, description and notes. Changes reach every open page within 30 seconds, with no restart.
- **Change log:** every edit records the old value, new value, who and when, shown in the Edit dialog.
- **API:** `PUT /api/environments/<id>` (admin sign-in or admin key) for scripted updates after a cluster rebuild.
- **Upgrading from 1.0.x:** new database tables are created automatically on startup. `config.json` values stay as the defaults until an environment is edited on the page.

## v1.0.1 (2026-10-30)

- **RHEL installer:** `deploy/install-rhel.sh` installs packages, creates `config.json` with a random admin key, opens the firewall, sets SELinux labels, installs the systemd service, runs a health check and prints the URL. It's safe to rerun after config changes or a `git pull`.
- **README quick start:** a new section for RHEL VMs, covering the private-repo token, finding the URL, and updating.

## v1.0.0 (2026-10-30)

First release.

- **Reservation board:** Robin and Yoda side by side on a day schedule, with live "Available now / In use" cards and Open buttons that link to each Concert Operate console.
- **Booking:** click or drag to reserve, a configurable slot size and maximum length, and double bookings blocked. Times show in each viewer's own time zone.
- **HTTPS on port 443:** served directly by the app, with a self-signed certificate generated on first start or your own certificate dropped into `certs/`.
- **IBMid sign-in:** OpenID Connect with PKCE. `@ibm.com` addresses (and subdomains) are always allowed.
- **Partner access list:** admins add or remove partner emails or company domains from the page. Changes take effect immediately, and public email domains are blocked as whole-domain entries.
- **Reservation history:** cancellations are kept, not deleted. The History view has filters, totals per environment and a CSV download. Admins see everyone's history and other people see their own.
- **No dependencies:** Python 3.6+ standard library and SQLite only. Ships with a systemd unit and a Containerfile.
