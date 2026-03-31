import { getActivitiesForHour, getOcrForHour } from "../lib/db";
import { analyzeHour } from "../lib/ai";

export interface SummarizeParams {
  date: string;
  hour: number;
}

export async function runSummarizeWorkflow(
  env: { DB: any; AI: any },
  params: SummarizeParams
): Promise<{ success: boolean; summary?: string; error?: string }> {
  const { date, hour } = params;

  try {
    // Check if already summarized
    const existing = await env.DB
      .prepare("SELECT id FROM hourly_summaries WHERE date = ? AND hour = ?")
      .bind(date, hour).first();
    if (existing) {
      return { success: true, summary: "Already summarized." };
    }

    // Collect activity data
    const [activities, ocrResults] = await Promise.all([
      getActivitiesForHour(env.DB, date, hour),
      getOcrForHour(env.DB, date, hour),
    ]);

    if (activities.results.length === 0) {
      return { success: true, summary: "No activity." };
    }

    // AGGREGATE activities by app+window before sending to AI
    const aggregated = new Map<string, { app: string; title: string; duration: number }>();
    for (const a of activities.results as any[]) {
      const key = `${a.app_name}|||${a.window_title}`;
      const existing = aggregated.get(key);
      if (existing) {
        existing.duration += (a.duration || 0);
      } else {
        aggregated.set(key, { app: a.app_name, title: a.window_title || "", duration: a.duration || 0 });
      }
    }

    // Filter and format — skip private tabs, loginwindow, and <30s
    const activityText = [...aggregated.values()]
      .filter(a => a.duration >= 30)
      .filter(a => !a.title.toLowerCase().includes("private"))
      .filter(a => !a.title.toLowerCase().includes("incognito"))
      .filter(a => a.app !== "loginwindow")
      .sort((a, b) => b.duration - a.duration)
      .map(a => `${a.app} | "${a.title}" | ${Math.round(a.duration / 60)}min`)
      .join("\n");

    const ocrText = ocrResults.results
      .map((s) => s.ocr_text)
      .filter((t) => t && t.length > 0)
      .join("\n---\n")
      .substring(0, 3000);

    // Fetch user labels for personalized categorization
    const labelsResult = await env.DB
      .prepare("SELECT pattern, category, subcategory FROM user_labels")
      .all();
    const userLabels = labelsResult.results || [];

    // Analyze with AI
    const result = await analyzeHour(env.AI, activityText, ocrText, userLabels as any[]);

    console.log(`Analyzed ${date} h${hour}: ${result.activities.length} activities`);

    // Store summary + structured activities
    await env.DB
      .prepare("INSERT INTO hourly_summaries (date, hour, summary, activities) VALUES (?, ?, ?, ?)")
      .bind(date, hour, result.summary, JSON.stringify(result.activities))
      .run();

    return { success: true, summary: result.summary };
  } catch (err: any) {
    console.error("Summarize error:", err);
    return { success: false, error: err.message || String(err) };
  }
}
