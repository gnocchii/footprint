import { insertScreenshot } from "../lib/db";

export async function handleScreenshotIngestion(request: Request, db: any): Promise<Response> {
  const body = (await request.json()) as { timestamp: string; ocrText: string };

  if (!body.timestamp || !body.ocrText) {
    return Response.json({ error: "timestamp and ocrText required" }, { status: 400 });
  }

  await insertScreenshot(db, body.timestamp, body.ocrText);

  return Response.json({ success: true });
}
