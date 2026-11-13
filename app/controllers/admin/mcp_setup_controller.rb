module Admin
  # Browser landing page at GET /mcp (behind admin basic auth) with instructions for
  # connecting an agent to the MCP server. MCP clients hitting /mcp with a bearer
  # token, or without asking for HTML, still go to McpController (see routes).
  class McpSetupController < BaseController
    def show
      @url = "#{request.base_url}/mcp"
      @token = ENV["MCP_TOKEN"]
      @tools = PoloMcp::TOOLS.map { [_1.name_value, _1.description] }
    end
  end
end
