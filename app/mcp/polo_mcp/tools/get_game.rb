module PoloMcp
  module Tools
    class GetGame < MCP::Tool
      tool_name "get_game"
      title "Get a game"
      description "One game's details and its full email thread (quoted replies stripped). " \
                  "Look up by game_id (from list_games/search_messages) or groupsio_topic_id."
      input_schema(
        properties: {
          game_id: { type: "integer" },
          groupsio_topic_id: { type: "integer" },
        },
      )
      annotations(read_only_hint: true, open_world_hint: false)

      def self.call(server_context:, game_id: nil, groupsio_topic_id: nil)
        game = if game_id then Game.find_by(id: game_id)
               elsif groupsio_topic_id then Game.find_by(groupsio_topic_id: groupsio_topic_id)
               end
        return PoloMcp.error("Pass game_id or groupsio_topic_id.") if game_id.nil? && groupsio_topic_id.nil?
        return PoloMcp.error("Game not found.") unless game

        PoloMcp.respond(GameSerializer.call(game, messages: true))
      end
    end
  end
end
