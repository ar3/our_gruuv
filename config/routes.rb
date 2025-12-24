Rails.application.routes.draw do
  
  get "auth/google_oauth2_callback"
  # Assignments routes - moved to organization namespace
  

  root "pages#home"
  get "healthcheck/index"
  get "/healthcheck", to: "healthcheck#index"
  get "/healthcheck/oauth", to: "healthcheck#oauth", as: :healthcheck_oauth
  get "/healthcheck/search", to: "healthcheck#search", as: :healthcheck_search
  get "/healthcheck/notification_api", to: "healthcheck#notification_api", as: :healthcheck_notification_api
  get "/healthcheck/giphy", to: "healthcheck#giphy", as: :healthcheck_giphy
  post "/healthcheck/test_notification_api", to: "healthcheck#test_notification_api"
  post "/healthcheck/test_giphy", to: "healthcheck#test_giphy"
  
  
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
  
  # Asana OAuth callback (fixed URL for Asana)
  get 'asana/oauth/callback', to: 'organizations/company_teammates/asana/oauth#callback'
  
  # Slack webhooks (support both /slack/interactions and /webhooks/slack/interactions)
  post 'slack/interactions', to: 'webhooks/slack#create'
  namespace :webhooks do
    post 'slack/interactions', to: 'slack#create'
    post 'slack/events', to: 'slack#event'
  end

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
      post :refresh_slack_profiles
      get :pundit_healthcheck
      get :accountability_chart
      get :new_refresh_names
      get :new_refresh_slack
    end
    
    resources :employees, only: [:index, :new, :create], controller: 'organizations/employees' do
      collection do
        get :new_employee
        post :create_employee
        get :customize_view
        patch :update_view
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
    
    # Bulk sync events (consolidated for all upload and sync types)
    resources :bulk_sync_events, only: [:index, :show, :new, :create, :destroy] do
      member do
        post :process_sync
      end
    end
    
    # Legacy upload_events routes for backward compatibility
    resources :upload_events, only: [:index, :show, :new, :create, :destroy], controller: 'bulk_sync_events' do
      member do
        post :process_upload, to: 'bulk_sync_events#process_sync'
      end
    end
    
    # Person access permissions within organization context
    resources :person_accesses, only: [:new, :create, :edit, :update, :destroy], controller: 'organizations/person_accesses'
    
    resources :huddle_playbooks, module: :organizations
    
    # Abilities management
    resources :abilities, module: :organizations do
      collection do
        get :customize_view
        patch :update_view
      end
      resource :assignment_milestones, only: [:show, :update], module: :abilities
    end
    
    # Prompt Templates management
    resources :prompt_templates, module: :organizations, except: [:show] do
      resources :prompt_questions, module: :prompt_templates do
        member do
          patch :archive
          patch :unarchive
        end
      end
    end
    
    # Prompts management
    resources :prompts, module: :organizations, constraints: { id: /[0-9]+/ }, except: [:show, :new] do
      collection do
        get :customize_view
        patch :update_view
        post :create
      end
      member do
        patch :close
        post :close_and_start_new
        get :manage_goals
      end
      resources :prompt_goals, module: :prompts, only: [:create, :destroy]
    end
    
    # Assignments management
    resources :assignments, module: :organizations do
      collection do
        get :customize_view
        patch :update_view
      end
      resource :ability_milestones, only: [:show, :update], module: :assignments
    end
    
    # Company teammates management
    resources :company_teammates, module: :organizations, only: [:show, :update] do
      member do
        get :about_me
        get :complete_picture
        get :internal
        get :permissions
        post :update_permissions
        get :assignment_selection
        post :update_assignments
      end
      
      # Unified check-ins page (spreadsheet-style giant form)
      resource :check_ins, controller: 'company_teammates/check_ins', only: [:show, :update] do
        post :save_and_redirect, on: :member
      end
      
      # Goal check-ins page (overlay)
      resource :goal_check_ins, controller: 'company_teammates/goal_check_ins', only: [:show, :update]
      
      resource :one_on_one_link, controller: 'company_teammates/one_on_one_links', only: [:show, :update] do
        member do
          get 'asana/oauth/authorize', to: 'company_teammates/asana/oauth#authorize', as: :asana_oauth_authorize_one_on_one
        end
      end
      
      # Finalization flow (separate from check-ins)
      resource :finalization, controller: 'company_teammates/finalizations', only: [:show, :create] do
        patch :acknowledge, on: :member
      end
      
      # Employment tenures
      resources :employment_tenures, controller: 'company_teammates/employment_tenures', only: [:new, :create, :edit, :update, :destroy, :show] do
        collection do
          get :change
          get :add_history
        end
        member do
          get :employment_summary
        end
      end
      
      # Asana OAuth (nested under company_teammates)
      get 'asana/oauth/authorize', to: 'company_teammates/asana/oauth#authorize', as: :asana_oauth_authorize
    end
    
    # Teammates resource routes for position, assignments, and aspirations
    resources :teammates, module: :organizations, only: [] do
      resource :position, only: [:show, :update], controller: 'teammates/position'
      resources :assignments, only: [:show], controller: 'teammates/assignments'
      resources :aspirations, only: [:show], controller: 'teammates/aspirations'
    end
    
    # Positions management
    resources :positions, module: :organizations do
      collection do
        get :customize_view
        patch :update_view
        get :position_levels
      end
      member do
        get :job_description
        get :manage_assignments
        patch :update_assignments
      end
    end
    
    # Position types management
    resources :position_types, module: :organizations do
      member do
        post :clone_positions
      end
    end
    
    # Aspirations management
    resources :aspirations, module: :organizations
    
    # Goals management
    resources :goals, module: :organizations do
      collection do
        get :customize_view
        patch :update_view
        post :bulk_update_check_ins
      end
      member do
        patch :start
        post :check_in
        patch :set_timeframe
        get :done
        post :complete
        patch :undelete
      end
      resources :goal_links, only: [:create, :destroy] do
        collection do
          get :new_outgoing_link
          get :new_incoming_link
        end
      end
    end
    
    # GIF search
    get 'gifs/search', to: 'organizations/gifs#search'
    
    # Observations management
    resources :observations, module: :organizations do
      collection do
        get :select_type  # Type selection page
        get :new_kudos  # Kudos-specific observation creation
        get :new_feedback  # Feedback-specific observation creation
        get :new_quick_note  # Quick note-specific observation creation
        get :journal  # Shortcut to apply "My Journal" workspace
        get :quick_new  # Quick observation creation from check-ins
        get :filtered_observations  # Filtered observations page (overlay) for check-ins
        get :customize_view
        patch :update_view
      end
      member do
        patch :convert_to_generic
        get :set_ratings, action: :set_ratings
        post :set_ratings, action: :set_ratings
        get :review, action: :review
        post :create_observation, action: :create_observation
        get :share_publicly
        get :share_privately
        post :post_to_slack, action: :post_to_slack
        get :add_assignments  # Add assignments to draft observation
        get :add_aspirations  # Add aspirations to draft observation
        get :add_abilities    # Add abilities to draft observation
        get :manage_observees    # Manage observees for draft observation
        patch :save_and_add_assignments  # Save draft and navigate to add assignments
        post :add_rateables  # Add rateables to draft observation
        patch :manage_observees   # Manage observees for draft observation
        # Support both PATCH and POST (forms submit POST with _method='patch')
        patch :update_draft, constraints: { id: /(\d+|new)/ }  # Update draft observation (supports 'new' for new records)
        post :update_draft, constraints: { id: /(\d+|new)/ }, to: 'observations#update_draft'  # POST with _method override
        post :cancel, constraints: { id: /(\d+|new)/ }  # Cancel and optionally save draft if story has content (supports 'new' for new records)
        post :publish, constraints: { id: /(\d+|new)/ }  # Publish draft observation (supports 'new' for new records)
      end
    end
    
    # Seats management
    resources :seats, module: :organizations do
      collection do
        post :create_missing_employee_seats
        post :create_missing_position_type_seats
        get :customize_view
        patch :update_view
      end
      member do
        patch :reconcile
      end
    end
    
    # Departments and Teams management
    resources :departments_and_teams, module: :organizations, except: [:destroy] do
      member do
        patch :archive
      end
    end
    
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
        
        # Bulk management pages
        get :teammates, to: 'slack/teammates#index'
        patch :update_teammate_association, to: 'slack/teammates#update'
        
        get :channels, to: 'slack/channels#index'
        post :refresh_channels, to: 'slack/channels#refresh_channels'
        post :refresh_groups, to: 'slack/channels#refresh_groups'

        # Per-organization channel settings (overlay UX)
        get 'channels/:target_organization_id/edit',
            to: 'slack/channels#edit',
            as: :edit_channel
        patch 'channels/:target_organization_id',
              to: 'slack/channels#update',
              as: :channel
        # Company-only channel settings (huddle review)
        get 'channels/:target_organization_id/edit-company',
            to: 'slack/channels#edit_company',
            as: :edit_company_channel
        patch 'channels/:target_organization_id/update-company',
              to: 'slack/channels#update_company',
              as: :company_channel
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
  
  # People routes - only public view and employment tenures remain
  resources :people, only: [] do
    member do
      get :public
    end
    resources :assignments, only: [:show], module: :people
  end

  # Organization access permissions - moved to organization namespace

