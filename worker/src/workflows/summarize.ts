import { getActivitiesForHour, getOcrForHour, saveSummary, markScreenshotsProcessed } from "../lib/db";
import { generateSummary } from "../lib/ai";

export interface SummarizeParams {
  date: string;
  hour: number;
}

export async function runSummarizeWorkflow(
  env: { DB: any; AI: any },
  params: SummarizeParams
): Promise<{ success: boolean; summary?: string }> {
  const { date, hour } = params;

  // Step 1: Collect activity data
  const [activities, ocrResults] = await Promise.all([
    getActivitiesForHour(env.DB, date, hour),
    getOcrForHour(env.DB, date, hour),
  ]);

  if (activities.results.length === 0) {
    return { success: true, summary: "No activity recorded this hour." };
  }

  // Format activity data for the LLM
  const activityText = activities.results
    .map((a: any) => `${a.timestamp} - ${a.app_name} (${a.window_title}) - ${Math.round(a.duration / 60)}min`)
    .join("\n");

  const ocrText = ocrResults.results
    .map((s) => s.ocr_text)
    .filter((t) => t.length > 0)
    .join("\n---\n")
    .substring(0, 3000); // Limit OCR text length

  // Step 2: Analyze with Llama 3.3
  const result = await generateSummary(env.AI, activityText, ocrText);

  // Step 3: Store results
  await saveSummary(
    env.DB,
    date,
    hour,
    result.summary,
    JSON.stringify(result.topApps),
    JSON.stringify(result.categories)
  );

  await markScreenshotsProcessed(env.DB, date, hour);

  // Update activity categories
  for (const [appName, category] of Object.entries(result.categories)) {
    await env.DB
      .prepare("UPDATE activity_records SET category = ? WHERE app_name = ? AND timestamp LIKE ?")
      .bind(category, appName, `${date}%`)
      .run();
  }

  return { success: true, summary: result.summary };
}
