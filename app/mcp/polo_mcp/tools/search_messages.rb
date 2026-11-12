module PoloMcp
  module Tools
    class SearchMessages < MCP::Tool
      tool_name "search_messages"
      title "Search messages"
      description "Case-insensitive search of synced email messages by text and/or author, newest first. " \
                  "Good for 'when did Diana last say she was out?' or 'who mentioned Beaver Creek?'."
      input_schema(
        properties: {
          query: { type: "string", description: "Text to find in message bodies" },
          author: { type: "string", description: "Part of the sender's name" },
          limit: { type: "integer", minimum: 1, maximum: 100, description: "Default: 25" },
        },
      )
      annotations(read_only_hint: true, open_world_hint: false)

      def self.call(server_context:, query: nil, author: nil, limit: 25)
        return PoloMcp.error("Pass query and/or author.") if query.blank? && author.blank?

        scope = Message.includes(:game).order(sent_at: :desc)
        scope = scope.where("messages.body ILIKE ?", "%#{Message.sanitize_sql_like(query)}%") if query.present?
        scope = scope.where("messages.author_name ILIKE ?", "%#{Message.sanitize_sql_like(author)}%") if author.present?

        results = scope.limit(limit.clamp(1, 100)).map do |m|
          {
            game_id: m.game_id,
            subject: m.game.subject,
            game_date: m.game.starts_at&.to_date&.iso8601,
            from: m.author_name,
            sent_at: PoloMcp.time(m.sent_at),
            text: m.body,
          }
        end
        PoloMcp.respond({ count: results.size, results: results })
      end
    end
  end
end
