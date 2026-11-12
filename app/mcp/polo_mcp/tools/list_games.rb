module PoloMcp
  module Tools
    class ListGames < MCP::Tool
      tool_name "list_games"
      title "List games"
      description "List games without their messages. 'upcoming' is soonest first, 'past' is most recent first, " \
                  "'undated' is threads with no date settled yet. Use for history questions like " \
                  "'how many games did we play in October?' or 'who played last week?'."
      input_schema(
        properties: {
          which: { type: "string", enum: %w[upcoming past undated], description: "Default: past" },
          limit: { type: "integer", minimum: 1, maximum: 100, description: "Default: 20" },
          since: { type: "string", format: "date", description: "Only games on/after this date (YYYY-MM-DD)" },
          until: { type: "string", format: "date", description: "Only games on/before this date (YYYY-MM-DD)" },
        },
      )
      annotations(read_only_hint: true, open_world_hint: false)

      def self.call(server_context:, which: "past", limit: 20, since: nil, **opts)
        scope = case which
                when "upcoming" then Game.upcoming
                when "undated" then Game.undated
                else Game.past
                end
        scope = scope.where(starts_at: Time.zone.parse(since).beginning_of_day..) if since
        scope = scope.where(starts_at: ..Time.zone.parse(opts[:until]).end_of_day) if opts[:until]

        games = scope.includes(:attendances).limit(limit.clamp(1, 100))
        PoloMcp.respond({ which: which, count: games.size, games: games.map { GameSerializer.call(_1) } })
      rescue ArgumentError, TypeError
        PoloMcp.error("since/until must be dates like 2026-11-15.")
      end
    end
  end
end
