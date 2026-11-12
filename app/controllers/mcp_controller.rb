# Streamable HTTP endpoint for the PoloMcp server.
#
# Auth: `Authorization: Bearer $MCP_TOKEN`. The endpoint is disabled (403) when
# MCP_TOKEN isn't set, mirroring how admin is disabled without ADMIN_PASSWORD.
#
# Each request gets a fresh stateless transport that answers with plain JSON
# (no sessions, no SSE streams), which suits a regular Rails request cycle.
class McpController < ActionController::API
  before_action :authenticate!

  def handle
    server = PoloMcp.server
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      server,
      stateless: true,
      enable_json_response: true,
      serve_subscriptions_listen: false,
      # Host/Origin checks guard unauthenticated localhost servers against DNS rebinding.
      # Every request here must carry the bearer token, and Rails' own host authorization applies.
      dns_rebinding_protection: false,
    )
    server.transport = transport

    request.body.rewind
    status, headers, body = transport.call(request.env)

    headers.each { |k, v| response.headers[k] = v }
    self.status = status
    self.response_body = body
  end

  private

  def authenticate!
    expected = ENV["MCP_TOKEN"]
    return head(:forbidden) if expected.blank?

    token = request.authorization.to_s[/\ABearer (.+)\z/, 1].to_s
    return if ActiveSupport::SecurityUtils.secure_compare(token, expected)

    response.headers["WWW-Authenticate"] = 'Bearer realm="crozet-polo-mcp"'
    head :unauthorized
  end
end
