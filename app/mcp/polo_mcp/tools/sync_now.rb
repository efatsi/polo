module PoloMcp
  module Tools
    class SyncNow < MCP::Tool
      tool_name "sync_now"
      title "Sync from groups.io now"
      description "Pull the latest emails from groups.io immediately (normally this runs every 15 minutes) and " \
                  "re-extract any thread with new messages. Use when someone may have replied in the last few " \
                  "minutes. Can take ~10-30 seconds."
      input_schema(properties: {})
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true, open_world_hint: true)

      def self.call(server_context:)
        stats = Groupsio::Sync.call(max_topics: 5)
        PoloMcp.respond(stats.merge(synced_at: PoloMcp.time(Time.current)))
      rescue StandardError => e
        Rails.logger.error("[mcp] sync_now failed: #{e.class}: #{e.message}")
        PoloMcp.error("Sync failed: #{e.message}")
      end
    end
  end
end
