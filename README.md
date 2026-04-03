# Jellyfin Media Stack with Request Automation

Complete media automation stack with Jellyseerr requests, Tailscale Funnel access, and full *arr suite.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     arr-net (Bridge Network)                    │
│                                                                 │
│  jellyfin:8096  →  Tailscale Funnel →  https://optiplexjf...   │
│  jellyseerr:5055 → Tailscale Funnel →  https://seerr...        │
│  radarr:7878                                                    │
│  sonarr:8989                                                    │
│  prowlarr:9696 ← FlareSolverr (Cloudflare bypass)              │
│  qbittorrent:8090                                               │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Environment Setup

Create `.env` file with Tailscale auth keys:

```bash
TS_AUTHKEY=tskey-auth-xxxxxxxxxxxxx          # For optiplexjf
TS_AUTHKEY_JELLYSEERR=tskey-auth-yyyyyyyy    # For seerr (MUST be different key)
```

**Generate auth keys:** https://login.tailscale.com/admin/settings/keys

### 2. Start Stack

```bash
docker compose up -d
```

### 3. Service URLs

| Service | Local URL | Funnel URL |
|---------|-----------|------------|
| **Video Stack** | | |
| Jellyfin | `http://optiplex:8096` | `https://optiplexjf.tailf51ed0.ts.net` |
| Jellyseerr | `http://optiplex:5055` | `https://seerr.tailf51ed0.ts.net` |
| Radarr | `http://optiplex:7878` | - |
| Sonarr | `http://optiplex:8989` | - |
| Prowlarr | `http://optiplex:9696` | - |
| qBittorrent | `http://optiplex:8090` | - |
| **Music Stack** | | |
| Lidarr | `http://optiplex:8686` | - |
| slskd | `http://optiplex:5030` | - |
| Navidrome | `http://optiplex:4533` | `https://music.tailf51ed0.ts.net` |
| Aurral | `http://optiplex:3001` | `https://aurral.tailf51ed0.ts.net` |

**Default credentials:**
- qBittorrent: `admin` / `adminadmin` (change immediately!)
- Radarr/Sonarr/Prowlarr: Set on first login

### Docker Compose Profiles

Tailscale funnel containers use profiles to selectively start/stop. The Jellyfin funnel always runs. Use profiles to reduce bandwidth when streaming 4K.

| Profile | Container | Purpose |
|---------|-----------|---------|
| *(always on)* | `tailscale` | Jellyfin funnel |
| `seerr` | `tailscale-jellyseerr` | Jellyseerr funnel |
| `navidrome` | `tailscale-navidrome` | Navidrome funnel |
| `aurral` | `tailscale-aurral` | Aurral funnel |

```bash
# Default - only Jellyfin funnel
docker compose up -d

# With specific services
docker compose --profile seerr up -d
docker compose --profile navidrome --profile aurral up -d

# All tailscale nodes
docker compose --profile seerr --profile navidrome --profile aurral up -d

# Stop extra funnels when streaming 4K
docker compose stop tailscale-jellyseerr tailscale-navidrome tailscale-aurral
```

---

## Configuration Sequence

### 1. qBittorrent
- Change default password
- Add public trackers (improves download success):
  ```
  udp://tracker.opentrackr.org:1337/announce
  udp://tracker.openbittorrent.com:6969/announce
  udp://tracker.internetwarriors.net:1337/announce
  ```

### 2. Prowlarr + FlareSolverr
1. **Configure FlareSolverr first:**
   - Settings → Apps → Add → FlareSolverr
   - URL: `http://flaresolverr:8191`
   - Test → Save

2. **Add indexers:**
   - 1337x (requires FlareSolverr for Cloudflare)
   - TorrentGalaxy (no Cloudflare)
   - The Pirate Bay (no Cloudflare)
   - EZTV (TV only, no Cloudflare)
   - YTS (movies only, no Cloudflare)

3. **Sync to Radarr/Sonarr:**
   - Settings → Apps → Sonarr/Radarr → Sync Indexers

