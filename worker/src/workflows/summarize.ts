import { getActivitiesForHour, getOcrForHour, saveSummary, markScreenshotsProcessed } from "../lib/db";
import { generateSummary } from "../lib/ai";

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
      .filter((t) => t && t.length > 0)
      .join("\n---\n")
      .substring(0, 3000);

    console.log(`Summarizing ${date} hour ${hour}: ${activities.results.length} activities, ${ocrText.length} chars OCR`);

    // Step 2: Analyze with Llama 3.3
    const result = await generateSummary(env.AI, activityText, ocrText);

    console.log("Summary result:", JSON.stringify(result));

    // Step 3: Store results — ensure everything is a string for D1
    const topAppsStr = typeof result.topApps === "string"
      ? result.topApps
      : JSON.stringify(result.topApps || []);

    const categoriesStr = typeof result.categories === "string"
      ? result.categories
      : JSON.stringify(result.categories || {});

    await saveSummary(
      env.DB,
      date,
      hour,
      String(result.summary),
      topAppsStr,
      categoriesStr
    );

    await markScreenshotsProcessed(env.DB, date, hour);

    // Update activity categories
    if (result.categories && typeof result.categories === "object") {
      for (const [appName, category] of Object.entries(result.categories)) {
        if (typeof category === "string") {
          await env.DB
            .prepare("UPDATE activity_records SET category = ? WHERE app_name = ? AND timestamp LIKE ?")
            .bind(String(category), String(appName), `${date}%`)
            .run();
        }
      }
    }

    return { success: true, summary: result.summary };
  } catch (err: any) {
    console.error("Summarize workflow error:", err);
    return { success: false, error: err.message || String(err) };
  }
}
