export interface D1Binding {
  prepare(query: string): D1PreparedStatement;
  batch<T = unknown>(statements: D1PreparedStatement[]): Promise<D1Result<T>[]>;
}

interface D1PreparedStatement {
  bind(...values: unknown[]): D1PreparedStatement;
  all<T = unknown>(): Promise<D1Result<T>>;
  first<T = unknown>(): Promise<T | null>;
  run(): Promise<D1Result>;
}

interface D1Result<T = unknown> {
  results: T[];
  success: boolean;
}

export async function insertActivities(
  db: D1Binding,
  records: { timestamp: string; appName: string; windowTitle: string; bundleId: string; duration: number; category: string }[]
) {
  const statements = records.map((r) =>
    db
      .prepare("INSERT INTO activity_records (timestamp, app_name, window_title, bundle_id, duration, category) VALUES (?, ?, ?, ?, ?, ?)")
      .bind(r.timestamp, r.appName, r.windowTitle, r.bundleId, r.duration, r.category)
  );
  await db.batch(statements);
}

export async function insertScreenshot(
  db: D1Binding,
  timestamp: string,
  ocrText: string
) {
  await db
    .prepare("INSERT INTO screenshots (timestamp, ocr_text) VALUES (?, ?)")
    .bind(timestamp, ocrText)
    .run();
}

export async function getActivitiesForHour(db: D1Binding, date: string, hour: number) {
  const startHour = hour.toString().padStart(2, "0");
  const endHour = (hour + 1).toString().padStart(2, "0");
  const start = `${date}T${startHour}:00:00`;
  const end = `${date}T${endHour}:00:00`;

  return db
    .prepare("SELECT * FROM activity_records WHERE timestamp >= ? AND timestamp < ? ORDER BY timestamp")
    .bind(start, end)
    .all();
}

export async function getOcrForHour(db: D1Binding, date: string, hour: number) {
  const startHour = hour.toString().padStart(2, "0");
  const endHour = (hour + 1).toString().padStart(2, "0");
  const start = `${date}T${startHour}:00:00`;
  const end = `${date}T${endHour}:00:00`;

  return db
    .prepare("SELECT ocr_text FROM screenshots WHERE timestamp >= ? AND timestamp < ? AND processed_by_ai = 0")
    .bind(start, end)
    .all<{ ocr_text: string }>();
}

export async function saveSummary(
  db: D1Binding,
  date: string,
  hour: number,
  summary: string,
  topApps: string,
  categories: string
) {
  await db
    .prepare("INSERT INTO hourly_summaries (date, hour, summary, top_apps, categories) VALUES (?, ?, ?, ?, ?)")
    .bind(date, hour, summary, topApps, categories)
    .run();
}

export async function markScreenshotsProcessed(db: D1Binding, date: string, hour: number) {
  const startHour = hour.toString().padStart(2, "0");
  const endHour = (hour + 1).toString().padStart(2, "0");
  const start = `${date}T${startHour}:00:00`;
  const end = `${date}T${endHour}:00:00`;

  await db
    .prepare("UPDATE screenshots SET processed_by_ai = 1 WHERE timestamp >= ? AND timestamp < ?")
    .bind(start, end)
    .run();
}

export async function getSummaries(db: D1Binding, date: string) {
  return db
    .prepare("SELECT * FROM hourly_summaries WHERE date = ? ORDER BY hour")
    .bind(date)
    .all();
}

export async function getStats(db: D1Binding, date: string) {
  const appUsage = await db
    .prepare(
      "SELECT app_name, category, SUM(duration) as total_duration FROM activity_records WHERE timestamp LIKE ? GROUP BY app_name ORDER BY total_duration DESC"
    )
    .bind(`${date}%`)
    .all<{ app_name: string; category: string; total_duration: number }>();

  const categoryUsage = await db
    .prepare(
      "SELECT category, SUM(duration) as total_duration FROM activity_records WHERE timestamp LIKE ? AND category != 'Other' GROUP BY category ORDER BY total_duration DESC"
    )
    .bind(`${date}%`)
    .all<{ category: string; total_duration: number }>();

  return { appUsage: appUsage.results, categoryUsage: categoryUsage.results };
}

export async function getActivitiesForDate(db: D1Binding, date: string) {
  return db
    .prepare("SELECT * FROM activity_records WHERE timestamp LIKE ? ORDER BY timestamp")
    .bind(`${date}%`)
    .all();
}

export async function getChatHistory(db: D1Binding, limit = 20) {
  return db
    .prepare("SELECT role, message FROM chat_history ORDER BY timestamp DESC LIMIT ?")
    .bind(limit)
    .all<{ role: string; message: string }>();
}

export async function saveChatMessage(db: D1Binding, role: string, message: string) {
  await db
    .prepare("INSERT INTO chat_history (role, message) VALUES (?, ?)")
    .bind(role, message)
    .run();
}
