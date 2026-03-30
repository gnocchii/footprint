import { getSummaries } from "../lib/db";

export async function handleGetSummaries(request: Request, db: any): Promise<Response> {
  const url = new URL(request.url);
  const date = url.searchParams.get("date");

  if (!date) {
    return Response.json({ error: "date query param required (YYYY-MM-DD)" }, { status: 400 });
  }

  const result = await getSummaries(db, date);

  return Response.json({
    date,
    summaries: result.results.map((s: any) => ({
      ...s,
      top_apps: JSON.parse(s.top_apps || "[]"),
      categories: JSON.parse(s.categories || "{}"),
    })),
  });
}
