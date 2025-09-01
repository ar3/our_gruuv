Rails.application.routes.draw do
  
  get "dashboard/index"
  get "auth/google_oauth2_callback"
  get "positions/index"
  get "positions/show"
  get "positions/new"
  get "positions/edit"
  # Assignments routes
  resources :assignments
  resources :positions do
    member do
      get :job_description
    end
    collection do
      get :position_levels
    end
  end
  resources :position_types do
    member do
      post :clone_positions
    end
  end
  

  root "pages#home"
  get "healthcheck/index"
  get "/healthcheck", to: "healthcheck#index"
  get "/healthcheck/oauth_test", to: "healthcheck#oauth_test"
  
  # OAuth debug route
  get "/auth/debug", to: "auth#oauth_debug"
  
  # OAuth routes
get '/auth/:provider/callback', to: 'auth#google_oauth2_callback'
get '/auth/failure', to: 'auth#failure'
post '/auth/google_oauth2', to: redirect('/auth/google_oauth2')

# Login page
get '/login', to: 'auth#login', as: :login
  
  # Dashboard
  get '/dashboard', to: 'dashboard#index', as: :dashboard
  
  # API routes
  namespace :api do
    post 'companies/teams', to: 'companies#teams'
  end
  
  # Slack OAuth callback (fixed URL for Slack)
  get 'slack/oauth/callback', to: 'organizations/slack/oauth#callback'
  
  # Organizations routes
  resources :organizations do
    member do
      patch :switch
      get :huddles_review
      post :refresh_slack_channels
      patch :update_huddle_review_channel
      post :trigger_weekly_notification
    end
    
    resources :employees, only: [:index, :new, :create], controller: 'organizations/employees' do
      collection do
        get :new_employee
        post :create_employee
      end
    end
    
    # Employment management wizard
    resources :employment_management, only: [:index, :new, :create], controller: 'organizations/employment_management' do
      collection do
        get :potential_employees
      end
    end
    
    # Employment data uploads
    resources :upload_events, only: [:index, :show, :new, :create, :destroy] do
      member do
        post :process_upload
      end
    end
    
    # Person access permissions within organization context
    resources :person_accesses, only: [:new, :create, :edit, :update, :destroy], controller: 'organizations/person_accesses'
    
    resources :huddle_playbooks, module: :organizations
    
    # Abilities management
    resources :abilities, module: :organizations
    
    # Seats management
    resources :seats, module: :organizations do
      member do
        patch :reconcile
      end
    end
    
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
        
        # Debug endpoints
        get :debug_channels
        get :list_all_channel_types
        get :debug_responses
        get :test_pagination
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


      
      post :post_start_announcement_to_slack
      get :notifications_debug
    end
    
    collection do
      post :start_huddle_from_playbook
      post :post_weekly_summary
    end
  end
  
  # Past huddles for participants
  get '/my-huddles', to: 'huddles#my_huddles', as: :my_huddles
  
  # People routes
  resources :people, only: [:index, :show, :edit, :update] do
    member do
      get :public
      get :teammate
    end
    resources :employment_tenures, only: [:new, :create, :edit, :update, :destroy, :show] do
      collection do
        get :change
        get :add_history

      end
      member do
        get :employment_summary
      end
    end
    
    # Assignment tenures - unified interface for managing assignments and check-ins
    resource :assignment_tenures, only: [:show, :update] do
      collection do
        get :choose_assignments
        post :update_assignments
      end
    end
  end

  # Organization access permissions - moved to organization namespace

# Profile management
get '/profile', to: 'people#show', as: :profile
get '/profile/edit', to: 'people#edit', as: :edit_profile
patch '/profile', to: 'people#update', as: :update_profile

# Impersonation routes
resources :impersonations, only: [:create, :destroy]

# Identity management
post '/profile/identities/connect_google', to: 'people#connect_google_identity', as: :connect_google_identity
delete '/profile/identities/:id', to: 'people#disconnect_identity', as: :disconnect_identity
  
  # Session management
  delete '/logout', to: 'application#logout', as: :logout
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
