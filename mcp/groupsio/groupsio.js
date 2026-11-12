// Minimal read-only client for the groups.io API (https://groups.io/api).
// Auth: API key from https://groups.io/settings/apikeys, sent as a Bearer token.

const BASE = "https://groups.io/api/v1";

export class GroupsIoError extends Error {
  constructor(type, extra, status) {
    super(`groups.io ${type}${extra ? `: ${extra}` : ""} (HTTP ${status})`);
    this.type = type;
    this.status = status;
  }
}

export class GroupsIo {
  constructor({ apiKey, group }) {
    if (!apiKey) throw new Error("GROUPSIO_API_KEY is not set");
    this.apiKey = apiKey;
    this.group = group;
  }

  async get(endpoint, params = {}) {
    const url = new URL(`${BASE}/${endpoint}`);
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined && v !== null && v !== "") url.searchParams.set(k, String(v));
    }

    for (let attempt = 0; ; attempt++) {
      const res = await fetch(url, {
        headers: { Authorization: `Bearer ${this.apiKey}`, Accept: "application/json" },
      });

      // 429s come back with an empty body; back off with jitter and retry (GETs only).
      if (res.status === 429 && attempt < 4) {
        await new Promise((r) => setTimeout(r, 500 * 2 ** attempt + Math.random() * 250));
        continue;
      }

      const text = await res.text();
      let json;
      try {
        json = text ? JSON.parse(text) : {};
      } catch {
        throw new GroupsIoError("bad_response", text.slice(0, 200), res.status);
      }
      if (!res.ok || json.object === "error") {
        throw new GroupsIoError(json.type || "http_error", json.extra, res.status);
      }
      return json;
    }
  }

  // Follows next_page_token until has_more is false or `max` items are collected.
  async getAll(endpoint, params, max = 500) {
    const items = [];
    let first, page_token;
    do {
      const page = await this.get(endpoint, { ...params, limit: 100, page_token });
      first ??= page;
      items.push(...(page.data || []));
      page_token = page.has_more ? page.next_page_token : undefined;
    } while (page_token && items.length < max);
    return { ...first, data: items.slice(0, max) };
  }

  topics({ limit = 10 } = {}) {
    return this.get("gettopics", { group_name: this.group, limit, sort_field: "recentpostdate", sort_dir: "desc" });
  }

  topic(topicId) {
    return this.getAll("gettopic", { topic_id: topicId, sort_field: "Created", sort_dir: "asc" });
  }

  search({ q, preset_date_range, limit = 25 }) {
    return this.get("searcharchives", {
      group_name: this.group,
      q,
      preset_date_range,
      limit,
      sort_field: "created",
      sort_dir: "desc",
      exclude_sigs: true,
    });
  }
}
