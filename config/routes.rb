Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "games#current"

  # MCP server for Claude (bearer-token auth; see McpController). Every request to /mcp
  # goes to the server so connector probes always get a real MCP response.
  match "mcp", to: "mcp#handle", via: [:get, :post, :delete]
  # Setup instructions for connecting an agent (admin basic auth).
  get "mcp-setup", to: "admin/mcp_setup#show", as: :mcp_setup

  namespace :admin do
    root "games#index"
    resources :games, only: [:index, :edit, :update] do
      post :extract, on: :member
      post :sync, on: :collection
    end
  end
end
