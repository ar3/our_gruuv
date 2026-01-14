require 'csv'

class Organizations::BulkDownloadsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_login

  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page'
    end
  end

  def index
    authorize company, :view_bulk_sync_events?
  end

  def download
    type = params[:type]
    
    case type
    when 'company_teammates'
      authorize company, :download_company_teammates_csv?
      send_data download_company_teammates_csv, 
                filename: "company_teammates_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                type: 'text/csv',
                disposition: 'attachment'
    when 'assignments'
      authorize company, :download_bulk_csv?
      send_data download_assignments_csv,
                filename: "assignments_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                type: 'text/csv',
                disposition: 'attachment'
    when 'abilities'
      authorize company, :download_bulk_csv?
      send_data download_abilities_csv,
                filename: "abilities_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                type: 'text/csv',
                disposition: 'attachment'
    when 'positions'
      authorize company, :download_bulk_csv?
      send_data download_positions_csv,
                filename: "positions_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                type: 'text/csv',
                disposition: 'attachment'
    else
      head :not_found
    end
  end

  private

  def download_company_teammates_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'First Name', 'Middle Name', 'Last Name', 'Suffix', 'Preferred Name', 'External Title',
        'Email', 'Slack User Name',
        'Last PageVisit Created At', 'First PageVisit Created At', 'PageVisit Count',
        'Last Position Finalized Check-In', 'Last Assignment Finalized Check-In', 'Last Aspiration Finalized Check-In',
        'Number of Milestones Attained', 'Manager Email',
        'Number of Published Observations (as Observee)', '1:1 Document Link', 'Public Page Link',
        'Active Assignments'
      ]
      
      CompanyTeammate.includes(
        person: [:page_visits],
        employment_tenures: { 
          position: :position_type,
          manager_teammate: :person
        },
        assignment_tenures: :assignment,
        teammate_identities: [],
        teammate_milestones: [],
        one_on_one_link: []
      )
                     .for_organization_hierarchy(company)
                     .find_each do |teammate|
        person = teammate.person
        latest_tenure = teammate.employment_tenures.order(started_at: :desc).first
        external_title = latest_tenure&.position&.position_type&.external_title || ''
        
        # PageVisit data
        page_visits = person.page_visits
        last_page_visit_created_at = page_visits.order(created_at: :desc).first&.created_at&.to_s || ''
        first_page_visit_created_at = page_visits.order(created_at: :asc).first&.created_at&.to_s || ''
        page_visit_count = page_visits.count
        
        # Email
        email = person.email || ''
        
        # Slack user name
        slack_identity = teammate.teammate_identities.find { |ti| ti.provider == 'slack' }
        slack_user_name = slack_identity&.name || ''
        
        # Last finalized check-ins
        last_position_check_in = PositionCheckIn
          .where(teammate: teammate)
          .where.not(official_check_in_completed_at: nil)
          .order(official_check_in_completed_at: :desc)
          .first
        last_position_finalized = last_position_check_in&.official_check_in_completed_at&.to_s || ''
        
        last_assignment_check_in = AssignmentCheckIn
          .where(teammate: teammate)
          .where.not(official_check_in_completed_at: nil)
          .order(official_check_in_completed_at: :desc)
          .first
        last_assignment_finalized = last_assignment_check_in&.official_check_in_completed_at&.to_s || ''
        
        last_aspiration_check_in = AspirationCheckIn
          .where(teammate: teammate)
          .where.not(official_check_in_completed_at: nil)
          .order(official_check_in_completed_at: :desc)
          .first
        last_aspiration_finalized = last_aspiration_check_in&.official_check_in_completed_at&.to_s || ''
        
        # Number of milestones attained
        milestones_count = teammate.teammate_milestones.count
        
        # Manager email
        manager_teammate = latest_tenure&.manager_teammate
        manager_email = manager_teammate&.person&.email || ''
        
        # Number of published observations where they are the observee
        published_observations_count = Observation
          .joins(:observees)
          .where(observees: { teammate: teammate })
          .where.not(published_at: nil)
          .count
        
        # 1:1 document link
        one_on_one_link = teammate.one_on_one_link
        one_on_one_url = one_on_one_link&.url || ''
        
        # Public page link
        public_page_url = Rails.application.routes.url_helpers.public_person_url(person)
        
        # Active assignments: serialize as "Title | ID: 123 | Started: 2024-01-01 | Energy: 50% | Rating: Exceeds"
        # Each assignment on a new line, separated by "\n"
        company_ids = company.self_and_descendants.map(&:id)
        active_assignments = teammate.assignment_tenures
          .joins(:assignment)
          .where(assignments: { company_id: company_ids })
          .where(ended_at: nil)
          .where('anticipated_energy_percentage > 0')
          .order(started_at: :asc)
          .map do |tenure|
            assignment = tenure.assignment
            parts = [
              assignment.title || '',
              "ID: #{assignment.id}",
              "Started: #{tenure.started_at&.strftime('%Y-%m-%d') || ''}"
            ]
            
            if tenure.anticipated_energy_percentage.present?
              parts << "Energy: #{tenure.anticipated_energy_percentage}%"
            end
            
            if tenure.official_rating.present?
              parts << "Rating: #{tenure.official_rating}"
            end
            
            parts.join(' | ')
          end.join("\n")
        
        csv << [
          person.first_name || '',
          person.middle_name || '',
          person.last_name || '',
          person.suffix || '',
          person.preferred_name || '',
          external_title,
          email,
          slack_user_name,
          last_page_visit_created_at,
          first_page_visit_created_at,
          page_visit_count,
          last_position_finalized,
          last_assignment_finalized,
          last_aspiration_finalized,
          milestones_count,
          manager_email,
          published_observations_count,
          one_on_one_url,
          public_page_url,
          active_assignments
        ]
      end
    end
  end

  def download_assignments_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Assignment ID', 'Title', 'Tagline', 'Department', 'Positions', 'Milestones', 'Outcomes', 'Required Activities', 'Handbook', 'Version', 'Changes Count', 'Public URL', 'Created At', 'Updated At']
      
      Assignment.includes(:company, :department, :published_external_reference, position_assignments: { position: [:position_type, :position_level] }, assignment_abilities: :ability, assignment_outcomes: [])
                .where(company: company.self_and_descendants)
                .order(:title)
                .find_each do |assignment|
        # Department or company name
        department_or_company = assignment.department&.display_name || assignment.company&.display_name || ''
        
        # Positions: "External Title - Level (assignment_type, min%-max%)" separated by newlines
        positions = assignment.position_assignments.map do |position_assignment|
          position = position_assignment.position
          parts = [
            "#{position.position_type.external_title} - #{position.position_level.level}",
            " (#{position_assignment.assignment_type}"
          ]
          
          # Add energy range if present
          if position_assignment.min_estimated_energy.present? && position_assignment.max_estimated_energy.present?
            parts << ", #{position_assignment.min_estimated_energy}%-#{position_assignment.max_estimated_energy}%"
          elsif position_assignment.min_estimated_energy.present?
            parts << ", #{position_assignment.min_estimated_energy}%+"
          elsif position_assignment.max_estimated_energy.present?
            parts << ", up to #{position_assignment.max_estimated_energy}%"
          end
          
          parts << ")"
          parts.join
        end.join("\n")
        
        # Milestones: "Ability Name - Milestone X" separated by newlines
        milestones = assignment.assignment_abilities.by_milestone_level.map do |aa|
          "#{aa.ability.name} - Milestone #{aa.milestone_level}"
        end.join("\n")
        
        # Outcomes: descriptions separated by newlines
        outcomes = assignment.assignment_outcomes.ordered.map(&:description).join("\n")
        
        # Public assignment URL (full URL)
        public_url = begin
          Rails.application.routes.url_helpers.organization_public_maap_assignment_url(
            assignment.company,
            assignment
          )
        rescue => e
          # Fallback to path if URL generation fails
          Rails.logger.warn "Failed to generate full URL for assignment #{assignment.id}: #{e.message}"
          Rails.application.routes.url_helpers.organization_public_maap_assignment_path(
            assignment.company,
            assignment
          )
        end
        
        csv << [
          assignment.id,
          assignment.title || '',
          assignment.tagline || '',
          department_or_company,
          positions,
          milestones,
          outcomes,
          assignment.required_activities || '',
          assignment.handbook || '',
          assignment.semantic_version || '',
          assignment.changes_count,
          public_url,
          assignment.created_at&.to_s || '',
          assignment.updated_at&.to_s || ''
        ]
      end
    end
  end

  def download_abilities_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'Name', 'Description', 'Organization', 'Semantic Version', 'Assignments',
        'Milestone 1 Description', 'Milestone 2 Description', 'Milestone 3 Description',
        'Milestone 4 Description', 'Milestone 5 Description',
        'Created At', 'Updated At'
      ]
      
      Ability.includes(:organization, assignment_abilities: :assignment)
             .where(organization: company.self_and_descendants)
             .order(:name)
             .find_each do |ability|
        # Format assignments: "<assignment name> - Milestone <milestone level>" separated by newlines
        assignments = ability.assignment_abilities.map do |assignment_ability|
          "#{assignment_ability.assignment.title} - Milestone #{assignment_ability.milestone_level}"
        end.join("\n")
        
        csv << [
          ability.name || '',
          ability.description || '',
          ability.organization&.display_name || '',
          ability.semantic_version || '',
          assignments,
          ability.milestone_1_description || '',
          ability.milestone_2_description || '',
          ability.milestone_3_description || '',
          ability.milestone_4_description || '',
          ability.milestone_5_description || '',
          ability.created_at&.to_s || '',
          ability.updated_at&.to_s || ''
        ]
      end
    end
  end

  def download_positions_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'External Title', 'Level', 'Company', 'Semantic Version', 'Created At', 'Updated At',
        'Public Position URL', 'Number of Active Employment Tenures', 'Assignments', 'Version Count',
        'Position Type Summary', 'Position Summary', 'Seats'
      ]
      
      Position.includes(
        position_type: [:organization, :seats],
        position_level: [],
        position_assignments: :assignment
      )
              .joins(position_type: :organization)
              .where(organizations: { id: company.self_and_descendants.map(&:id) })
              .order('position_types.external_title, position_levels.level')
              .find_each do |position|
        # Public position URL (full URL)
        public_url = begin
          Rails.application.routes.url_helpers.organization_public_maap_position_url(
            position.company,
            position
          )
        rescue => e
          # Fallback to path if URL generation fails
          Rails.logger.warn "Failed to generate full URL for position #{position.id}: #{e.message}"
          Rails.application.routes.url_helpers.organization_public_maap_position_path(
            position.company,
            position
          )
        end
        
        # Number of active employment tenures
        active_tenures_count = EmploymentTenure.active.where(position: position).count
        
        # Assignments: "<assignment name> (<required|suggested>, <min>%-<max>%)" separated by newlines
        assignments_list = position.position_assignments.map do |pa|
          parts = [
            pa.assignment.title,
            " (#{pa.assignment_type}"
          ]
          
          # Add energy range if present
          if pa.min_estimated_energy.present? && pa.max_estimated_energy.present?
            parts << ", #{pa.min_estimated_energy}%-#{pa.max_estimated_energy}%"
          elsif pa.min_estimated_energy.present?
            parts << ", #{pa.min_estimated_energy}%+"
          elsif pa.max_estimated_energy.present?
            parts << ", up to #{pa.max_estimated_energy}%"
          end
          
          parts << ")"
          parts.join
        end.join("\n")
        
        # PaperTrail versions count
        version_count = position.versions.count
        
        # Position type summary
        position_type_summary = position.position_type&.position_summary || ''
        
        # Position summary
        position_summary = position.position_summary || ''
        
        # Seats: newline-separated list of seat display names for this position's position_type
        seats_list = position.position_type&.seats&.map(&:display_name)&.join("\n") || ''
        
        csv << [
          position.position_type&.external_title || '',
          position.position_level&.level || '',
          position.company&.display_name || '',
          position.semantic_version || '',
          position.created_at&.to_s || '',
          position.updated_at&.to_s || '',
          public_url,
          active_tenures_count,
          assignments_list,
          version_count,
          position_type_summary,
          position_summary,
          seats_list
        ]
      end
    end
  end
end

