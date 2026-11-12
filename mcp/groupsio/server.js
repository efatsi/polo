#!/usr/bin/env node
// MCP server exposing the crozetbikepolo groups.io archive (read-only).
//
// Env:
// Read from the environment or the repo-root .env file:
//   GROUPSIO_API_KEY  required — create at https://groups.io/settings/apikeys
//   GROUPSIO_GROUP    group name (default: crozetbikepolo)
//   GROUPSIO_TZ       timezone for displayed times (default: America/New_York)

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { GroupsIo } from "./groupsio.js";
import { stripReply } from "./text.js";

// Load the repo-root .env (gitignored). Variables already in the environment win.
const envFile = fileURLToPath(new URL("../../.env", import.meta.url));
if (existsSync(envFile)) process.loadEnvFile(envFile);

const TZ = process.env.GROUPSIO_TZ || "America/New_York";
const client = new GroupsIo({
  apiKey: process.env.GROUPSIO_API_KEY,
  group: process.env.GROUPSIO_GROUP || "crozetbikepolo",
});

const fmtTime = (iso) =>
  iso
    ? new Date(iso).toLocaleString("en-US", {
        timeZone: TZ,
        weekday: "short",
        month: "short",
        day: "numeric",
        year: "numeric",
        hour: "numeric",
        minute: "2-digit",
      })
    : null;

const summarizeTopic = (t) => ({
  topic_id: t.id,
  subject: t.subject,
  started_by: t.name,
  started_at: fmtTime(t.created),
  last_post_at: fmtTime(t.updated),
  num_messages: t.num_messages,
  hashtags: (t.hashtags || []).map((h) => h.name ?? h),
});

const summarizeMessage = (m) => ({
  msg_num: m.msg_num,
  from: m.name,
  user_id: m.user_id,
  sent_at: fmtTime(m.created),
  text: stripReply(m.body || "", { isPlainText: m.is_plain_text }),
});

const json = (data) => ({ content: [{ type: "text", text: JSON.stringify(data, null, 2) }] });

const server = new McpServer({ name: "groupsio", version: "0.1.0" });

server.registerTool(
  "list_topics",
  {
    title: "List recent topics",
    description:
      "List the most recently active email threads (topics) in the bike polo groups.io group, newest activity first.",
    inputSchema: { limit: z.number().int().min(1).max(100).default(10).describe("How many topics to return") },
    annotations: { readOnlyHint: true },
  },
  async ({ limit }) => {
    const res = await client.topics({ limit });
    return json((res.data || []).map(summarizeTopic));
  }
);

server.registerTool(
  "get_thread",
  {
    title: "Read a thread",
    description:
      "Read every message in a thread, oldest first, with quoted reply history stripped so each message shows only what that person newly wrote. " +
      "Omit topic_id to get the most recently active thread (usually this week's game). " +
      "Use this to work out who is playing, who is out, and what time works for the most people.",
    inputSchema: {
      topic_id: z.number().int().optional().describe("Topic ID from list_topics; omit for the most recent thread"),
    },
    annotations: { readOnlyHint: true },
  },
  async ({ topic_id }) => {
    let id = topic_id;
    if (!id) {
      const latest = await client.topics({ limit: 1 });
      id = latest.data?.[0]?.id;
      if (!id) return json({ error: "No topics found in group" });
    }
    const res = await client.topic(id);
    const topic = res.topic ? summarizeTopic(res.topic) : { topic_id: id };
    const messages = (res.data || []).map(summarizeMessage);
    return json({ ...topic, participants: [...new Set(messages.map((m) => m.from))], messages });
  }
);

server.registerTool(
  "search_messages",
  {
    title: "Search the archive",
    description:
      "Full-text search of the group's message archive, newest first. Supports '#tag' for hashtags. Good for questions like 'when did we last play at Crozet Park?'.",
    inputSchema: {
      query: z.string().min(1).describe("Search terms"),
      date_range: z
        .enum(["past_hour", "past_24_hours", "past_week", "past_month", "past_year"])
        .optional()
        .describe("Restrict to a recent window"),
      limit: z.number().int().min(1).max(100).default(25),
    },
    annotations: { readOnlyHint: true },
  },
  async ({ query, date_range, limit }) => {
    const res = await client.search({ q: query, preset_date_range: date_range, limit });
    return json({
      total: res.total_count,
      results: (res.data || []).map((m) => ({
        topic_id: m.topic_id,
        msg_num: m.msg_num,
        from: m.name,
        subject: m.subject,
        sent_at: fmtTime(m.created),
        text: stripReply(m.body || m.summary || ""),
      })),
    });
  }
);

await server.connect(new StdioServerTransport());
