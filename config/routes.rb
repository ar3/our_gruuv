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
    
    resources :health_check, only: [:index] do
      collection do
        post :test_notification_api
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
        patch :acknowledge_snapshots
      end
    end
    
    # Check-ins health dashboard
    get :check_ins_health, to: 'organizations/check_ins_health#index'
    
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
    resources :abilities, module: :organizations do
      resource :assignment_milestones, only: [:show, :update], module: :abilities
    end
    
    # Assignments management
    resources :assignments, module: :organizations do
      resource :ability_milestones, only: [:show, :update], module: :assignments
    end
    
    # People management
    resources :people, module: :organizations, only: [:show] do
      member do
        get :complete_picture
        get :teammate
        post :update_permission
        get :assignment_selection
        post :update_assignments
      end
      
      # Unified check-ins page (spreadsheet-style giant form)
      resource :check_ins, only: [:show, :update]
      
      # Finalization flow (separate from check-ins)
      resource :finalization, only: [:show, :create] do
        patch :acknowledge, on: :member
      end
      
      # Check-in history pages
      resource :position_check_ins, only: [] do
        collection do
          get :history
        end
      end
      
      resources :assignment_check_ins, only: [] do
        member do
          get :history
        end
      end
      
      resources :aspiration_check_ins, only: [] do
        member do
          get :history
        end
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
    
    # Goals management
    resources :goals, module: :organizations do
      resources :goal_links, only: [:create, :destroy] do
        collection do
          get :new_outgoing_link
          get :new_incoming_link
        end
      end
    end
    
    # Observations management
    resources :observations, module: :organizations do
      collection do
        get :journal  # Shortcut to apply "My Journal" workspace
        get :quick_new  # Quick observation creation from check-ins
      end
      member do
        get :set_ratings, action: :set_ratings
        post :set_ratings, action: :set_ratings
        get :review, action: :review
        post :create_observation, action: :create_observation
        post :post_to_slack, action: :post_to_slack
        get :add_assignments  # Add assignments to draft observation
        get :add_aspirations  # Add aspirations to draft observation
        get :add_abilities    # Add abilities to draft observation
        get :add_observees    # Add observees to draft observation
        patch :save_and_add_assignments  # Save draft and navigate to add assignments
        post :add_rateables  # Add rateables to draft observation
        post :add_observees   # Add observees to draft observation
        patch :update_draft, constraints: { id: /[0-9]+|new/ }  # Update draft observation (supports 'new' for new records)
        post :cancel, constraints: { id: /[0-9]+|new/ }  # Cancel and optionally save draft if story has content (supports 'new' for new records)
        post :publish, constraints: { id: /[0-9]+|new/ }  # Publish draft observation (supports 'new' for new records)
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
    
    # Search functionality
    resource :search, only: [:show], module: :organizations, controller: 'search'
    
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
  resources :people, only: [:show, :edit, :update] do
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
  
  # Test-only routes (only loaded in test environment)
  if Rails.env.test?
    namespace :test do
      get 'auth/sign_in', to: 'auth#sign_in'
      post 'auth/sign_in', to: 'auth#sign_in'
      get 'auth/sign_out', to: 'auth#sign_out'
      post 'auth/sign_out', to: 'auth#sign_out'
      get 'auth/current_user', to: 'auth#current_user'
    end
  end
  
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

  # ENM Alignment Typology App (completely isolated namespace)
  namespace :enm do
    root 'home#index'
    
    resources :assessments, only: [:new, :create, :show, :edit, :update], param: :code do
      member do
        get 'phase/:phase', to: 'assessments#show_phase', as: :phase
        patch 'phase/:phase', to: 'assessments#update_phase'
      end
    end
    
    resources :partnerships, only: [:new, :create, :show, :edit, :update], param: :code do
      member do
        post :add_assessment
        delete 'remove_assessment/:assessment_code', to: 'partnerships#remove_assessment', as: :remove_assessment
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
