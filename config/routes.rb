Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "games#current"

  # A browser visiting /mcp gets setup instructions (admin basic auth); MCP clients
  # (bearer token, or not asking for HTML) hit the server itself (see McpController).
  get "mcp", to: "admin/mcp_setup#show", as: :mcp_setup, constraints: ->(req) {
    !req.authorization.to_s.start_with?("Bearer ") && req.headers["Accept"].to_s.include?("text/html")
  }
  match "mcp", to: "mcp#handle", via: [:get, :post, :delete]

  namespace :admin do
    root "games#index"
    resources :games, only: [:index, :edit, :update] do
      post :extract, on: :member
      post :sync, on: :collection
    end
  end
end