# Impersonation routes
resources :impersonations, only: [:create, :destroy]

# Interest submissions for coming soon features
resources :interest_submissions, path: 'interest', only: [:index, :new, :create, :show]

# Identity management
post '/profile/identities/connect_google', to: 'people#connect_google_identity', as: :connect_google_identity
delete '/profile/identities/:id', to: 'people#disconnect_identity', as: :disconnect_identity

# User preferences
resource :user_preferences, only: [] do
  patch :layout, on: :collection, to: 'user_preferences#update_layout'
  patch :vertical_nav, on: :collection, to: 'user_preferences#update_vertical_nav'
end
  
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

  # Public MAAP routes
  get '/public_maap', to: 'public_maap/index#index', as: :public_maap
  
  # Public MAAP under organizations namespace
  resources :organizations, only: [] do
    get 'public_maap', to: 'organizations/public_maap#show', as: :public_maap
    
    namespace :public_maap, module: 'organizations/public_maap' do
      resources :positions, only: [:index, :show], controller: 'positions'
      resources :assignments, only: [:index, :show], controller: 'assignments'
      resources :abilities, only: [:index, :show], controller: 'abilities'
      resources :aspirations, only: [:index, :show], controller: 'aspirations'
      resources :departments, only: [:show], controller: 'departments'
    end
    
    # Kudos (public observation links)
    get 'kudos', to: 'organizations/kudos#index', as: :kudos
    get 'kudos/:date/:id', to: 'organizations/kudos#show', as: :kudo
  end

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

  # Missing resources index pages (public, no authentication)
  get '/missing_resources', to: 'missing_resources#index', as: :missing_resources
  get '/missing_resource_requests', to: 'missing_resources#requests_index', as: :missing_resource_requests

  # Catch-all route for unmatched paths (must be last)
  # This handles all 404s and sends them to the missing resources controller
  get '*path', to: 'missing_resources#show', as: :missing_resource, constraints: lambda { |req| !req.path.start_with?('/rails/active_storage') }

  # Defines the root path route ("/")
  # root "posts#index"
end
