import { getStats } from "../lib/db";

export async function handleGetStats(request: Request, db: any): Promise<Response> {
  const url = new URL(request.url);
  const date = url.searchParams.get("date");

  if (!date) {
    return Response.json({ error: "date query param required (YYYY-MM-DD)" }, { status: 400 });
  }

  const stats = await getStats(db, date);

  return Response.json({ date, ...stats });
}