### 3. Radarr
1. Add root folder: `/movies`
2. Settings → Download Clients → Add qBittorrent
   - Host: `qbittorrent:8090`
   - Category: `radarr` (or leave blank)
3. Settings → Indexers → Add from Prowlarr
4. Settings → Connect → Add Jellyfin (optional, for library rescan)
   - Host: `http://jellyfin:8096`
   - Enable: On Import

### 4. Sonarr
1. Add root folder: `/movies` (or `/tv` if separate)
2. Same as Radarr (qBittorrent, indexers, Jellyfin)

### 5. Jellyseerr
1. Connect to Jellyfin: `http://jellyfin:8096`
2. Add Radarr: `http://radarr:7878`
3. Add Sonarr: `http://sonarr:8989`
4. Configure quality profiles, root folders

### 6. Jellyfin Enhanced Plugin
1. Install plugins:
   - Repository: `https://raw.githubusercontent.com/n00bcodr/jellyfin-plugins/main/10.11/manifest.json`
   - Install: Plugin Pages + Jellyfin Enhanced
2. Configure:
   - Dashboard → Plugins → Jellyfin Enhanced
   - Jellyseerr URL: `http://jellyseerr:5055`
   - Enable Requests Page

---

## Tailscale Funnel Setup

### Architecture

Two separate Tailscale containers = two separate hostnames:

| Container | Hostname | Funnel URL | Purpose |
|-----------|----------|------------|---------|
| `tailscale` | `optiplexjf` | `https://optiplexjf.tailf51ed0.ts.net` | Jellyfin |
| `tailscale-jellyseerr` | `seerr` | `https://seerr.tailf51ed0.ts.net` | Jellyseerr |

### Critical Requirements

1. **Each container MUST have unique auth key** (TS_AUTHKEY vs TS_AUTHKEY_JELLYSEERR)
2. **Clear state directories** when recreating: `./tailscale/state/*` and `./tailscale-jellyseerr/state/*`
3. **DNS propagation** can take up to 10 minutes

### Configuration Files

**Jellyfin Funnel:** `tailscale/config/serve.json`
```json
{
    "TCP": { "443": { "HTTPS": true } },
    "Web": {
        "optiplexjf.tailf51ed0.ts.net:443": {
            "Handlers": { "/": { "Proxy": "http://jellyfin:8096" } }
        }
    },
    "AllowFunnel": { "optiplexjf.tailf51ed0.ts.net:443": true }
}
```

**Jellyseerr Funnel:** `tailscale-jellyseerr/config/serve.json`
```json
{
    "TCP": { "443": { "HTTPS": true } },
    "Web": {
        "seerr.tailf51ed0.ts.net:443": {
            "Handlers": { "/": { "Proxy": "http://jellyseerr:5055" } }
        }
    },
    "AllowFunnel": { "seerr.tailf51ed0.ts.net:443": true }
}
```

### Enable Funnels

```bash
docker exec jellyfin-setup-tailscale-1 tailscale funnel --bg --https=443 http://jellyfin:8096
docker exec seerr tailscale funnel --bg --https=443 http://jellyseerr:5055
```

### Verify Status

```bash
docker exec jellyfin-setup-tailscale-1 tailscale funnel status
docker exec seerr tailscale funnel status
```

---

## qBittorrent VPN/Proxy Setup (NordVPN)

### Problem: Real IP Exposed to Torrent Swarms

By default, qBittorrent exposes your real IP to torrent swarms. Even with a VPN container running, qBittorrent may not route traffic through it correctly.

### Solution: NordVPN SOCKS5 Proxy

**Why SOCKS5 instead of Gluetun VPN:**
- Gluetun's port 8388 is **Shadowsocks** (NOT standard SOCKS5)
- qBittorrent only supports standard SOCKS5 proxy
- NordVPN provides direct SOCKS5 proxy servers that work immediately

### Configuration Steps

**1. Get NordVPN SOCKS5 Credentials:**
- Go to: https://my.nordaccount.com/dashboard/nordvpn/
- Copy "Service credentials" (different from regular NordVPN login)

