# Concert Operate Demo Reservation Board

A small web page where people reserve time on the **Robin** and **Yoda** Concert Operate demo environments and open each one from a link. Reservations are a courtesy calendar: they show others who is demoing when, but they don't lock anyone out of the clusters.

**What users see**
- **Status cards:** one card per environment showing "Available now" or "In use" (with who has it and until when), the next few reservations, and an **Open Robin / Open Yoda** button that goes to the cluster.
- **Sign-in (optional):** with IBMid sign-in on, IBMers and the partners you approve log in with their IBMid and their name and email fill in automatically (section 4).
- **Day schedule:** Robin and Yoda side by side. Click a free slot, or drag down a column, to reserve. Click a reservation to see who has it, their contact, and what it's for.
- **Cancel:** people can cancel their own reservations. Admins can cancel anyone's.
- **History:** every reservation is kept, including past and cancelled ones, with filters and a CSV download (section 7).
- **URL changes from the page:** admins update the Robin and Yoda links with an Edit button, and every change is logged (section 6).
- **Time zones:** each person sees times in their own local time zone.

**What it needs:** Python 3.6 or newer and the `openssl` command, both already on RHEL and Ubuntu TechZone VMs. No pip installs, no web server, no database server. Reservations are stored in `data/reservations.db` (SQLite).

**Port:** it serves HTTPS directly on **port 443**, so that's the only port that needs to be open.

## Quick start: deploy on a RHEL VM

These steps work on a fresh RHEL 8 or 9 VM (for example from TechZone). They take about 10 minutes.

**1. Make a read-only GitHub token** (the repo is private, so the VM needs one to download the code)

- **Open the token page:** on GitHub, go to **Settings**, then **Developer settings**, then **Personal access tokens**, then **Fine-grained tokens**, and click **Generate new token**.
- **Settings:** name it `techzone-vm-reservations`. Under **Only select repositories**, pick `concert-demo-reservations`. Under **Repository permissions**, set **Contents** to **Read-only**.
- **Copy the token:** click **Generate token** and copy it right away. GitHub only shows it once.

**2. Download the code and run the installer**

SSH to the VM, then:

```bash
sudo dnf install -y git
sudo git clone https://raghuhulgundi@github.com/raghuhulgundi/concert-demo-reservations.git /opt/demo-reserve
#   when it asks for a password, paste the token
sudo git -C /opt/demo-reserve config credential.helper store   # optional: remember the token for updates
cd /opt/demo-reserve
sudo ./deploy/install-rhel.sh
```

The installer:
- **Packages:** installs Python 3, OpenSSL and curl if they're missing.
- **Config:** creates `config.json` with a random admin key, and adds the VM's names to the HTTPS certificate.
- **Firewall and SELinux:** opens port 443 in firewalld and fixes SELinux labels.
- **Service:** sets the app up to start automatically, starts it, checks it's healthy, and **prints the URL**.

**3. Fill in your settings and run it again**

```bash
sudo vi /opt/demo-reserve/config.json      # admin_emails, auth (section 4), first Robin/Yoda URLs
sudo /opt/demo-reserve/deploy/install-rhel.sh
```

You can run the installer as often as you like. It never overwrites `config.json` or your data.

**What's the URL?**

It's `https://<the VM's public address>`, with no port number, because the app uses 443. The installer prints what it detects, but **the TechZone reservation page is the authority**. Open your reservation in TechZone and look for the VM's public IP or hostname under its details. For example:

- `https://52.118.10.20` if TechZone gives you an IP address.
- `https://my-vm.us-east.techzone.ibm.com` (illustrative) if it gives you a hostname.

Before you turn on IBMid sign-in, two things to check:
- **Prefer a hostname:** use one if TechZone gives you one. The IBMid redirect URL (`https://<host>/auth/callback`) is registered once in IBM's SSO tool and must match exactly. IP addresses may not be accepted there and can change if the VM is re-provisioned.
- **Add it to the certificate:** add that hostname or IP to `tls_extra_names` in `config.json`, delete the `certs/` folder, and rerun the installer to regenerate the certificate.

**Updating later**

```bash
cd /opt/demo-reserve && sudo git pull && sudo ./deploy/install-rhel.sh
```

The sections below explain each setting and the manual steps in more detail.

## 1. Get the code and set your environment links

On the TechZone VM:

```bash
sudo git clone https://raghuhulgundi@github.com/raghuhulgundi/concert-demo-reservations.git /opt/demo-reserve
cd /opt/demo-reserve
sudo cp config.example.json config.json
sudo vi config.json
```

