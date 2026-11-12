Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "games#current"
  resources :games, only: [:index, :show]

  namespace :admin do
    root "games#index"
    resources :games, only: [:index, :edit, :update] do
      post :extract, on: :member
      post :sync, on: :collection
    end
  end
end
