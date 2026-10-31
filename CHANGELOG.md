# Changelog

Versions follow `MAJOR.MINOR.PATCH`. Each release is tagged in git as `vX.Y.Z`.

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
