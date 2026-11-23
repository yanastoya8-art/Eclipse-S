import type { VercelRequest, VercelResponse } from "@vercel/node";

export default function handler(_req: VercelRequest, res: VercelResponse) {
  res.setHeader("Cache-Control", "no-store");
  return res.status(200).json({
    ok: true,
    providers: {
      gemini: Boolean(process.env.GEMINI_API_KEY?.trim()),
      openAI: Boolean(process.env.OPENAI_API_KEY?.trim()),
    },
  });
}
