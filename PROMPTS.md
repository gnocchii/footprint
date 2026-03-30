# AI Prompts Used During Development

This document records the AI prompts and interactions used to build cf_ai_footprint.

## Project Planning

**Prompt**: Help me think of good ideas for a Cloudflare AI application assignment that requires: LLM, workflow/coordination, user input via chat or voice, and memory/state. I have an existing macOS activity tracker called Footprint that captures window activity, screenshots, and OCR text — can we replatform it onto Cloudflare?

**Result**: Decided on architecture with Swift app as the capture agent, Cloudflare Worker as the backend, Workers AI (Llama 3.3) for analysis, D1 for storage, and a chat interface for querying activity history.

## Architecture Design

**Prompt**: Plan the implementation for cf_ai_footprint. The Swift app stays as the local capture agent. Cloudflare Worker handles API routing, Llama 3.3 handles summarization and chat, D1 handles storage. I want the UI to look like macOS Screen Time in Settings.

**Result**: Designed a REST API with endpoints for activity ingestion, screenshot OCR ingestion, summary retrieval, stats aggregation, and chat. Planned a cron-triggered summarization workflow.

## Implementation

**Prompt**: Build the Cloudflare Worker with routes for activity ingestion, screenshot OCR, summaries, stats, and chat. Build a summarization workflow that collects hourly data, analyzes with Llama 3.3, and stores results. Then modify the Swift app to: replace OpenAI with CloudflareService, add a Chat tab, and restyle the UI to match macOS Screen Time (stacked horizontal bars, clean grouped layout).

**Result**: Full implementation of:
- Worker API with 6 endpoints + cron trigger
- Summarization pipeline (collect → analyze → store)
- CloudflareService.swift replacing OpenAIService.swift
- ChatView.swift with suggestion chips and message bubbles
- Screen Time-style UI with stacked bars, percentage breakdowns, and color-coded categories

## AI System Prompts (In-App)

### Summarization Prompt (Workers AI)
Used in `worker/src/lib/ai.ts` — `generateSummary()`:
> You are an activity analysis assistant. Given the following computer activity records and screen text (OCR), produce a JSON response with: 1. "summary": A 2-3 sentence natural language summary of what the user was doing, 2. "categories": An object mapping each app name to a category, 3. "topApps": An array of {app, minutes} for the top 5 most-used apps.

### Chat System Prompt (Workers AI)
Used in `worker/src/lib/ai.ts` — `chatWithContext()`:
> You are Footprint, an AI assistant that knows everything about the user's computer activity. You help them understand how they spent their time. Be concise, specific, and reference actual apps/times from the data. If the data doesn't cover what they're asking about, say so.

## Tools Used

- **Claude Code** (Anthropic) — Architecture planning, code generation, code review
- **Xcode 16** — Swift development and testing
- **Wrangler** — Cloudflare Worker development and deployment
