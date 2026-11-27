# Eclipse Share — Cloudflare Worker + R2

This service provides internet-accessible, expiring links for Eclipse media. It is intentionally separate from the existing Vercel AI-research backend.

## What it supports

- **Authenticated direct streams:** the Worker stores upstream headers encrypted in R2 and proxies the media response, including byte-range requests used by seeking.
- **HLS:** master/media playlists are rewritten so variant playlists, segments, initialization maps, and URI-based keys are requested through the same expiring share capability.
- **Completed files:** a file can be uploaded to R2 and served from a public internet URL with byte-range support, so the receiving device does not need Eclipse or the originating iPhone.
- **Security:** creation endpoints require a server-side admin bearer token; share capabilities are AES-GCM encrypted, expire after at most seven days, and do not reveal upstream URLs or provider headers. Redirect destinations are checked and credentials are stripped on cross-origin redirects.

## Deploy

### GitHub Actions deployment (recommended)

The repository includes `.github/workflows/deploy-cloudflare-share.yml`. After this PR is merged, add the following under **GitHub → Settings → Secrets and variables → Actions**:

**Repository secrets**
- `CLOUDFLARE_API_TOKEN`: Cloudflare API token scoped to the target account with Workers Scripts: Edit and R2 Storage: Edit permissions.
- `CLOUDFLARE_ACCOUNT_ID`: the Cloudflare account ID.
- `SHARE_ADMIN_TOKEN`: a long random secret used by Eclipse to create share links.
- `SHARE_ENCRYPTION_KEY`: a 32-byte key, base64 encoded. Generate with `openssl rand -base64 32`.

**Repository variable**
- `CLOUDFLARE_WORKER_BASE_URL`: the exact public URL for the Worker, e.g. `https://eclipse-share.<your-account-subdomain>.workers.dev` (or your configured custom domain).

Then merge the PR and run **Actions → Deploy Cloudflare Share Worker → Run workflow**. The workflow creates the `eclipse-shares` R2 bucket if it does not exist, uploads both secrets directly to Cloudflare, and deploys the Worker. It never prints secret values. The workflow can also redeploy automatically when `cloudflare-share/**` changes on `main`.

### Manual local deployment

1. Create a Cloudflare R2 bucket named `eclipse-shares`.
2. Install Wrangler in this directory and run `npx wrangler login`.
3. Generate the 32-byte encryption key with `openssl rand -base64 32`.
4. Set `SHARE_ADMIN_TOKEN` and `SHARE_ENCRYPTION_KEY` with `wrangler secret put`.
5. Set the Worker public URL in `wrangler.toml`.
6. Run `npx wrangler deploy` and verify `GET /health`.

Never commit secrets or put them in the iOS app bundle or workflow logs.

## API

All creation endpoints require `Authorization: Bearer <SHARE_ADMIN_TOKEN>`.

### Create a direct/HLS stream link

`POST /v1/shares`

```json
{
  "url": "https://provider.example/path/master.m3u8",
  "headers": {
    "Authorization": "Bearer provider-token",
    "Referer": "https://provider.example/"
  },
  "expiresInSeconds": 86400
}
```

Returns `{ "url": "https://.../v1/r/<encrypted-capability>", "expiresAt": "..." }`.

The generated link can be opened by Safari or an HLS-capable player from another network. HLS playlists are rewritten on demand; media bodies are streamed and Range headers are forwarded.

### Create a completed-file upload link

`POST /v1/uploads`

```json
{ "filename": "episode.mp4", "mimeType": "video/mp4", "expiresInSeconds": 86400 }
```

Returns `uploadUrl`, `fileUrl`, and `partSizeBytes`. The iOS app reads the completed file in 8 MiB chunks, sends each chunk to `PUT uploadUrl/parts/{partNumber}`, then posts the ordered part/ETag list to `POST uploadUrl/complete`. This avoids the Worker request-body ceiling for large media files. The current client cap is 10,000 parts (about 80 GiB).

## Important deployment/security notes

- The app-side integration must keep the admin token out of the IPA. A secure device-pairing/authentication flow is required before the iOS app can call the creation endpoints. Do not solve this by hardcoding the token in Swift or Info.plist.
- The current Worker blocks obvious private/local IP ranges and validates redirect targets. Before production, add a strict provider/CDN hostname allowlist appropriate to the user's configured stream providers; DNS-level rebinding defenses should also be reviewed.
- R2 storage and egress may incur charges. Set Cloudflare spending limits and an R2 lifecycle rule for expired objects. The Worker checks expiration at read time; lifecycle cleanup is also recommended.
- HLS playlists larger than 2 MiB are rejected rather than buffered without a bound.
- The Worker is not deployed until the repository owner configures the Cloudflare Actions secrets and variable listed above and runs the deployment workflow.

## Local checks

`npx wrangler dev` runs the Worker locally after configuring a local R2 bucket binding and secrets in `.dev.vars`. Never commit `.dev.vars`.