**2. Configure qBittorrent:**

In qBittorrent WebUI (`http://localhost:8090`):
1. **Tools → Options → Connection**
2. **Proxy Server section:**
   - Type: `SOCKS5`
   - Host: `us.socks.nordhold.net` (or other server below)
   - Port: `1080`
   - Authentication: ✅ Checked
   - Username: NordVPN service username
   - Password: NordVPN service password
   - Use proxy for peer connections: ✅ Checked
   - Disable connections not supported by proxies: ✅ Checked
3. **Save**

**3. Test:**
- Use ipleak.net torrent test
- Verify torrent IP shows NordVPN server, NOT your real IP

### NordVPN SOCKS5 Servers

```
us.socks.nordhold.net        # United States
nl.socks.nordhold.net        # Netherlands
se.socks.nordhold.net        # Sweden
amsterdam.nl.socks.nordhold.net
chicago.us.socks.nordhold.net
new-york.us.socks.nordhold.net
```

**Reference:** https://support.nordvpn.com/hc/en-us/articles/20195967385745-NordVPN-proxy-setup-for-qBittorrent

### Limitations

- **Only protects qBittorrent traffic** (not other services)
- **No port forwarding** (NordVPN discontinued this feature)
- **Seeding limited** (incoming connections blocked)
- **Private tracker ratio may suffer** (not connectable)

### Alternative: Full VPN Routing

For complete VPN protection of all qBittorrent traffic:
- Use `network_mode: service:gluetun` in docker-compose.yml
- Routes ALL qBittorrent traffic through Gluetun VPN container
- More complex setup, requires container dependency management

---

### 7. Music Stack

**Services:** Lidarr (album automation), slskd (Soulseek client), Navidrome (streaming), Aurral (discovery UI), Soularr (Lidarr→slskd bridge).

**Configuration:**

