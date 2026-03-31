export async function handleGetHourlyActivities(request: Request, db: any): Promise<Response> {
  const url = new URL(request.url);
  const date = url.searchParams.get("date");

  if (!date) {
    return Response.json({ error: "date query param required" }, { status: 400 });
  }

  const result = await db
    .prepare("SELECT * FROM hourly_summaries WHERE date = ? ORDER BY hour")
    .bind(date)
    .all();

  const hours = result.results.map((row: any) => ({
    hour: row.hour,
    summary: row.summary,
    activities: JSON.parse(row.activities || "[]"),
  }));

  return Response.json({ date, hours });
}
