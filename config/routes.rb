Rails.application.routes.draw do
  root "pages#home"
  get "healthcheck/index"
  get "/healthcheck", to: "healthcheck#index"
  
  # API routes
  namespace :api do
    post 'companies/teams', to: 'companies#teams'
  end
  
  # Organizations routes
  resources :organizations do
    member do
      patch :switch
    end
    
    resources :huddle_playbooks, except: [:show], module: :organizations
    
    # Slack integration nested under organizations
    resource :slack, only: [:show], module: :organizations, controller: 'slack' do
      collection do
        get :test_connection
        get :list_channels
        post :post_test_message
        get :configuration_status
        patch :update_configuration
        
        # OAuth routes
        get 'oauth/authorize', to: 'slack/oauth#authorize'
        get 'oauth/callback', to: 'slack/oauth#callback'
        delete 'oauth/uninstall', to: 'slack/oauth#uninstall'
      end
    end
  end
  
  # Huddles routes
  resources :huddles, only: [:index, :show, :new, :create] do
    member do
      get :feedback
      post :submit_feedback
      get :join
      post :join_huddle
      get :summary
      post :post_summary_to_slack
    end
  end
  
  # Past huddles for participants
  get '/my-huddles', to: 'huddles#my_huddles', as: :my_huddles
  
  # Profile management
  get '/profile', to: 'people#show', as: :profile
  get '/profile/edit', to: 'people#edit', as: :edit_profile
  patch '/profile', to: 'people#update', as: :update_profile
  
  # Session management
  delete '/logout', to: 'application#logout', as: :logout
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