(The installer in the quick start does this copy for you.)

`config.json` holds your real settings (client secret, admin key). It's listed in `.gitignore`, so it never gets committed to the public repo. Only `config.example.json` is in git.

Edit `config.json`:

- **`environments[].url`:** replace the two `REPLACE-with...` values with the Concert Operate console URLs for Robin and Yoda. Until you do, the Open buttons are greyed out. Later changes are easier from the page (section 6).
- **`environments[].description` / `notes`:** optional text shown on each card, for example the cluster name or "log in with the shared demo user from Box".
- **`admin_key`:** change to a long random string (for example the output of `openssl rand -hex 24`).
- **`tls_extra_names`:** add the VM's public hostname and IP address, for example `["useast.services.cloud.techzone.ibm.com", "52.118.10.20"]`. These go into the self-signed certificate.
- **Optional settings:** `slot_minutes` (30), `day_start_hour` / `day_end_hour` for the visible grid (7 to 22), `max_booking_hours` per reservation (8).

Don't put passwords in `notes`: anyone who can reach the page can read them.

## 2. Run it on the TechZone VM

```bash
cd /opt/demo-reserve
sudo python3 server.py     # quick test, then Ctrl+C (port 443 needs sudo)
```

If the VM can't reach GitHub, download the repo as a zip on your laptop (GitHub, **Code**, then **Download ZIP**) and copy it over with `scp` instead.

On first start it creates a self-signed certificate in `certs/` and prints the names it covers. Open `https://<vm-host>`.

**Keep it running as a service:**

```bash
sudo cp /opt/demo-reserve/demo-reserve.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now demo-reserve
sudo systemctl status demo-reserve
journalctl -u demo-reserve -f       # logs
```

On RHEL with SELinux enforcing, if systemd can't start it from `/opt`, run `sudo restorecon -Rv /opt/demo-reserve`.

**Open 443 in the VM firewall** (TechZone already allows it at the network level):

```bash
# RHEL / CentOS
sudo firewall-cmd --permanent --add-service=https && sudo firewall-cmd --reload
# Ubuntu
sudo ufw allow 443/tcp
```

If something else on the VM already uses 443 (for example a web server), stop it first: `sudo ss -ltnp | grep :443` shows what's there.

## 3. The certificate warning

A self-signed certificate means each person sees a "Your connection is not private" warning the first time. They click **Advanced**, then **Proceed**. The connection is still encrypted. To get rid of the warning, use either option below.

