export interface AiBinding {
  run(model: string, input: Record<string, unknown>): Promise<unknown>;
}

const MODEL = "@cf/meta/llama-3.3-70b-instruct-fp8-fast";

// Structured activity produced by the AI per hour
export interface AnalyzedActivity {
  label: string;        // Clean human label like "Yuri on Ice"
  category: string;     // Entertainment, Productivity, Social, Communication, Learning, Other
  subcategory: string;  // Anime, YouTube, Coding, Email, Messaging, etc.
  minutes: number;
}

export interface HourAnalysis {
  summary: string;
  activities: AnalyzedActivity[];
}

export async function analyzeHour(
  ai: AiBinding,
  activityText: string,
  ocrText: string,
  userLabels: { pattern: string; category: string; subcategory: string }[]
): Promise<HourAnalysis> {
  const labelContext = userLabels.length > 0
    ? `\nThe user has provided these category preferences (ALWAYS respect these):\n${userLabels.map(l => `- "${l.pattern}" → ${l.category} / ${l.subcategory}`).join("\n")}\n`
    : "";

  const prompt = `Analyze this hour of computer activity. For each distinct activity, produce a clean label and categorize it.

Rules:
- NEVER use app names like "Brave Browser" or "Safari" as labels. Use the actual content.
- Group related items: multiple episodes of the same show → one entry with total time
- Clean labels: "Yuri!!! On ICE - Episode 3 - 9anime" → "Yuri on Ice"
- YouTube videos: summarize what they watched, don't just copy tab titles
- Coding in Xcode/VS Code → label it by project name if visible
- Slack/email → "Slack" or "Email" is fine as label
- Anything under 1 minute total → skip it
- Categories: Entertainment, Productivity, Social, Communication, Learning, Other
- Subcategories: Anime, YouTube, Coding, Email, Messaging, Video Calls, School, Shopping, Browsing, etc.
${labelContext}
Activity data:
${activityText}

${ocrText ? `Screen text (OCR):\n${ocrText}` : ""}

Respond with this exact JSON (no markdown fences):
{"summary":"1-2 sentence summary mentioning specific content","activities":[{"label":"Yuri on Ice","category":"Entertainment","subcategory":"Anime","minutes":35}]}`;

  try {
    const rawResult = await ai.run(MODEL, {
      messages: [
        { role: "system", content: "You output valid JSON only. No markdown fences, no explanation." },
        { role: "user", content: prompt },
      ],
      max_tokens: 2048,
    });

    const r = rawResult as any;
    let parsed: any;
    if (r?.response && typeof r.response === "object") {
      parsed = r.response;
    } else {
      let raw = typeof r?.response === "string" ? r.response : JSON.stringify(r);
      const fenceMatch = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (fenceMatch) raw = fenceMatch[1].trim();
      parsed = JSON.parse(raw);
    }

    return {
      summary: String(parsed.summary || ""),
      activities: Array.isArray(parsed.activities) ? parsed.activities.map((a: any) => ({
        label: String(a.label || ""),
        category: String(a.category || "Other"),
        subcategory: String(a.subcategory || ""),
        minutes: Number(a.minutes) || 0,
      })).filter((a: AnalyzedActivity) => a.minutes >= 1) : [],
    };
  } catch (err) {
    console.error("AI analysis failed:", err);
    return { summary: "Activity recorded this hour.", activities: [] };
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
      content: `You are Footprint, an AI assistant that knows everything about the user's computer activity. Be concise, specific, reference actual apps and times.\n\nActivity data:\n${activityContext}`,
    },
    ...chatHistory.slice(-10).map((m) => ({
      role: m.role as "user" | "assistant",
      content: m.message,
    })),
    { role: "user" as const, content: question },
  ];

  try {
    const result = await ai.run(MODEL, { messages, max_tokens: 512 }) as any;
    return result?.response || "Sorry, I couldn't generate a response.";
  } catch {
    return "Sorry, I'm having trouble connecting to the AI.";
  }
}
