# Deploying haiflow with Cloudflare Zero Trust

Expose haiflow to the internet with two layers of security: Cloudflare Access (identity) + your API key (authorization).

## Prerequisites

- A Cloudflare account (free plan works)
- A domain added to Cloudflare (even a cheap one works)
- `cloudflared` installed: `brew install cloudflared`
- haiflow running locally on port 3333

## 1. Authenticate cloudflared

```bash
cloudflared tunnel login
```

This opens a browser to authorize cloudflared with your Cloudflare account.

## 2. Create a named tunnel

```bash
cloudflared tunnel create haiflow
```

This generates a tunnel ID and credentials file at `~/.cloudflared/<TUNNEL_ID>.json`.

Note your tunnel ID — you'll need it next.

## 3. Create a DNS route

Point a subdomain to your tunnel:

```bash
cloudflared tunnel route dns haiflow haiflow.yourdomain.com
```

This creates a CNAME record in Cloudflare DNS automatically.

## 4. Configure the tunnel

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /Users/<you>/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: haiflow.yourdomain.com
    service: http://localhost:3333
  - service: http_status:404
```

## 5. Add a Cloudflare Access policy

This is the key step — it adds an identity check before requests reach haiflow.

1. Go to [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com)
2. Navigate to **Access > Applications > Add an application**
3. Choose **Self-hosted**
4. Configure:
   - **Application name:** haiflow
   - **Session duration:** 24 hours
   - **Application domain:** `haiflow.yourdomain.com`
5. Add an **Access Policy**:
   - **Policy name:** Allow me
   - **Action:** Allow
   - **Include rule:** Emails — enter your email address
6. Save the application

Now anyone hitting `haiflow.yourdomain.com` must verify their email before the request is even forwarded to your machine.

### Bypass for programmatic access (n8n, cron, webhooks)

Automated clients can't do email login. Create a **Service Token** instead:

1. Go to **Access > Service Auth > Create Service Token**
2. Name it (e.g., `n8n`)
3. Save the **Client ID** and **Client Secret** — they're shown only once
4. Add a second policy to your haiflow application:
   - **Policy name:** Service tokens
   - **Action:** Service Auth
   - **Include rule:** Service Token — select the token you created

Automated clients send both the Cloudflare service token AND your haiflow API key:

```bash
curl -X POST https://haiflow.yourdomain.com/trigger \
  -H "CF-Access-Client-Id: <CLIENT_ID>" \
  -H "CF-Access-Client-Secret: <CLIENT_SECRET>" \
  -H "Authorization: Bearer $HAIFLOW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "explain this codebase", "session": "worker"}'
```

## 6. Start the tunnel

```bash
cloudflared tunnel run haiflow
```

### Run as a background service (persistent)

```bash
# macOS — install as a launch daemon
sudo cloudflared service install
```

The tunnel reconnects automatically after reboots.

## Security layers

With this setup, an attacker needs ALL of these to reach haiflow:

| Layer | What it does | What's needed to bypass |
|-------|-------------|------------------------|
| Cloudflare Access | Identity check before traffic reaches your machine | Your email OTP or a service token |
| HTTPS (automatic) | Encrypts traffic end-to-end | Nothing — always on via Cloudflare |
| `HAIFLOW_API_KEY` | Authorizes API requests | The Bearer token from your `.env` |
| Localhost hooks | Restricts `/hooks/*` to local requests | Physical/shell access to your machine |

Stealing your `.env` alone is no longer enough — the attacker also needs to pass the Cloudflare Access identity check.

## Quick reference

```bash
# Check tunnel status
cloudflared tunnel info haiflow

# List tunnels
cloudflared tunnel list

# Delete tunnel (if needed)
cloudflared tunnel delete haiflow

# View live logs
cloudflared tunnel run --loglevel debug haiflow
```

## Alternatives

| Option | Pros | Cons |
|--------|------|------|
| **Cloudflare Tunnel + Access** (this guide) | Free, identity layer, auto-HTTPS | Requires a domain |
| **Tailscale Funnel** | No domain needed, mesh VPN | Only your Tailscale network can reach it |
| **ngrok + IP restrictions** | Quick setup | Paid for static domains, no identity layer |
| **VPS + Caddy + firewall** | Full control, always-on | More setup, manage Claude Code auth remotely |
