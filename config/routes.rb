Rails.application.routes.draw do
  
  get "auth/google_oauth2_callback"
  # Assignments routes - moved to organization namespace
  
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
  
  
  # Organization switcher
  get '/organizations/switch', to: 'organizations#switch_page', as: :switch_organizations
  
  # API routes
  namespace :api do
    post 'companies/teams', to: 'companies#teams'
  end
  
  # Integration routes
  namespace :integrations do
    resources :pendo_asana, only: [:index] do
      collection do
        post :test_pendo_connection
        post :test_asana_connection
        post :fetch_asana_projects
        post :sync_guides
      end
    end
  end
  
  # Slack OAuth callback (fixed URL for Slack)
  get 'slack/oauth/callback', to: 'organizations/slack/oauth#callback'
  
  # Organizations routes
  resources :organizations do
    member do
      patch :switch
      post :follow
      delete :unfollow
      get :huddles_review
      post :refresh_slack_channels
      patch :update_huddle_review_channel
      post :trigger_weekly_notification
      get :dashboard
      get :celebrate_milestones
    end
    
    resources :employees, only: [:index, :new, :create], controller: 'organizations/employees' do
      collection do
        get :new_employee
        post :create_employee
      end
      member do
        get :audit
      end
    end
    
    # Employment management wizard
    resources :employment_management, only: [:index, :new, :create], controller: 'organizations/employment_management' do
      collection do
        get :potential_employees
      end
    end
    
    # Upload events (consolidated for all upload types)
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
    
    # Assignments management
    resources :assignments, module: :organizations
    
    # Assignment tenures - unified interface for managing assignments and check-ins
    resources :assignment_tenures, module: :organizations, only: [:show, :update] do
      collection do
        post :update_assignments
        get :changes_confirmation
      end
      member do
        get :choose_assignments
      end
    end
    
    # Check-in management
    resources :check_ins, module: :organizations, only: [:show] do
      member do
        patch :finalize_check_in
        patch :bulk_finalize_check_ins
      end
    end
    
    # People management
    resources :people, module: :organizations, only: [:show] do
      member do
        get :complete_picture
        get :teammate
        get 'execute_changes/:maap_snapshot_id', action: :execute_changes, as: :execute_changes
        post 'process_changes/:maap_snapshot_id', action: :process_changes, as: :process_changes
        post :update_permission
      end
    end
    
    # Positions management
    resources :positions, module: :organizations do
      member do
        get :job_description
      end
      collection do
        get :position_levels
      end
    end
    
    # Aspirations management
    resources :aspirations, module: :organizations
    
    # Observations management
    resources :observations, module: :organizations do
      collection do
        get :journal  # Shortcut to apply "My Journal" workspace
      end
      member do
        get :set_ratings, action: :set_ratings
        post :set_ratings, action: :set_ratings
        get :review, action: :review
        post :create_observation, action: :create_observation
        post :post_to_slack, action: :post_to_slack
      end
    end
    
    # Seats management
    resources :seats, module: :organizations do
      member do
        patch :reconcile
      end
    end
    
    # Departments and Teams management
    resources :departments_and_teams, module: :organizations, only: [:index]
    
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
      get :direct_feedback

      
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
    end
              resources :assignments, only: [:show], controller: 'people/assignments'
    resources :employment_tenures, only: [:new, :create, :edit, :update, :destroy, :show] do
      collection do
        get :change
        get :add_history

      end
      member do
        get :employment_summary
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

# Interest submissions for coming soon features
resources :interest_submissions, path: 'interest', only: [:index, :new, :create, :show]

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

  # Coming Soon placeholder pages
  get '/seats', to: 'pages#seats_coming_soon', as: :seats_coming_soon
  get '/aspirations', to: 'pages#aspirations_coming_soon', as: :aspirations_coming_soon
  get '/observations', to: 'pages#observations_coming_soon', as: :observations_coming_soon
  get '/good-issues', to: 'pages#good_issues_coming_soon', as: :good_issues_coming_soon
  get '/diverge-converge', to: 'pages#diverge_converge_coming_soon', as: :diverge_converge_coming_soon
  get '/team-signals', to: 'pages#team_signals_coming_soon', as: :team_signals_coming_soon
  get '/okr3-management', to: 'pages#okr3_management_coming_soon', as: :okr3_management_coming_soon
  get '/hypothesis-management', to: 'pages#hypothesis_management_coming_soon', as: :hypothesis_management_coming_soon
  get '/eligibility-reviews', to: 'pages#eligibility_reviews_coming_soon', as: :eligibility_reviews_coming_soon
  
  # Overview pages for Level 2 navigation
  get '/position-management', to: 'pages#position_management_overview', as: :position_management_overview
  get '/milestones', to: 'pages#milestones_overview', as: :milestones_overview
  get '/huddles-overview', to: 'pages#huddles_overview', as: :huddles_overview
  get '/accountability', to: 'pages#accountability', as: :accountability

  # Kudos permalinks (public observation links)
  get '/kudos/:date/:id', to: 'kudos#show', as: :kudos

  # Defines the root path route ("/")
  # root "posts#index"
end
