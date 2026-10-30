# Changelog

Versions follow `MAJOR.MINOR.PATCH`. Each release is tagged in git as `vX.Y.Z`.

## v1.0.0 (2026-10-30)

First release.

- **Reservation board:** Robin and Yoda side by side on a day schedule, with live "Available now / In use" cards and Open buttons that link to each Concert Operate console.
- **Booking:** click or drag to reserve, a configurable slot size and maximum length, and double bookings blocked. Times show in each viewer's own time zone.
- **HTTPS on port 443:** served directly by the app, with a self-signed certificate generated on first start or your own certificate dropped into `certs/`.
- **IBMid sign-in:** OpenID Connect with PKCE. `@ibm.com` addresses (and subdomains) are always allowed.
- **Partner access list:** admins add or remove partner emails or company domains from the page. Changes take effect immediately, and public email domains are blocked as whole-domain entries.
- **Reservation history:** cancellations are kept, not deleted. The History view has filters, totals per environment and a CSV download. Admins see everyone's history and other people see their own.
- **No dependencies:** Python 3.6+ standard library and SQLite only. Ships with a systemd unit and a Containerfile.
