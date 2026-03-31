import { getActivitiesForDate } from "../lib/db";

export async function handleCategorize(request: Request, db: any, ai: any): Promise<Response> {
  const body = (await request.json()) as { date: string };
  if (!body.date) {
    return Response.json({ error: "date required" }, { status: 400 });
  }

  const activities = await getActivitiesForDate(db, body.date);
  if (activities.results.length === 0) {
    return Response.json({ date: body.date, categories: [], uncertain: [] });
  }

  // Build a deduplicated summary of activities with durations
  const activityMap = new Map<string, { app: string; title: string; duration: number }>();
  for (const a of activities.results as any[]) {
    const key = `${a.app_name}|||${a.window_title}`;
    const existing = activityMap.get(key);
    if (existing) {
      existing.duration += a.duration || 0;
    } else {
      activityMap.set(key, { app: a.app_name, title: a.window_title || "", duration: a.duration || 0 });
    }
  }

  // Filter out <60s and private/empty titles
  const filtered = [...activityMap.values()]
    .filter(a => a.duration >= 60)
    .filter(a => !a.title.toLowerCase().includes("private"))
    .filter(a => !a.title.toLowerCase().includes("incognito"))
    .filter(a => a.app !== "loginwindow")
    .sort((a, b) => b.duration - a.duration);

  const activityText = filtered
    .map(a => `${a.app} | "${a.title}" | ${Math.round(a.duration / 60)}min`)
    .join("\n");

  const prompt = `You are analyzing a person's computer activity for the day. Your job is to intelligently categorize WHAT they were actually doing — not which app they used.

Rules:
- Never use app names like "Brave Browser" or "Safari" as categories or labels
- Group related activities together (e.g., all anime episodes under "Anime", all YouTube videos by topic)
- Create clean, human-readable labels — NOT raw tab titles. Summarize them.
- For example: "Yuri!!! On ICE - Episode 3 - 9anime" becomes just "Yuri on Ice" under Anime
- Multiple YouTube videos about the same person/topic should be grouped
- Slack, email, Zoom = Productivity (unless clearly social)
- iMessage chatting with friends = Social
- Coding, GitHub, Xcode, terminal = Productivity
- If you're unsure whether something is productive or social (e.g., Discord can be either), put it in "uncertain"

Activity data (App | Window Title | Duration):
${activityText}

Respond with this exact JSON structure (no markdown fences):
{
  "categories": [
    {
      "name": "Entertainment",
      "subcategories": [
        {
          "name": "Anime",
          "entries": [
            {"label": "Yuri on Ice", "minutes": 130},
            {"label": "Ao Haru Ride", "minutes": 45}
          ]
        }
      ]
    }
  ],
  "uncertain": [
    {"activity": "Discord - Purdue Hackers general chat", "suggestedCategory": "Social", "reason": "Could be social or productivity depending on context"}
  ]
}

Categories to use: Entertainment, Productivity, Social, Communication, Learning, Other
Subcategories should be descriptive (e.g., "Anime", "YouTube", "Coding", "Email", "Messaging", "Video Calls", "School", "Shopping")`;

  try {
    const MODEL = "@cf/meta/llama-3.3-70b-instruct-fp8-fast";
    const rawResult = await ai.run(MODEL, {
      messages: [
        { role: "system", content: "You output valid JSON only. No markdown fences, no explanation." },
        { role: "user", content: prompt },
      ],
      max_tokens: 2048,
    });

    let parsed: any;
    const r = rawResult as any;
    if (r?.response && typeof r.response === "object") {
      parsed = r.response;
    } else {
      let raw = typeof r?.response === "string" ? r.response : JSON.stringify(r);
      const fenceMatch = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (fenceMatch) raw = fenceMatch[1].trim();
      parsed = JSON.parse(raw);
    }

    // Cache in D1
    await db.prepare(
      "INSERT OR REPLACE INTO daily_categorizations (date, categorization) VALUES (?, ?)"
    ).bind(body.date, JSON.stringify(parsed)).run();

    return Response.json({ date: body.date, ...parsed });
  } catch (err: any) {
    console.error("Categorize failed:", err);
    return Response.json({ error: err.message }, { status: 500 });
  }
}
