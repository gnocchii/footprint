import { insertActivities } from "../lib/db";

interface ActivityRecord {
  timestamp: string;
  appName: string;
  windowTitle: string;
  bundleId: string;
  duration: number;
  category: string;
}

export async function handleActivityIngestion(request: Request, db: any): Promise<Response> {
  const body = (await request.json()) as { records: ActivityRecord[] };

  if (!body.records || !Array.isArray(body.records) || body.records.length === 0) {
    return Response.json({ error: "records array required" }, { status: 400 });
  }

  await insertActivities(db, body.records);

  return Response.json({ success: true, count: body.records.length });
}
