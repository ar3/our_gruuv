# frozen_string_literal: true

module OrganizationSitemap
  module Registry

    module_function

    def section_definitions
      @section_definitions ||= [
        home_and_tools_section,
        about_me_section,
        observations_section,
        teammate_directory_section,
        celebrate_milestones_section,
        huddles_section,
        insights_section,
        kudos_center_section,
        admin_explore_maap_section,
        admin_section,
        beta_section
      ].freeze
    end

    def home_and_tools_section
      {
        label: "Home & Tools",
        icon: "bi-house",
        pages: [
          page(
            key: :start_here,
            label: "Start Here",
            icon: "bi-house-door",
            path: ->(ctx) { ctx.organization_start_here_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(ctx.organization).show? },
            goal: "Your personalized landing page with shortcuts to the parts of OurGruuv you use most.",
            synonyms: %w[start here home landing dashboard widgets]
          ),
          page(
            key: :get_shit_done,
            label: "Get Shit Done",
            icon: "bi-lightning-charge",
            path: ->(ctx) { ctx.organization_get_shit_done_path(ctx.organization) },
            policy: ->(ctx) { ctx.teammate.present? && ctx.policy(ctx.teammate).view_check_ins? },
            goal: "See what needs your attention across observations, check-ins, goals, and other pending work.",
            synonyms: %w[get shit done gsd pending todos action items]
          ),
          page(
            key: :something_interesting,
            label: "Something Interesting",
            icon: "bi-stars",
            path: ->(ctx) { ctx.something_interesting_organization_get_shit_done_path(ctx.organization) },
            policy: ->(ctx) { ctx.teammate.present? && ctx.policy(ctx.teammate).view_check_ins? },
            goal: "Catch up on notable changes and activity since you last visited.",
            synonyms: %w[something interesting updates activity feed whats new]
          ),
          page(
            key: :search,
            label: "Search",
            icon: "bi-search",
            path: ->(ctx) { ctx.organization_search_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(ctx.company).view_search? },
            goal: "Find people, records, and pages across your organization.",
            synonyms: %w[search find lookup]
          ),
          page(
            key: :sitemap,
            label: "Sitemap",
            icon: "bi-map",
            path: ->(ctx) { ctx.organization_sitemap_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(ctx.organization).show? },
            goal: "Browse every page you can access in this organization, with descriptions and search keywords.",
            synonyms: %w[sitemap site map pages navigation directory all pages]
          )
        ]
      }
    end

    def about_me_section
      {
        label: "About Me",
        icon: "bi-person",
        pages: [
          page(
            key: :about_me,
            label: ->(ctx) { "About #{ctx.casual_name}" },
            icon: "bi-person",
            path: ->(ctx) { ctx.about_me_organization_company_teammate_path(ctx.organization, ctx.teammate) },
            policy: ->(ctx) { ctx.teammate.present? && ctx.policy(ctx.teammate).view_check_ins? },
            goal: "See your current role, assignments, teams, recent OGOs, and public goals in one overview.",
            synonyms: %w[about me profile my profile teammate view internal view]
          ),
          page(
            key: :one_on_one_hub,
            label: "1:1 Hub",
            icon: "bi-link-45deg",
            path: ->(ctx) { ctx.organization_company_teammate_one_on_one_link_path(ctx.organization, ctx.teammate) },
            policy: ->(ctx) {
              ctx.teammate.present? &&
                ctx.policy(OneOnOneLink.new(teammate: ctx.teammate)).show?
            },
            goal: "Track priorities and work-to-meet items for your one-on-one meetings.",
            synonyms: %w[1:1 one on one one-on-one weekly 1:1 1:1 hub one on ones]
          ),
          page(
            key: :my_check_in,
            label: "My Check-In",
            icon: "bi-clipboard-check",
            path: ->(ctx) { ctx.organization_company_teammate_check_ins_path(ctx.organization, ctx.teammate) },
            policy: ->(ctx) { ctx.teammate.present? && ctx.policy(ctx.teammate).view_check_ins? },
            goal: "Choose how to move toward clarity—one item at a time, in bulk, together at finalization, or by reviewing history.",
            synonyms: %w[check-in check in clarity check-in my check-in bulk check-in finalization]
          ),
          page(
            key: :ogos_involving_me,
            label: "OGO's involving me",
            icon: "bi-person",
            path: ->(ctx) {
              ctx.organization_observations_path(ctx.organization, involving_teammate_id: ctx.teammate&.id)
            },
            policy: ->(ctx) { ctx.teammate.present? && ctx.policy(ctx.company).view_observations? },
            goal: "Review observations and OGOs where you are the observer or observee.",
            synonyms: %w[ogos involving me my ogos my observations observations about me]
          ),
          page(
            key: :my_feedback_requests,
            label: "My Feedback Requests",
            icon: "bi-chat-dots",
            path: ->(ctx) { ctx.organization_feedback_requests_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(ctx.company).view_feedback_requests? },
            goal: "See feedback requests assigned to you and respond to them.",
            synonyms: %w[feedback requests my feedback]
          ),
          page(
            key: :my_prompts,
            label: ->(ctx) { "My #{ctx.company_label_plural('prompt', 'Prompts')}" },
            icon: "bi-journal-text",
            path: ->(ctx) { ctx.organization_prompts_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(ctx.company).view_prompts? },
            goal: "Manage your growth prompts and growth plan.",
            synonyms: %w[prompts my prompts growth plan my growth plan]
          ),
          page(
            key: :my_goals,
            label: "My Goals",
            icon: "bi-bullseye",
            path: ->(ctx) {
              ctx.organization_goals_path(ctx.organization, owner_id: "CompanyTeammate_#{ctx.teammate.id}")
            },
            policy: ->(ctx) { ctx.policy(ctx.company).view_goals? },
            goal: "Track goals you own, including confidence check-ins and progress.",
            synonyms: %w[my goals goals I own personal goals]
          ),
          page(
            key: :all_goals,
            label: "All Goals",
            icon: "bi-bullseye",
            path: ->(ctx) { ctx.organization_goals_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(ctx.company).view_goals? },
            goal: "Browse and manage goals across the organization.",
            synonyms: %w[goals all goals company goals org goals]
          ),
          page(
            key: :notifications,
            label: "Notifications",
            icon: "bi-bell",
            path: ->(ctx) { ctx.organization_company_teammate_notifications_path(ctx.organization, ctx.teammate) },
            policy: ->(ctx) { ctx.teammate.present? },
            goal: "Manage daily and weekly digest notification preferences.",
            synonyms: %w[notifications digest daily digest weekly digest email preferences]
          ),
          page(
            key: :my_growth,
            label: "My Growth",
            icon: "bi-flask",
            path: ->(ctx) { ctx.my_growth_experiences_organization_company_teammate_path(ctx.organization, ctx.teammate) },
            policy: ->(ctx) { ctx.teammate.present? && ctx.policy(ctx.teammate).view_check_ins? },
            goal: "Explore growth experiences, abilities, goals, and position change options.",
            synonyms: %w[my growth growth experiences career growth development]
          ),
          page(
            key: :my_huddles_about_me,
            label: "My Huddles",
            icon: "bi-person",
            path: ->(ctx) { ctx.my_huddles_path },
            policy: ->(ctx) { ctx.policy(Huddle).show? },
            goal: "See huddles you participate in and join upcoming sessions.",
            synonyms: %w[my huddles huddles I'm in participant huddles]
          )
        ]
      }
    end

    def observations_section
      {
        label: "Observations (OGO)",
        icon: "bi-eye",
        pages: [
          page(
            key: :add_new_ogo,
            label: "Add New OGO",
            icon: "bi-plus-circle",
            path: ->(ctx) { ctx.select_type_organization_observations_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(ctx.company).view_observations? },
            goal: "Create a new observation or OGO for a teammate.",
            synonyms: %w[add ogo new ogo new observation create observation give kudos]
          ),
          page(
            key: :organization_kudos,
            label: ->(ctx) { "#{ctx.org_display_name} Kudos" },
            icon: "bi-gift",
            path: ->(ctx) {
              ctx.organization_observations_path(
                ctx.organization,
                privacy: %w[public_to_company public_to_world],
                spotlight: "most_observed",
                view: "wall"
              )
            },
            policy: ->(ctx) { ctx.policy(ctx.company).view_observations? },
            goal: "Browse public kudos and celebrations shared across the company.",
            synonyms: %w[kudos wall company kudos public observations celebration]
          ),
          page(
            key: :all_observations,
            label: "All observations",
            icon: "bi-list-ul",
            path: ->(ctx) { ctx.organization_observations_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(ctx.company).view_observations? },
            goal: "Browse every observation you can access in the organization.",
            synonyms: %w[all observations ogos every observation observation list]
          )
        ]
      }
    end

    def teammate_directory_section
      {
        label: "Teammate Directory",
        icon: "bi-people",
        pages: [
          page(
            key: :view_teammates,
            label: "View Teammates",
            icon: "bi-people",
            path: ->(ctx) { ctx.organization_employees_path(ctx.organization, spotlight: "teammate_tenures") },
            policy: ->(ctx) { ctx.policy(Organization).show? },
            goal: "Find teammates, open profiles, and explore employment information.",
            synonyms: %w[teammates directory employees roster people list]
          ),
          page(
            key: :my_employees,
            label: "My Employees",
            icon: "bi-person-badge",
            path: ->(ctx) {
              ctx.organization_employees_path(
                ctx.organization,
                manager_teammate_id: ctx.teammate&.id,
                view: "managers_view",
                spotlight: "manager_lite"
              )
            },
            policy: ->(ctx) {
              ctx.teammate&.has_direct_reports? && ctx.policy(Organization).show?
            },
            goal: "See direct and indirect reports you manage and jump to their profiles.",
            synonyms: %w[my employees direct reports reports manager view my team]
          ),
          page(
            key: :employee_hierarchy,
            label: "Employee Hierarchy",
            icon: "bi-diagram-3",
            path: ->(ctx) {
              ctx.organization_employees_path(
                ctx.organization,
                spotlight: "manager_distribution",
                status: %w[unassigned_employee assigned_employee],
                view: "vertical_hierarchy"
              )
            },
            policy: ->(ctx) { ctx.policy(Organization).show? },
            goal: "Visualize reporting relationships and manager distribution across the company.",
            synonyms: %w[hierarchy org chart reporting structure manager tree]
          )
        ]
      }
    end

    def celebrate_milestones_section
      {
        label: "Celebrate Milestones",
        icon: "bi-trophy",
        pages: [
          page(
            key: :celebrate_milestones,
            label: "Celebrate Milestones",
            icon: "bi-trophy",
            path: ->(ctx) { ctx.celebrate_milestones_organization_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(ctx.organization).show? },
            goal: "Celebrate team and individual milestones across the organization.",
            synonyms: %w[celebrate milestones milestone awards recognition achievements]
          ),
          page(
            key: :bulk_award_milestones,
            label: "Bulk award milestones",
            icon: "bi-trophy",
            path: ->(ctx) { ctx.new_bulk_milestone_award_organization_company_teammate_path(ctx.organization, ctx.teammate) },
            policy: ->(ctx) { ctx.teammate.present? && ctx.policy(TeammateMilestone).create? },
            goal: "Award milestones to multiple teammates in one flow.",
            synonyms: %w[bulk award milestones milestone awards batch milestones]
          )
        ]
      }
    end

    def huddles_section
      {
        label: "Huddles",
        icon: "bi-chat-dots",
        pages: [
          page(
            key: :huddle_review,
            label: "Huddle Review",
            icon: "bi-graph-up",
            path: ->(ctx) { ctx.huddles_review_organization_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(ctx.organization).show? },
            goal: "Review huddle participation and outcomes for the organization.",
            synonyms: %w[huddle review huddles review team huddles]
          ),
          page(
            key: :my_huddles,
            label: "My Huddles",
            icon: "bi-person",
            path: ->(ctx) { ctx.my_huddles_path },
            policy: ->(ctx) { ctx.policy(Huddle).show? },
            goal: "See huddles you participate in and join upcoming sessions.",
            synonyms: %w[my huddles participant huddles]
          ),
          page(
            key: :todays_huddles,
            label: "Today's Huddles",
            icon: "bi-calendar-event",
            path: ->(ctx) { ctx.huddles_path },
            policy: ->(ctx) { ctx.policy(Huddle).show? },
            goal: "See huddles scheduled for today and join them quickly.",
            synonyms: %w[today huddles todays huddles scheduled huddles]
          ),
          page(
            key: :my_teams,
            label: "My Teams",
            icon: "bi-people-fill",
            path: ->(ctx) { ctx.my_teams_organization_path(ctx.organization) },
            policy: ->(ctx) { ctx.policy(Team).show? },
            goal: "See teams you belong to and open team pages.",
            synonyms: %w[my teams teams I am on team membership]
          )
        ]
      }
    end

    def insights_section
      {
        label: "Insights",
        icon: "bi-bar-chart-line",
        pages: [
          insights_page(:og_scorecard, "OG Scorecard", "bi-table", :organization_insights_og_scorecard_path,
            goal: "See organization-wide observation scorecard metrics.",
            synonyms: %w[og scorecard scorecard observation scorecard]),
          insights_page(:who_is_doing_what, "Who is doing what", "bi-pie-chart", :organization_insights_who_is_doing_what_path,
            goal: "Understand how observation activity is distributed across the company.",
            synonyms: %w[who is doing what activity distribution]),
          insights_page(:check_ins_health, "Check-ins Health", "bi-heart-pulse", :organization_check_ins_health_path,
            policy: ->(ctx) { ctx.policy(ctx.organization).check_ins_health? },
            goal: "Monitor clarity check-in health across employees and teams.",
            synonyms: %w[check-ins health check in health clarity health]),
          insights_page(:goals_health, "Goals Health", "bi-heart-pulse", :organization_goals_health_path,
            policy: ->(ctx) { ctx.policy(ctx.organization).goals_health? },
            goal: "Monitor goal check-in health and stale goals across the organization.",
            synonyms: %w[goals health goal health stale goals]),
          insights_page(:observations_health, "Observations Health", "bi-heart-pulse", :organization_observations_health_path,
            policy: ->(ctx) { ctx.policy(ctx.organization).observations_health? },
            goal: "Monitor observation cadence and gaps across employees.",
            synonyms: %w[observations health ogo health observation cadence]),
          insights_page(:insights_observations, "Observations", "bi-eye", :organization_insights_observations_path,
            goal: "Explore observation trends and analytics.",
            synonyms: %w[insights observations observation analytics ogo insights]),
          insights_page(:insights_feedback_requests, "Feedback Requests", "bi-chat-square-text", :organization_insights_feedback_requests_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_feedback_requests? },
            goal: "Analyze feedback request volume and completion.",
            synonyms: %w[feedback request insights feedback analytics]),
          insights_page(:insights_og_consultations, "OG Consultations", "bi-robot", :organization_insights_og_consultations_path,
            policy: ->(ctx) { ctx.policy(ctx.company).show? },
            goal: "See which Consult OG kinds are run, who runs them, and volume over time.",
            synonyms: %w[og consultations consult og maap clarity ogo search insights]),
          insights_page(:seats_titles_positions, "Seats, Titles, Positions", "bi-briefcase", :organization_insights_seats_titles_positions_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_seats? },
            goal: "Review seat, title, and position coverage across the organization.",
            synonyms: %w[seats titles positions seat insights title insights]),
          insights_page(:insights_assignments, "Assignments", "bi-list-check", :organization_insights_assignments_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_assignments? },
            goal: "Analyze assignment coverage and utilization.",
            synonyms: %w[assignment insights assignments analytics]),
          insights_page(:insights_abilities, "Abilities", "bi-award", :organization_insights_abilities_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_abilities? },
            goal: "Analyze ability and milestone adoption across the organization.",
            synonyms: %w[ability insights abilities analytics milestone insights]),
          insights_page(:insights_goals, "Goals", "bi-bullseye", :organization_insights_goals_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_goals? },
            goal: "Explore goal trends and confidence patterns.",
            synonyms: %w[goal insights goals analytics]),
          insights_page(:insights_prompts, "Prompts", "bi-journal-text", :organization_insights_prompts_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_prompts? },
            goal: "Review prompt usage and growth-plan activity.",
            synonyms: %w[prompt insights prompts analytics growth plan insights]),
          insights_page(:insights_huddles, "Huddles", "bi-chat-dots", :huddles_review_organization_path,
            goal: "Review huddle participation insights.",
            synonyms: %w[huddle insights huddles analytics]),
          insights_page(:acknowledgement_nudges, "Acknowledgement nudges", "bi-bell", :organization_check_ins_acknowledgement_nudges_path,
            policy: ->(ctx) { ctx.policy(ctx.organization).check_ins_health? },
            goal: "See who still needs to acknowledge MAAP snapshots and send nudges.",
            synonyms: %w[acknowledgement nudges audit nudges maap acknowledgement]),
          insights_page(:check_ins_progress, "Check-ins Progress", "bi-bar-chart-steps", :organization_insights_check_ins_progress_path,
            policy: ->(ctx) { ctx.policy(ctx.organization).check_ins_health? },
            goal: "Track clarity check-in progress across the organization over time.",
            synonyms: %w[check-ins progress check in progress clarity progress])
        ]
      }
    end

    def kudos_center_section
      {
        label: ->(ctx) { "#{ctx.company_label_plural('kudos_point', 'Kudos Point')} Center" },
        icon: "bi-coin",
        pages: [
          kudos_page(:kudos_balance, "My Balance", "bi-wallet2", :kudos_points_organization_company_teammate_path,
            goal: "See your kudos point balance and recent activity.",
            synonyms: %w[kudos balance my balance points balance wallet]),
          kudos_page(:rewards_catalog, "Rewards Catalog", "bi-gift", :organization_kudos_rewards_rewards_path,
            goal: "Browse rewards you can redeem with kudos points.",
            synonyms: %w[rewards catalog redeem rewards kudos rewards shop]),
          kudos_page(:leaderboard, ->(ctx) { "#{ctx.company_label_plural('kudos_point', 'Kudos Point')} Leader Board" },
            "bi-trophy", :organization_kudos_rewards_leaderboard_path,
            goal: "See who has earned the most kudos points in the organization.",
            synonyms: %w[leaderboard leader board kudos leaderboard top earners]),
          kudos_page(:kudos_bank, ->(ctx) { "#{ctx.company_label_plural('kudos_point', 'Kudos Point')} Bank" },
            "bi-bank", :organization_kudos_rewards_bank_awards_path,
            goal: "Review bank awards and kudos grants managed by admins.",
            synonyms: %w[kudos bank bank awards point bank]),
          kudos_page(:kudos_economy, ->(ctx) { "#{ctx.company_label_plural('kudos_point', 'Kudos Point')} Economy" },
            "bi-sliders", :organization_kudos_rewards_economy_path,
            goal: "Configure how kudos points are earned and spent.",
            synonyms: %w[kudos economy points economy kudos settings])
        ]
      }
    end

    def admin_explore_maap_section
      {
        label: "Admin/Explore MAAP(s)",
        icon: "bi-gear",
        pages: [
          maap_page(:milestones_abilities, "Milestones & Abilities", "bi-award", :organization_abilities_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_abilities? },
            goal: "Browse and manage company abilities and milestones in the MAAP.",
            synonyms: %w[abilities ability milestones maap abilities milestones and abilities]),
          maap_page(:assignments, "Assignments", "bi-list-check", :organization_assignments_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_assignments? },
            goal: "Browse and manage seat assignments across the organization.",
            synonyms: %w[assignments assignment catalog maap assignments]),
          maap_page(:positions, "Positions", "bi-briefcase-fill", :organization_positions_path,
            policy: ->(ctx) { ctx.organization.present? && ctx.policy(ctx.organization).show? },
            goal: "Browse and manage positions that define roles in the MAAP.",
            synonyms: %w[positions position catalog maap positions roles]),
          maap_page(:seats, "Seats", "bi-briefcase", :organization_seats_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_seats? },
            goal: "Browse and manage seats that hold assignments and titles.",
            synonyms: %w[seats seat catalog maap seats]),
          maap_page(:titles, "Titles", "bi-briefcase-fill", :organization_titles_path,
            policy: ->(ctx) { ctx.policy(ctx.organization).view_titles? },
            goal: "Browse and manage external titles linked to seats and positions.",
            synonyms: %w[titles title catalog job titles external titles])
        ]
      }
    end

    def admin_section
      {
        label: "Admin",
        icon: "bi-gear",
        pages: [
          admin_page(:aspirations, "Aspirational Values", "bi-star", :organization_aspirations_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_aspirations? },
            goal: "Define aspirational values that shape clarity check-ins and growth.",
            synonyms: %w[aspirations aspirational values values culture]),
          admin_page(:departments, "Departments", "bi-diagram-3", :organization_departments_path,
            goal: "Manage departments used to organize teammates and MAAP records.",
            synonyms: %w[departments department structure org departments]),
          admin_page(:teams, "Teams", "bi-people", :organization_teams_path,
            goal: "Manage teams, membership, and team settings.",
            synonyms: %w[teams team management groups]),
          admin_page(:company_preferences, ->(ctx) { "#{ctx.company.name} Preferences" }, "bi-sliders",
            :edit_organization_company_preference_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_company_preferences? },
            goal: "Configure company-wide terminology, labels, and preferences.",
            synonyms: %w[company preferences settings configuration labels terminology]),
          admin_page(:prompt_templates, "Prompt Templates", "bi-file-text", :organization_prompt_templates_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_prompt_templates? },
            goal: "Manage reusable prompt templates for growth plans.",
            synonyms: %w[prompt templates template library growth templates]),
          admin_page(:bulk_events, "Bulk Events", "bi-upload", :organization_bulk_sync_events_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_bulk_sync_events? },
            goal: "Review bulk sync events and imports.",
            synonyms: %w[bulk events bulk sync imports sync events]),
          admin_page(:bulk_downloads, "Bulk Downloads", "bi-download", :organization_bulk_downloads_path,
            policy: ->(ctx) { ctx.policy(ctx.company).view_bulk_sync_events? },
            goal: "Download bulk exports of organization data.",
            synonyms: %w[bulk downloads exports data export download]),
          admin_page(:slack_settings, "Slack Settings", "bi-slack", :organization_slack_path,
            policy: ->(ctx) { ctx.policy(ctx.organization).view_slack_settings? },
            goal: "Connect and configure Slack integration for this organization.",
            synonyms: %w[slack settings slack integration slack config]),
          admin_page(:value_billing, "Value / Billing", "bi-cash-coin", :organization_value_billing_path,
            goal: "Review value metrics and billing information for the organization.",
            synonyms: %w[value billing billing subscription plan])
        ]
      }
    end

    def beta_section
      {
        label: "Beta",
        icon: "bi-lightning",
        pages: [
          beta_page(:beta_insights, "Insights", "bi-bar-chart-line", :organization_insights_path,
            policy: ->(ctx) { ctx.policy(ctx.company).show? },
            goal: "Open the insights hub with links to analytics dashboards.",
            synonyms: %w[insights dashboard analytics hub]),
          beta_page(:meeting_transcripts, "Meeting transcripts", "bi-file-earmark-text", :organization_possible_observation_transcripts_path,
            policy: ->(ctx) { ctx.policy(::PossibleObservationTranscript).index? },
            goal: "Review meeting transcripts that may become observations.",
            synonyms: %w[meeting transcripts transcripts possible observations]),
          beta_page(:eligibility_requirements, "Eligibility Requirements", "bi-check2-circle", :organization_eligibility_requirements_path,
            policy: ->(ctx) { ctx.policy(:eligibility_requirement).index? },
            goal: "Define eligibility requirements for positions and career paths.",
            synonyms: %w[eligibility requirements eligibility career requirements]),
          beta_page(:position_comparison, "Position Comparison", "bi-layout-split", :organization_position_comparison_path,
            policy: ->(ctx) { ctx.policy(:eligibility_requirement).index? },
            goal: "Compare positions side by side for hiring and growth planning.",
            synonyms: %w[position comparison compare positions side by side]),
          beta_page(:assignment_experience_survey, "Assignment Experience Survey", "bi-clipboard2-check", :organization_assignment_survey_path,
            policy: ->(ctx) { ctx.policy(ctx.organization).assignment_survey? },
            goal: "Rate whether your assignments are understandable, possible, and relevant.",
            synonyms: %w[assignment experience survey clarity possible relevant])
        ]
      }
    end

    def page(key:, label:, icon:, path:, policy:, goal:, synonyms: [])
      { key: key, label: label, icon: icon, path: path, policy: policy, goal: goal, synonyms: synonyms }
    end

    def insights_page(key, label, icon, route, goal:, synonyms: [], policy: nil)
      page(
        key: key,
        label: label,
        icon: icon,
        path: ->(ctx) { ctx.public_send(route, ctx.organization) },
        policy: policy || ->(ctx) { ctx.policy(ctx.company).view_observations? },
        goal: goal,
        synonyms: synonyms
      )
    end

    def kudos_page(key, label, icon, route, goal:, synonyms: [])
      page(
        key: key,
        label: label,
        icon: icon,
        path: ->(ctx) {
          args = route == :kudos_points_organization_company_teammate_path ? [ctx.organization, ctx.teammate] : [ctx.organization]
          ctx.public_send(route, *args)
        },
        policy: ->(ctx) { ctx.policy(:kudos).view_dashboard? },
        goal: goal,
        synonyms: synonyms
      )
    end

    def maap_page(key, label, icon, route, goal:, synonyms: [], policy: nil)
      page(
        key: key,
        label: label,
        icon: icon,
        path: ->(ctx) { ctx.public_send(route, ctx.organization) },
        policy: policy,
        goal: goal,
        synonyms: synonyms
      )
    end

    def admin_page(key, label, icon, route, goal:, synonyms: [], policy: nil)
      page(
        key: key,
        label: label,
        icon: icon,
        path: ->(ctx) { ctx.public_send(route, ctx.organization) },
        policy: policy || ->(ctx) { ctx.policy(ctx.organization).show? },
        goal: goal,
        synonyms: synonyms
      )
    end

    def beta_page(key, label, icon, route, goal:, synonyms: [], policy: nil, path_args: nil)
      page(
        key: key,
        label: label,
        icon: icon,
        path: ->(ctx) {
          args = path_args ? path_args.call(ctx) : [ctx.organization]
          ctx.public_send(route, *args)
        },
        policy: policy,
        goal: goal,
        synonyms: synonyms
      )
    end

  end
end