**Option A: use a real certificate you already have** (for example one issued for the VM's hostname through IBM). Copy the files over the generated ones and restart:

```bash
sudo cp your-cert-fullchain.pem /opt/demo-reserve/certs/server.crt
sudo cp your-key.pem /opt/demo-reserve/certs/server.key
sudo systemctl restart demo-reserve
```

The `.crt` file should contain the server certificate followed by any intermediate certificates.

**Option B: free Let's Encrypt certificate through Caddy.** This works only if the VM has a public DNS name that the internet can reach on 443. Caddy can verify the name over 443 alone, so port 80 isn't needed.

1. In `config.json`, set `"tls": false`, `"host": "127.0.0.1"` and `"port": 8080`, then restart the service.
2. Install Caddy (see caddyserver.com/docs/install) and put this in `/etc/caddy/Caddyfile`:
   ```
   your-vm-hostname.example.com {
       reverse_proxy 127.0.0.1:8080
   }
   ```
3. `sudo systemctl restart caddy`. Caddy gets and renews the certificate automatically.

If the VM is only reachable on the IBM network or VPN, Let's Encrypt can't reach it, so stay with the self-signed certificate or Option A.

## 4. Turn on IBMid sign-in

With sign-in on, anyone opening the page is sent to IBM to log in with their IBMid first. IBMers get in automatically; partners get in once you add them to the partner list (section 5). Their name and email fill in automatically, their reservations are tied to their account (so they can cancel from any browser), and you can name admins who can cancel anyone's booking.

**Step 1: register the app with IBM's SSO self-service tool**

Go to **w3.ibm.com/tools/sso** (IBM network or VPN) and register a new application. The screens change over time, but you'll be asked for roughly:

- **Protocol:** OpenID Connect (OIDC).
- **Identity provider:** IBMid. This lets IBMers, business partners and customers all sign in with their IBMid. (Don't pick w3id: it only works for IBM employees.)
- **Environment:** start with staging/pre-production to test if the tool offers it, then register production.
- **Redirect URL:** `https://<vm-hostname>/auth/callback`. This must match `redirect_uri` in `config.json` exactly, including `https://` and no trailing slash.
- **Grant type / client type:** authorization code, confidential client (has a client secret). Enable PKCE if asked.
- **Scopes / claims:** `openid`, `profile`, `email`.

When it's approved you get a **client ID**, a **client secret**, and a **discovery URL** (ends in `/.well-known/openid-configuration`).

**Step 2: fill in the `auth` block in `config.json`**

```json
"auth": {
  "enabled": true,
  "provider_name": "IBMid",
  "discovery_url": "https://login.ibm.com/oidc/endpoint/default/.well-known/openid-configuration",
  "client_id": "<from the SSO tool>",
  "client_secret": "<from the SSO tool>",
  "redirect_uri": "https://<vm-hostname>/auth/callback",
  "scopes": "openid profile email",
  "allowed_email_domains": ["ibm.com"],
  "allowed_emails": [],
  "admin_emails": ["you@ibm.com"],
  "session_hours": 12
}
```

- **`discovery_url`:** the one above is IBMid production. If you registered a staging environment, use the discovery URL the SSO tool shows you instead.
- **`admin_emails`:** put your own IBMid email here (and anyone who helps you run the page). Admins can manage the partner list and cancel any reservation from the page. **Set this before you go live**, otherwise nobody can add partners from the page.
- **Who can get in:** an access list is always on.
  - **IBMers:** any `@ibm.com` address, including country subdomains such as `us.ibm.com` or `in.ibm.com`, is always allowed. This is built in and can't be switched off by accident.
  - **Partners:** only people you add on the **Partner access** panel (section 5).
  - **`allowed_email_domains` / `allowed_emails` (optional):** a fixed list in the file, if you'd rather manage some entries there. Most people can leave these alone and use the panel.
- **Keeping the secret out of the file (optional):** leave `client_secret` empty and add `Environment=RESERVE_OIDC_CLIENT_SECRET=...` to the service file instead.

Restart with `sudo systemctl restart demo-reserve`. The log should show `Sign-in with IBMid is on`.

**Troubleshooting**

- **"redirect_uri mismatch" on the IBM page:** the redirect URL registered in the SSO tool and `redirect_uri` in `config.json` differ. They must be identical.
- **"Sign-in unavailable, couldn't reach the sign-in service":** the VM can't reach the discovery URL. Test with `curl -sS <discovery_url>` on the VM. The VM needs outbound HTTPS to the IBM login servers.
- **"didn't share an email address":** the app registration doesn't release the `email` claim. Add the email scope or claim in the SSO tool.
- **"Access needed" page:** the person's IBMid email isn't an IBM address and isn't on the partner list. Add them on the Partner access panel and ask them to click **Try a different account** (or reload). The page tells them which email it saw, which helps when a partner's IBMid uses a different address than you expected.
- **Sign-in loops back to the IBM login:** the page must be opened over `https://`, because the session cookie is marked secure.

## 5. Manage partner access

Sign in with an email listed in `admin_emails`. A **Partner access** button appears under your name in the top right. It opens a panel where you can:

- **Add one person:** enter their email, for example `jane@partnerco.com`. Use this for partners whose IBMid is a personal address such as Gmail or Outlook.
- **Add a whole company:** enter the domain, for example `partnerco.com`. Everyone with an `@partnerco.com` IBMid (and subdomains such as `@emea.partnerco.com`) can sign in.
- **Record who they are:** the Company and Note fields are for your reference, for example "Reseller, joint demo team". The list also shows who added each entry and when.
- **Remove access:** click **Remove**, then **Confirm remove**. It takes effect on that person's next click, even if they're already signed in. Their past reservations stay on the calendar.

**Guardrails:**
- **Public email domains are blocked as whole domains:** you can't add `gmail.com`, `outlook.com` and similar as a domain, because that would let anyone in. Add those partners by individual email instead.
- **IBM addresses don't need adding:** they're always allowed.
- **Where the list lives:** in `data/reservations.db` alongside the bookings, so the normal backup covers it.

**Managing the list from the command line** (optional, uses the admin key):

```bash
# list
curl -k -H "X-Admin-Key: <admin_key>" https://<vm-host>/api/partners
# add a company or a person
curl -k -H "X-Admin-Key: <admin_key>" -H "Content-Type: application/json" \
  -d '{"value":"partnerco.com","company":"Partner Co","note":"Reseller"}' https://<vm-host>/api/partners
# remove (id from the list)
curl -k -X DELETE -H "X-Admin-Key: <admin_key>" https://<vm-host>/api/partners/<id>
```

## 6. Change the Robin and Yoda URLs

When a cluster is rebuilt or moved, update its link from the page. You don't need to touch the VM.

1. Sign in as an admin (an email in `admin_emails`).
2. Click **Edit** next to **Robin** or **Yoda** on its card.
3. Change the **Console URL**, and the description or notes if you like, then click **Save**.

Everyone's page picks up the new link within 30 seconds, without reloading. Reservations aren't affected, because they belong to "Robin" or "Yoda", not to a URL.

**Change history:** each edit records the old value, new value, who changed it and when. You can see it under **Change history** in the Edit dialog.

**`config.json` vs. the page:** the URLs in `config.json` are the starting values. Once you've edited an environment on the page, the page value wins, and editing `config.json` for that environment no longer changes what users see. After the first page edit, keep using the page (or the command below).

**From the command line or a script** (for example right after rebuilding a cluster):

```bash
curl -k -X PUT -H "X-Admin-Key: <admin_key>" -H "Content-Type: application/json" \
  -d '{"url":"https://new-console-url.example.com"}' https://<vm-host>/api/environments/robin
```

Use `robin` or `yoda` (the `id` values in `config.json`). You can also send `description` and `notes`.

## 7. Reservation history

Nothing is ever deleted. Cancelling a reservation marks it **cancelled**, with who cancelled it and when, and frees the slot on the calendar. Past reservations stay in the database too.

Click **History** (top right of the schedule) to see:
- **Every reservation:** date, time, environment, who, purpose, status (upcoming, in progress, completed or cancelled) and when it was booked.
- **Filters:** date range, environment, status, and a search box for name, email or purpose.
- **Totals:** reservation count and hours per environment for the current filters, not counting cancellations.
- **Download CSV:** the filtered list as a spreadsheet, with times in your local time zone plus UTC columns.

**Who sees what:** admins see everyone's history. Everyone else sees only their own reservations. With sign-in off, everyone sees everything.

**From the command line:**

```bash
curl -k -H "X-Admin-Key: <admin_key>" "https://<vm-host>/api/history?from=2026-11-01T00:00:00Z&env=robin&status=cancelled"
```

## 8. Admin tasks

**Cancel any reservation** (`-k` accepts the self-signed certificate):

```bash
curl -k -X DELETE -H "X-Admin-Key: <your admin_key>" https://<vm-host>/api/bookings/<id>
```

Find the id with:

```bash
curl -k "https://<vm-host>/api/bookings?from=2026-11-01T00:00:00Z&to=2026-11-30T00:00:00Z"
```

With sign-in on, the people in `admin_emails` can also cancel any reservation right from the page.

**Back up reservations and history:** copy the `data/` folder (reservations plus the key that keeps people signed in across restarts) and `certs/` if you want to keep the same certificate. Do this before the TechZone reservation for the VM expires, then drop the files into the same paths on the new VM.

**Change links or settings:** edit `config.json`, then `sudo systemctl restart demo-reserve`.

## Updating to a new version

Releases are tagged in GitHub (`v1.0.0`, `v1.1.0` and so on), and `CHANGELOG.md` lists what changed. On the VM:

```bash
cd /opt/demo-reserve
sudo cp -r data data.backup-$(date +%F)    # just in case
sudo git pull                               # or: sudo git checkout v1.1.0
sudo ./deploy/install-rhel.sh               # or just: sudo systemctl restart demo-reserve
curl -k https://localhost/healthz           # shows the running version
```

Your `config.json`, reservations, history, partner list and certificate aren't touched by updates. Database changes are applied automatically on startup. If a new version adds settings, they show up in `config.example.json`. Copy any you want into your `config.json`.

## Alternative: run with Podman or Docker

Inside the container the app listens on 8443, and the host maps 443 to it. Data and the certificate are kept on the `demo-reserve-data` volume.

```bash
cd /opt/demo-reserve
sudo podman build -t demo-reserve -f Containerfile .
sudo podman run -d --name demo-reserve --restart=always -p 443:8443 -v demo-reserve-data:/data demo-reserve
```

## Notes

- **Not access control:** the page doesn't stop anyone from logging into Robin or Yoda outside their slot. It's there so people can see who is demoing and avoid stepping on each other.
- **Who can cancel:** with sign-in on, the person who booked (from any browser) and anyone in `admin_emails`. With sign-in off, only the browser that made the reservation, so people who switch browsers need you to cancel with the admin key.
- **Sign-in is for the page only:** IBMid sign-in protects the reservation page. Robin and Yoda keep their own Concert Operate logins.
