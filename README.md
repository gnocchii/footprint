# cf_ai_footprint

**Footprint** is an AI-powered screen time tracker for macOS that understands *what* you were doing, not just *which app* was open. It captures your computer activity, analyzes it with AI, and lets you have a conversation about how you spent your time.

## Architecture

```
┌──────────────────────────────────────────┐
│         Swift Menu Bar App               │
│  ┌──────────┬──────┬──────────┬────────┐ │
│  │ Timeline │ Apps │Categories│  Chat  │ │
│  └──────────┴──────┴──────────┴────────┘ │
│  WindowTracker · ScreenshotService · OCR │
└──────────────────┬───────────────────────┘
                   │  REST API
                   ▼
          ┌──────────────────┐
          │  Cloudflare Worker│
          └────────┬─────────┘
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
   ┌─────────┐ ┌──────────┐ ┌──────────┐
   │   D1    │ │ Cron +   │ │Workers AI│
   │(storage)│ │ Workflow  │ │(Llama3.3)│
   └─────────┘ └──────────┘ └──────────┘
```

### Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **LLM** | Llama 3.3 70B on Workers AI | Activity analysis, summarization, chat |
| **Workflow / Coordination** | Cloudflare Workers + Cron Triggers | API gateway, hourly summarization pipeline |
| **User Input** | Chat tab in native macOS app | Natural language queries about activity |
| **Memory / State** | Cloudflare D1 (SQLite) | Activity records, summaries, chat history |

### How It Works

1. **Capture** — The macOS menu bar app tracks active windows (every 3s), captures screenshots (every 30s), and runs local OCR via Apple's Vision framework.
2. **Sync** — Activity data and OCR text are sent to the Cloudflare Worker API.
3. **Analyze** — Every hour, a cron-triggered workflow collects the hour's data, sends it to Llama 3.3 on Workers AI, and generates a natural language summary with app categorization.
4. **Query** — The Chat tab lets you ask questions like "What did I do this morning?" and get AI-generated answers grounded in your actual activity data.

## Setup

### Prerequisites

- macOS 14.0+
- Xcode 16+
- Node.js 18+
- Cloudflare account (free tier works)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/install-and-update/)

### 1. Deploy the Cloudflare Worker

```bash
cd worker

# Install dependencies
npm install

# Create the D1 database
npx wrangler d1 create footprint-db

# Copy the database_id from the output and update wrangler.toml

# Apply the schema
npx wrangler d1 execute footprint-db --file=schema.sql

# (Optional) Set an API key
npx wrangler secret put API_KEY

# Deploy
npm run deploy
```

Note your deployed Worker URL (e.g., `https://cf-ai-footprint.<account>.workers.dev`).

### 2. Build and Run the macOS App

```bash
# Generate Xcode project (if using xcodegen)
xcodegen generate

# Open in Xcode
open Footprint.xcodeproj
```

Build and run (`Cmd+R`). The app appears as a 🐾 icon in the menu bar.

### 3. Configure

1. Click the menu bar icon → Settings (gear icon)
2. Enter your Worker URL in the **Cloudflare Worker** section
3. (Optional) Enter your API key
4. Grant **Accessibility** and **Screen Recording** permissions when prompted

### Local Development

Run the worker locally:

```bash
cd worker
npm run dev
```

Then set the Worker URL in Settings to `http://localhost:8787`.

## Features

- **Timeline** — Hourly AI-generated summaries of your activity
- **Apps** — Screen Time-style stacked bar chart showing app usage breakdown
- **Categories** — AI-categorized time distribution (Productivity, Entertainment, Social, etc.)
- **Chat** — Ask natural language questions about your computer activity

## Tech Stack

- **Frontend**: SwiftUI (macOS 14+, menu bar app)
- **Backend**: Cloudflare Workers (TypeScript)
- **AI**: Llama 3.3 70B via Workers AI
- **Database**: Cloudflare D1
- **Local Processing**: Apple Vision (OCR), ScreenCaptureKit, Accessibility APIs
