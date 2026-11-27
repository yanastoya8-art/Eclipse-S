# Eclipse backend

This is the Vercel Functions project used by Eclipse. It provides the Spanish-language anime dub research proxy and internet sharing for completed downloads.

## Deploy

1. Create or use the Vercel project linked to `yanastoya8-art/Eclipse-S`.
2. Set the project's **Root Directory** to `backend`.
3. Add these Environment Variables in Vercel (Preview and Production as appropriate):
   - `GEMINI_API_KEY` — Google AI Studio API key.
   - `OPENAI_API_KEY` — OpenAI Responses API key.
   - `BLOB_READ_WRITE_TOKEN` — Vercel Blob read/write token for public, expiring download uploads.
   - Optional `GEMINI_MODEL` (default `gemini-2.5-flash`).
   - Optional `OPENAI_MODEL` (default `gpt-5.4`).
4. Create a Vercel Blob store in the same Vercel project and add its read/write token as `BLOB_READ_WRITE_TOKEN`.
5. Deploy. The upload-token endpoint is `https://YOUR-DEPLOYMENT.vercel.app/api/share/upload-token`.
6. In Eclipse, open **Settings → Storage → Internet Share Links** and enter the backend's HTTPS base URL (without a trailing slash).

No Cloudflare account, Worker, R2 bucket, Cloudflare API token, admin token, or encryption key is used.

## Internet download sharing

The iOS client requests a short-lived Vercel Blob client upload token from `POST /api/share/upload-token`, then uploads the completed local file directly to Vercel Blob. The Vercel read/write token remains server-side and is never embedded in the app.

- Links are public HTTPS URLs and can be opened on devices that do not have Eclipse installed.
- Uploaded objects are configured to expire after one day.
- The current app upload limit is 95 MiB per file.
- This storage-based implementation shares completed downloaded files. It does not relay active provider streams or rewrite HLS playlists; use the existing Copy Stream URL action for those sources.
- The upload-token endpoint has a best-effort per-instance IP throttle. Configure a Vercel Firewall rate-limit rule for `/api/share/upload-token` before production use; serverless instances do not share the in-memory counter.
- Public Blob storage and transfer may incur Vercel usage charges. Review Blob usage and billing limits.

## AI research proxy

The iOS client sends a POST request to `/api/ai-research/{provider}`, where provider is `gemini` or `openAI`, with JSON body `{"payload":{...}}`. The server reconstructs the upstream request from the prompt and selects the server-side key/model. The upstream response shape is returned to the existing iOS grounding and source-validation code.

The function enforces POST-only requests, a 20 KB prompt limit, a 64 KB body limit, a 25-second upstream timeout, and best-effort per-instance IP throttling. Configure a Vercel Firewall rate-limit rule for `/api/ai-research/*` and monitor provider usage.

Do not put provider keys or the Blob read/write token in GitHub Actions, `Build.xcconfig`, `Info.plist`, or the IPA.
