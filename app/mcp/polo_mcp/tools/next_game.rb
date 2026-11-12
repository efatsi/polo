module PoloMcp
  module Tools
    class NextGame < MCP::Tool
      tool_name "next_game"
      title "Next game"
      description "The next upcoming polo game (the one on the website's home page): date, time, location, " \
                  "status, who's playing / maybe / out, plus the full email thread. Use for questions about " \
                  "this week's game, e.g. who's in or what time works for the most people."
      input_schema(
        properties: {
          include_messages: { type: "boolean", description: "Include the thread's messages (default true)" },
        },
      )
      annotations(read_only_hint: true, open_world_hint: false)

      def self.call(server_context:, include_messages: true)
        game = Game.next_up
        return PoloMcp.respond({ game: nil, note: "No upcoming game or recent thread found." }) unless game

        later = Game.upcoming.where.not(id: game.id).limit(3).map { |g| GameSerializer.call(g) }
        PoloMcp.respond({ game: GameSerializer.call(game, messages: include_messages), later_games: later })
      end
    end
  end
end
