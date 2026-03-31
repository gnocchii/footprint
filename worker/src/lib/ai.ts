export interface AiBinding {
  run(model: string, input: Record<string, unknown>): Promise<unknown>;
}

const MODEL = "@cf/meta/llama-3.3-70b-instruct-fp8-fast";

export interface SummaryResult {
  summary: string;
  categories: Record<string, string>;
  topApps: { app: string; minutes: number }[];
}

export async function generateSummary(
  ai: AiBinding,
  activities: string,
  ocrTexts: string
): Promise<SummaryResult> {
  const prompt = `Analyze this computer activity. Categorize EACH app into exactly one of: Productivity, Entertainment, Social, Learning, Communication, Utilities, Other.

For browsers, look at the window title to determine the category. Examples:
- "YouTube" or "9anime" or "Netflix" = Entertainment
- "GitHub" or "Stack Overflow" or "Xcode" = Productivity
- "Slack" or "Discord" or "Twitter" = Social
- "Zoom" or "FaceTime" or "Messages" = Communication
- "Khan Academy" or "Coursera" = Learning

Be specific in the summary - mention actual content (video names, websites visited, who they were talking to if visible in window titles).

Activity records:
${activities}

${ocrTexts ? `Screen text (OCR):\n${ocrTexts}` : ""}

Respond in this exact JSON format (no markdown, no code fences, just raw JSON):
{"summary":"2-3 detailed sentences about what the user was doing, mentioning specific content","categories":{"AppName":"Category"},"topApps":[{"app":"AppName","minutes":25}]}`;

  try {
    const rawResult = await ai.run(MODEL, {
      messages: [
        { role: "system", content: "You output valid JSON only. No markdown fences, no explanation, just the JSON object." },
        { role: "user", content: prompt },
      ],
      max_tokens: 1024,
    });

    // Workers AI returns { response: <string|object> } — handle both
    const r = rawResult as any;
    let parsed: any;

    if (r?.response && typeof r.response === "object") {
      // Already parsed object — use directly
      parsed = r.response;
    } else {
      // String response — parse it
      let raw = typeof r?.response === "string" ? r.response : JSON.stringify(r);
      console.log("AI raw string response:", raw.slice(0, 500));

      // Handle markdown fences
      const fenceMatch = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (fenceMatch) {
        raw = fenceMatch[1].trim();
      }
      parsed = JSON.parse(raw);
    }

    console.log("AI parsed result:", JSON.stringify(parsed).slice(0, 500));
    return {
      summary: String(parsed.summary || "Activity recorded this hour."),
      categories: parsed.categories && typeof parsed.categories === "object" ? parsed.categories : {},
      topApps: Array.isArray(parsed.topApps) ? parsed.topApps : [],
    };
  } catch (err) {
    console.error("AI summary generation failed:", err);
    // Return a basic summary from the raw activity data
    const appNames = [...new Set(activities.split("\n").map(line => {
      const match = line.match(/- (.+?) \(/);
      return match ? match[1] : null;
    }).filter(Boolean))];

    return {
      summary: `Activity recorded with ${appNames.length} apps: ${appNames.slice(0, 3).join(", ")}.`,
      categories: Object.fromEntries(appNames.map(app => [app, "Other"])),
      topApps: [],
    };
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
      content: `You are Footprint, an AI assistant that knows everything about the user's computer activity. You help them understand how they spent their time. Be concise, specific, and reference actual apps and times from the data provided. If you don't have data for what they're asking, say so honestly.

Here is the user's activity data:
${activityContext}`,
    },
    ...chatHistory.slice(-10).map((m) => ({
      role: m.role as "user" | "assistant",
      content: m.message,
    })),
    { role: "user" as const, content: question },
  ];

  try {
    const result = await ai.run(MODEL, {
      messages,
      max_tokens: 512,
    }) as { response?: string };

    return result?.response || "Sorry, I couldn't generate a response.";
  } catch (err) {
    console.error("Chat AI failed:", err);
    return "Sorry, I'm having trouble connecting to the AI. Please try again.";
  }
}
