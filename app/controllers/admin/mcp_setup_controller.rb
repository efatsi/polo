module Admin
  # Page at GET /mcp-setup (behind admin basic auth) with instructions for
  # connecting an agent to the MCP server at /mcp (McpController).
  class McpSetupController < BaseController
    def show
      @url = "#{request.base_url}/mcp"
      @token = ENV["MCP_TOKEN"]
      @tools = PoloMcp::TOOLS.map { [_1.name_value, _1.description] }
    end
  end
end
