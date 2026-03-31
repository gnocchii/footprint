import { handleActivityIngestion } from "./routes/activity";
import { handleScreenshotIngestion } from "./routes/screenshot";
import { handleGetSummaries } from "./routes/summaries";
import { handleGetStats } from "./routes/stats";
import { handleChat } from "./routes/chat";
import { handleGetHourlyActivities } from "./routes/hourly-activities";
import { handleGetLabels, handleSetLabel } from "./routes/labels";
import { runSummarizeWorkflow } from "./workflows/summarize";

export interface Env {
  DB: D1Database;
  AI: Ai;
  API_KEY: string;
}

function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders())) {
    headers.set(key, value);
  }
  return new Response(response.body, { status: response.status, headers });
}

function authenticate(request: Request, env: Env): boolean {
  if (!env.API_KEY) return true; // No key configured = open
  const authHeader = request.headers.get("Authorization");
  return authHeader === `Bearer ${env.API_KEY}`;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    // Auth check for write endpoints
    if (request.method === "POST" && !authenticate(request, env)) {
      return withCors(Response.json({ error: "Unauthorized" }, { status: 401 }));
    }

    try {
      let response: Response;

      switch (true) {
        case path === "/api/activity" && request.method === "POST":
          response = await handleActivityIngestion(request, env.DB);
          break;

        case path === "/api/screenshot" && request.method === "POST":
          response = await handleScreenshotIngestion(request, env.DB);
          break;

        case path === "/api/summaries" && request.method === "GET":
          response = await handleGetSummaries(request, env.DB);
          break;

        case path === "/api/stats" && request.method === "GET":
          response = await handleGetStats(request, env.DB);
          break;

        case path === "/api/chat" && request.method === "POST":
          response = await handleChat(request, env.DB, env.AI);
          break;

        case path === "/api/hourly-activities" && request.method === "GET":
          response = await handleGetHourlyActivities(request, env.DB);
          break;

        case path === "/api/labels" && request.method === "GET":
          response = await handleGetLabels(request, env.DB);
          break;

        case path === "/api/labels" && request.method === "POST":
          response = await handleSetLabel(request, env.DB);
          break;

        case path === "/api/summarize" && request.method === "POST": {
          // Manual trigger for summarization
          const body = (await request.json()) as { date: string; hour: number };
          const result = await runSummarizeWorkflow(env, { date: body.date, hour: body.hour });
          response = Response.json(result);
          break;
        }

        case path === "/health":
          response = Response.json({ status: "ok", timestamp: new Date().toISOString() });
          break;

        default:
          response = Response.json({ error: "Not found" }, { status: 404 });
      }

      return withCors(response);
    } catch (error: any) {
      console.error("Worker error:", error);
      return withCors(Response.json({ error: error.message || "Internal error" }, { status: 500 }));
    }
  },

  async scheduled(event: ScheduledEvent, env: Env): Promise<void> {
    // Runs every hour — summarize the previous hour
    const now = new Date();
    const prevHour = new Date(now.getTime() - 60 * 60 * 1000);
    const date = prevHour.toISOString().split("T")[0];
    const hour = prevHour.getUTCHours();

    console.log(`Cron triggered: summarizing ${date} hour ${hour}`);
    await runSummarizeWorkflow(env, { date, hour });
  },
} satisfies ExportedHandler<Env>;
