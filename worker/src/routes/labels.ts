export async function handleGetLabels(request: Request, db: any): Promise<Response> {
  const result = await db
    .prepare("SELECT * FROM user_labels ORDER BY created_at DESC")
    .all();

  return Response.json({ labels: result.results });
}

export async function handleSetLabel(request: Request, db: any): Promise<Response> {
  const body = (await request.json()) as {
    pattern: string;
    category: string;
    subcategory?: string;
  };

  if (!body.pattern || !body.category) {
    return Response.json({ error: "pattern and category required" }, { status: 400 });
  }

  await db
    .prepare("INSERT OR REPLACE INTO user_labels (pattern, category, subcategory) VALUES (?, ?, ?)")
    .bind(body.pattern, body.category, body.subcategory || "")
    .run();

  return Response.json({ success: true });
}