1. **Lidarr** (http://localhost:8686):
   - Root folder: `/data/music/artists/`
   - Download client: qBittorrent (host: `qbittorrent`, port: `8090`, category: `music`)
   - Connect Prowlarr for music indexers

2. **slskd** (http://localhost:5030):
   - Soulseek credentials in `slskd/config/slskd.yml`
   - Downloads to `/data/music/singles`
   - API key configured for Soularr integration

3. **Navidrome** (http://localhost:4533):
   - Auto-scans `/data/music/` every hour
   - Create admin account on first login

4. **Aurral** (http://localhost:3001):
   - Connects to Lidarr API, Navidrome, slskd, Last.fm
   - Generates discovery recommendations and Weekly Flow playlists

**Data flow:** Aurral → Lidarr (wants album) → Soularr (polls) → slskd (searches Soulseek) → Lidarr (auto-imports)

---

## Music Deduplication

### Problem: slskd Creates Duplicate Files

slskd appends a timestamp suffix when downloading a file that already exists (e.g., `song_639107560465295531.mp3`). This is hardcoded behavior with no skip-existing option.

### Solution: Dedup Script + Cron

**Script:** `scripts/dedupe_music.sh`

Finds files with slskd timestamp suffixes and either:
- Deletes if original `song.mp3` exists
- Renames to original if only timestamped version exists

**Cron setup:**
```bash
# Run every hour to clean slskd duplicates
0 * * * * /home/benkalmus/repos/jellyfin-setup/scripts/dedupe_music.sh >> /var/log/dedupe_music.log 2>&1
```

**To add to crontab:**
```bash
crontab -e
# Add the line above, save and exit
```

**Verify it's running:**
```bash
cat /var/log/dedupe_music.log
```

### Additional Dedup Measures

1. **Soularr config** (`soularr/config.ini`): `search_source = artist` - limits searches to Lidarr-tracked artists only
2. **Tubifarry removed** - plugin was creating duplicate album directories from Spotify imports
3. **Periodic manual cleanup** - check `/opt/jellyfin/music/singles` for duplicate album directories (same album with different naming)

---

## Troubleshooting

### Sonarr Not Downloading Old Episodes (CRITICAL)

**Problem:** Sonarr shows "Release Rejected - Already meets cutoff" but nothing downloads.

**Root Cause:** Sonarr **does NOT** automatically search for episodes older than 14 days. It only monitors RSS feeds for NEW uploads (last 15-60 minutes).

**Official Sonarr FAQ:** https://wiki.servarr.com/Sonarr_FAQ#how-does-sonarr-find-episodes

> "Sonarr will only find releases that are newly uploaded to your indexers. It will not actively try to find releases uploaded in the past."

**Solutions:**

1. **Manual Search (Immediate):**
   - Sonarr → Series → Click show → Magnifying glass → "Search All Missing"

2. **Import Lists (Automated - Recommended):**
   - Settings → Import Lists → Add → Sonarr
   - URL: `http://sonarr:8989` (point to itself or another instance)
   - Enable: "Search for Missing Episodes" ✅
   - Monitor: "Missing Episodes"
   - Refresh: Every 5 minutes
   - This automatically triggers searches for missing content

3. **When Requesting via Jellyseerr:**
   - Request triggers monitoring in Sonarr
   - **You must still click "Search All Missing"** for old episodes
   - Future episodes (aired <14 days) will be caught by RSS automatically

**GitHub Discussion:** https://github.com/Sonarr/Sonarr/issues/6219

---

### Stalled Torrents (0 KB/s)

**Problem:** qBittorrent shows download at 0 KB/s (no seeders), Sonarr won't search alternatives.

**Solution:**

1. **Delete stalled torrent:**
   - qBittorrent → Right-click torrent → Delete
   - Choose: "Delete torrent only" (keep files) or "Delete torrent + files"

2. **Remove from Sonarr queue:**
   - Sonarr → Activity → Queue → Click red X

3. **Search again:**
   - Sonarr → Series → Click show → Search

**Prevention - Configure qBittorrent:**
- Tools → Options → BitTorrent
- Add trackers from: https://github.com/XIU2/TrackersListCollection
- Set "Stop seeding when ratio reaches:" to `1.0`

**Prevention - Configure Sonarr:**
- Settings → Download Clients → qBittorrent
- Enable: "Remove Failed" ✅
- Set failure timeout: `120` minutes

---

### 1337x / Cloudflare Indexers Not Working

**Problem:** "Unable to connect to indexer... blocked by CloudFlare Protection"

**Solution:** FlareSolverr container (already added to stack)

**Configuration:**
1. Prowlarr → Settings → Apps → Add → FlareSolverr
2. URL: `http://flaresolverr:8191`
3. Test → Save
4. Edit 1337x indexer → Base URL: `https://1337x.to`
5. Test → Save

**Test FlareSolverr:**
```bash
curl -L http://localhost:8191/health
```

**Indexers requiring FlareSolverr:**
- 1337x (all mirrors)
- Any indexer showing Cloudflare challenge

**Indexers working WITHOUT FlareSolverr:**
- TorrentGalaxy
- The Pirate Bay
- EZTV
- YTS
- TorrentDownloads
- MagnetDL

---

### Tailscale DNS Not Resolving

**Problem:** `https://seerr.tailf51ed0.ts.net` returns "DNS couldn't find address"

**Cause:** ISP/router DNS servers don't have Tailscale DNS records cached.

**Solutions:**

1. **Change DNS on accessing device (Recommended):**
   - Windows: Set DNS to `1.1.1.1` (Cloudflare) or `8.8.8.8` (Google)
   - Android: Wi-Fi → Long-press network → Modify → Static → DNS: `1.1.1.1`
   - iOS: Settings → Wi-Fi → (i) → Configure DNS → Manual → Add `1.1.1.1`

2. **Wait for DNS propagation:**
   - Can take up to 10 minutes after enabling Funnel

3. **Use Tailscale client on accessing device:**
   - Install Tailscale on phone/Windows
   - Connect to tailnet
   - MagicDNS resolves instantly

**DASAN H660GM Router:**
- ISP-locked, no DNS settings available
- Must change DNS on individual devices

---

### Radarr/Sonarr Not Finding Releases

**Problem:** RSS Sync finds releases but grabs 0.

**Common Causes:**

1. **Quality Profile Mismatch:**
   - Check Settings → Quality Profile
   - Ensure qualities are enabled (WEBDL, BluRay, etc.)

2. **Language Profile:**
   - Only English allowed by default
   - Releases in other languages rejected

3. **Minimum Seeders:**
   - Check indexer settings
   - Default: 1 seeder minimum

4. **Root Folder Not Set:**
   - Radarr/Sonarr won't download without root folder
   - Settings → Media Management → Root Folders

**Debug:**
```bash
docker logs jellyfin-setup-radarr-1 2>&1 | grep -i "reject\|download"
docker logs jellyfin-setup-sonarr-1 2>&1 | grep -i "reject\|download"
```

---

## Directory Structure

```
/opt/jellyfin/
├── movies/              # Radarr root folder
├── tv/                  # Sonarr root folder
├── music/
│   ├── artists/         # Lidarr-managed albums (FLAC)
│   ├── singles/         # slskd + Aurral downloads (MP3)
│   └── liked/           # sldl Spotify/YouTube downloads
└── downloads/
    ├── movies/
    ├── tv/
    └── music/

./ (repo root)
├── config/              # Jellyfin config
├── jellyseerr/config/
├── radarr/config/
├── sonarr/config/
├── prowlarr/config/
├── qbittorrent/config/
├── lidarr/config/
├── slskd/config/
├── navidrome/config/
├── aurral/data/
├── soularr/config.ini
├── scripts/
│   └── dedupe_music.sh  # Slskd duplicate cleanup script
├── tailscale/state/, config/
├── tailscale-jellyseerr/state/, config/
├── tailscale-navidrome/state/, config/
└── tailscale-aurral/state/, config/
```

---

## Useful Commands

### Check Container Status
```bash
docker compose ps
```

### View Logs
```bash
docker logs jellyfin-setup-<service>-1 2>&1 | tail -50
```

### Restart Services
```bash
docker compose restart tailscale tailscale-jellyseerr
docker compose restart jellyfin jellyseerr radarr sonarr
```

### Check Tailscale Status
```bash
docker exec jellyfin-setup-tailscale-1 tailscale status
docker exec seerr tailscale status
```

### Test Funnel Endpoints
```bash
curl -s -o /dev/null -w "%{http_code}\n" https://optiplexjf.tailf51ed0.ts.net/
curl -s -o /dev/null -w "%{http_code}\n" https://seerr.tailf51ed0.ts.net/
```

### API Key Retrieval
```bash
# Radarr/Sonarr/Prowlarr
docker exec jellyfin-setup-<service>-1 cat /config/config.xml | grep ApiKey

# qBittorrent (check logs for initial password)
docker logs jellyfin-setup-qbittorrent-1 2>&1 | grep -i password
```

---

## External Resources

- **Sonarr FAQ:** https://wiki.servarr.com/Sonarr_FAQ
- **Radarr FAQ:** https://wiki.servarr.com/Radarr_FAQ
- **Tailscale Funnel:** https://tailscale.com/kb/1223/tailscale-funnel
- **Prowlarr Indexers:** https://wiki.servarr.com/Prowlarr/indexers
- **Trackers List:** https://github.com/XIU2/TrackersListCollection
- **FlareSolverr:** https://github.com/FlareSolverr/FlareSolverr

---

## Known Limitations

1. **Sonarr RSS Behavior:**
   - Only finds NEW uploads (last 15-60 min)
   - Old episodes require manual search or Import Lists
   - This is **intentional** (to avoid indexer API bans)

2. **Tailscale Funnel Ports:**
   - Only supports ports: 443, 8443, 10000
   - Cannot use custom ports for Funnel

3. **Public Trackers:**
   - Dead torrents common (0 seeders)
   - Use multiple indexers for redundancy
   - Consider private trackers for better retention

4. **Cloudflare Protection:**
   - Many public trackers use Cloudflare
   - FlareSolverr required for 1337x and others
   - Some indexers may still be inaccessible
