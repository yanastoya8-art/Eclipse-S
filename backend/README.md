# Eclipse AI research proxy

This is a standalone Vercel Functions project for Eclipse's Spanish-language anime dub date research. It proxies Google Gemini and OpenAI Responses API calls so provider credentials stay in Vercel's server-side environment and are never embedded in the iOS app.

## Deploy

1. Create a Vercel project linked to `yanastoya8-art/Eclipse-S`.
2. Set the project's **Root Directory** to `backend`.
3. Add these Environment Variables in Vercel (Preview and Production as appropriate):
   - `GEMINI_API_KEY` — Google AI Studio API key.
   - `OPENAI_API_KEY` — OpenAI API key.
   - Optional `GEMINI_MODEL` (default `gemini-2.5-flash`).
   - Optional `OPENAI_MODEL` (default `gpt-5.4`).
4. Deploy. The endpoint is `https://YOUR-DEPLOYMENT.vercel.app/api/ai-research/gemini` and `.../openAI`.
5. Set the base URL (without a trailing slash) as the GitHub Actions repository **variable** `SPANISH_DUB_RESEARCH_PROXY_URL`. For local builds, set `SPANISH_DUB_RESEARCH_PROXY_URL = https://YOUR-DEPLOYMENT.vercel.app` in the ignored `Build.local.xcconfig`.

Do not put either provider API key in GitHub Actions, `Build.xcconfig`, `Info.plist`, or the IPA. Only the public proxy base URL belongs in the iOS build configuration.

## API

The iOS client sends a POST request to `/api/ai-research/{provider}`, where provider is `gemini` or `openAI`, with JSON body `{"payload":{...}}`. The server reconstructs the upstream request from the prompt and selects the server-side key/model. The upstream response shape is returned to the existing iOS grounding and source-validation code.

## Abuse protection

The function enforces POST-only requests, a 20 KB prompt limit, a 64 KB body limit, a 25-second upstream timeout, and best-effort per-instance IP throttling. Serverless instances do not share the in-memory throttle. Before production traffic, configure a Vercel Firewall rate-limit rule for `/api/ai-research/*` and monitor provider usage. Do not treat a public app URL as a secret or embed a shared proxy credential in the app.
