import { chatWithContext } from "../lib/ai";
import { getActivitiesForDate, getSummaries, getChatHistory, saveChatMessage } from "../lib/db";

export async function handleChat(request: Request, db: any, ai: any): Promise<Response> {
  const body = (await request.json()) as { message: string; date?: string };

  if (!body.message) {
    return Response.json({ error: "message required" }, { status: 400 });
  }

  // Build activity context from today or specified date
  const today = new Date().toISOString().split("T")[0];
  const date = body.date || today;

  const [activities, summaries, history] = await Promise.all([
    getActivitiesForDate(db, date),
    getSummaries(db, date),
    getChatHistory(db, 10),
  ]);

  // Build context string
  let context = `Date: ${date}\n\n`;

  if (summaries.results.length > 0) {
    context += "Hourly summaries:\n";
    for (const s of summaries.results as any[]) {
      context += `- ${s.hour}:00: ${s.summary}\n`;
    }
    context += "\n";
  }

  if (activities.results.length > 0) {
    context += "Activity records:\n";
    for (const a of activities.results as any[]) {
      const time = a.timestamp.split("T")[1]?.substring(0, 5) || "";
      context += `- ${time} ${a.app_name} (${a.window_title}) - ${Math.round(a.duration / 60)}min [${a.category}]\n`;
    }
  }

  if (!summaries.results.length && !activities.results.length) {
    context += "No activity data available for this date.";
  }

  // Get chat history (reversed since DB returns newest first)
  const chatHist = (history.results || []).reverse();

  // Generate response
  const response = await chatWithContext(ai, body.message, context, chatHist);

  // Save both messages
  await saveChatMessage(db, "user", body.message);
  await saveChatMessage(db, "assistant", response);

  return Response.json({ response, date });
}
