# MCP server exposing the synced game data, so Claude can answer questions like
# "who's in for Sunday?" or "when did we last play at Beaver Creek?".
# Served over Streamable HTTP at /mcp (see McpController).
module PoloMcp
  TOOLS = [
    Tools::NextGame,
    Tools::GetGame,
    Tools::ListGames,
    Tools::SearchMessages,
    Tools::SyncNow,
  ].freeze

  INSTRUCTIONS = <<~TEXT.freeze
    Data for the Crozet bike polo group, synced from its groups.io email list every 15 minutes.
    Each email thread is a "game". Its date, time, location, status and attendance were extracted
    by Claude from the emails, and admins can override them, so treat the raw messages as the
    source of truth when they disagree. Times are US Eastern.
  TEXT

  def self.server
    MCP::Server.new(
      name: "crozet-polo",
      title: "Crozet Bike Polo",
      version: "1.0.0",
      instructions: INSTRUCTIONS,
      tools: TOOLS,
    )
  end

  # Text + structured content in one response.
  def self.respond(data)
    MCP::Tool::Response.new([{ type: "text", text: JSON.pretty_generate(data) }], structured_content: data)
  end

  def self.error(message)
    MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
  end

  def self.time(t) = t&.in_time_zone&.strftime("%a %b %-d, %Y %-l:%M %p %Z")
end
