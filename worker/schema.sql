-- Footprint D1 Schema

CREATE TABLE IF NOT EXISTS activity_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  app_name TEXT NOT NULL,
  window_title TEXT DEFAULT '',
  bundle_id TEXT DEFAULT '',
  duration REAL DEFAULT 0,
  category TEXT DEFAULT 'Other'
);

CREATE TABLE IF NOT EXISTS screenshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  ocr_text TEXT DEFAULT '',
  processed_by_ai INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS hourly_summaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  hour INTEGER NOT NULL,
  summary TEXT DEFAULT '',
  activities TEXT DEFAULT '[]',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS chat_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL DEFAULT (datetime('now')),
  role TEXT NOT NULL,
  message TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_labels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pattern TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,
  subcategory TEXT DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON activity_records(timestamp);
CREATE INDEX IF NOT EXISTS idx_screenshots_timestamp ON screenshots(timestamp);
CREATE INDEX IF NOT EXISTS idx_summaries_date ON hourly_summaries(date);
CREATE INDEX IF NOT EXISTS idx_user_labels_pattern ON user_labels(pattern);
