export interface AiBinding {
  run(model: string, input: Record<string, unknown>): Promise<unknown>;
}

const MODEL = "@cf/meta/llama-3.3-70b-instruct-fp8-fast";

export async function generateSummary(
  ai: AiBinding,
  activities: string,
  ocrTexts: string
): Promise<{ summary: string; categories: Record<string, string>; topApps: { app: string; minutes: number }[] }> {
  const prompt = `You are an activity analysis assistant. Given the following computer activity records and screen text (OCR), produce a JSON response with:
1. "summary": A 2-3 sentence natural language summary of what the user was doing
2. "categories": An object mapping each app name to one of: Productivity, Entertainment, Social, Learning, Communication, Utilities, Other
3. "topApps": An array of {app, minutes} for the top 5 most-used apps, sorted by minutes descending

Activity records:
${activities}

Screen text (OCR):
${ocrTexts}

Respond with valid JSON only, no markdown fences.`;

  const result = await ai.run(MODEL, {
    messages: [
      { role: "system", content: "You are a precise JSON-outputting assistant. Only output valid JSON." },
      { role: "user", content: prompt },
    ],
    max_tokens: 1024,
  }) as { response: string };

  try {
    return JSON.parse(result.response);
  } catch {
    return { summary: result.response, categories: {}, topApps: [] };
  }
}

export async function chatWithContext(
  ai: AiBinding,
  question: string,
  activityContext: string,
  chatHistory: { role: string; message: string }[]
): Promise<string> {
  const messages = [
    {
      role: "system",
      content: `You are Footprint, an AI assistant that knows everything about the user's computer activity. You help them understand how they spent their time. Be concise, specific, and reference actual apps/times from the data. If the data doesn't cover what they're asking about, say so.

Here is the user's recent activity data:
${activityContext}`,
    },
    ...chatHistory.slice(-10).map((m) => ({
      role: m.role as "user" | "assistant",
      content: m.message,
    })),
    { role: "user" as const, content: question },
  ];

  const result = await ai.run(MODEL, {
    messages,
    max_tokens: 512,
  }) as { response: string };

  return result.response;
}
