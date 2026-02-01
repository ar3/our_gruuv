require 'csv'

class Organizations::BulkDownloadsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_login
  before_action :set_bulk_download, only: [:download_file]

  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page'
    end
  end

  def index
    authorize company, :view_bulk_sync_events?
  end

  def show
    @download_type = params[:id]
    authorize company, :view_bulk_download_history?
    
    @bulk_downloads = BulkDownload
      .for_organization(company)
      .by_type(@download_type)
      .recent
      .includes(:downloaded_by, downloaded_by: :person)
  end

  def download
    type = params[:type]
    
    csv_content = nil
    filename = nil
    
    case type
    when 'company_teammates'
      authorize company, :download_company_teammates_csv?
      csv_content = download_company_teammates_csv
      filename = "company_teammates_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    when 'assignments'
      authorize company, :download_bulk_csv?
      csv_content = download_assignments_csv
      filename = "assignments_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    when 'abilities'
      authorize company, :download_bulk_csv?
      csv_content = download_abilities_csv
      filename = "abilities_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    when 'positions'
      authorize company, :download_bulk_csv?
      csv_content = download_positions_csv
      filename = "positions_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    when 'seats'
      authorize company, :download_bulk_csv?
      csv_content = download_seats_csv
      filename = "seats_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    when 'titles'
      authorize company, :download_bulk_csv?
      csv_content = download_titles_csv
      filename = "titles_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    when 'departments_and_teams'
      authorize company, :download_bulk_csv?
      csv_content = download_departments_and_teams_csv
      filename = "departments_and_teams_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    else
      head :not_found
      return
    end
    
    # Upload to S3 and log the download
    begin
      uploader = S3::CsvUploader.new
      s3_result = uploader.upload(
        csv_content,
        filename: filename,
        organization_id: company.id,
        download_type: type
      )
      
      BulkDownload.create!(
        company: company,
        downloaded_by: current_company_teammate,
        download_type: type,
        s3_key: s3_result[:s3_key],
        s3_url: s3_result[:s3_url],
        filename: filename,
        file_size: csv_content.bytesize
      )
    rescue => e
      # Log error but don't fail the download
      Rails.logger.error "Failed to upload bulk download to S3: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
    end
    
    # Send CSV to user
    send_data csv_content,
              filename: filename,
              type: 'text/csv',
              disposition: 'attachment'
  end

  def download_file
    unless policy(@bulk_download).download?
      head :forbidden
      return
    end
    
    begin
      uploader = S3::CsvUploader.new
      file_content = uploader.download(@bulk_download.s3_key)
      
      send_data file_content,
                filename: @bulk_download.filename,
                type: 'text/csv',
                disposition: 'attachment'
    rescue => e
      Rails.logger.error "Failed to download file from S3: #{e.message}"
      flash[:alert] = 'Failed to download file. Please try again.'
      redirect_to organization_bulk_download_path(company, @bulk_download.download_type)
    end
  end

  private

  def set_bulk_download
    @bulk_download = BulkDownload.find(params[:id])
  end

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
          position: :title,
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
        external_title = latest_tenure&.position&.title&.external_title || ''
        
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
      
      Assignment.includes(:company, :department, :published_external_reference, position_assignments: { position: [:title, :position_level] }, assignment_abilities: :ability, assignment_outcomes: [])
                .where(company: company.self_and_descendants)
                .order(:title)
                .find_each do |assignment|
        # Department or company name
        department_or_company = assignment.department&.display_name || assignment.company&.display_name || ''
        
        # Positions: "External Title - Level (assignment_type, min%-max%)" separated by newlines
        positions = assignment.position_assignments.map do |position_assignment|
          position = position_assignment.position
          parts = [
            "#{position.title.external_title} - #{position.position_level.level}",
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
          ability.department&.display_name || ability.company&.display_name || '',
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
        'External Title', 'Level', 'Company', 'Department', 'Semantic Version', 'Created At', 'Updated At',
        'Public Position URL', 'Number of Active Employment Tenures', 'Assignments', 'Version Count',
        'Title', 'Position Summary', 'Seats', 'Other Uploads'
      ]
      
      Position.includes(
        title: [:organization, :seats, :department],
        position_level: [],
        position_assignments: :assignment
      )
              .joins(title: :organization)
              .where(organizations: { id: company.self_and_descendants.map(&:id) })
              .order('titles.external_title, position_levels.level')
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
        
        # Title (external_title)
        title_value = position.title&.external_title || ''
        
        # Position summary
        position_summary = position.position_summary || ''
        
        # Seats: newline-separated list of seat display names for this position's title
        seats_list = position.title&.seats&.map(&:display_name)&.join("\n") || ''
        
        # Department
        department_name = position.title&.department&.display_name || ''
        
        # Other Uploads: external_title - level
        other_uploads = if position.title&.external_title.present? && position.position_level&.level.present?
          "#{position.title.external_title} - #{position.position_level.level}"
        else
          ''
        end
        
        csv << [
          position.title&.external_title || '',
          position.position_level&.level || '',
          position.company&.display_name || '',
          department_name,
          position.semantic_version || '',
          position.created_at&.to_s || '',
          position.updated_at&.to_s || '',
          public_url,
          active_tenures_count,
          assignments_list,
          version_count,
          title_value,
          position_summary,
          seats_list,
          other_uploads
        ]
      end
    end
  end

  def download_seats_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'Seat ID', 'Display Name', 'Title', 'Organization', 'Department', 'Team',
        'State', 'Seat Needed By', 'Reports To Seat', 'Number of Direct Reports',
        'Active Employment Tenures', 'Job Classification', 'Created At', 'Updated At'
      ]
      
      org_ids = company.self_and_descendants.map(&:id)
      Seat.joins(:title)
          .where(titles: { organization_id: org_ids })
          .includes(:title, :department, :team, :reports_to_seat, :reporting_seats, employment_tenures: { teammate: :person })
          .order('titles.external_title, seats.seat_needed_by')
          .find_each do |seat|
        # Reports to seat display name
        reports_to_display = seat.reports_to_seat&.display_name || ''
        
        # Number of direct reports
        direct_reports_count = seat.reporting_seats.count
        
        # Active employment tenures count
        active_tenures_count = seat.employment_tenures.active.count
        
        csv << [
          seat.id,
          seat.display_name,
          seat.title.external_title,
          seat.title.company.display_name,
          seat.title&.department&.display_name || '',
          seat.team&.display_name || '',
          seat.state,
          seat.seat_needed_by&.strftime('%Y-%m-%d') || '',
          reports_to_display,
          direct_reports_count,
          active_tenures_count,
          seat.job_classification || '',
          seat.created_at&.to_s || '',
          seat.updated_at&.to_s || ''
        ]
      end
    end
  end

  def download_titles_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'Title ID', 'External Title', 'Organization', 'Position Major Level',
        'Number of Positions', 'Number of Seats', 'Number of Active Employment Tenures',
        'Created At', 'Updated At'
      ]
      
      org_ids = company.self_and_descendants.map(&:id)
      Title.where(organization_id: org_ids)
           .includes(:organization, :position_major_level, :positions, :seats)
           .order(:external_title)
           .find_each do |title|
        # Count positions
        positions_count = title.positions.count
        
        # Count seats
        seats_count = title.seats.count
        
        # Count active employment tenures through positions
        active_tenures_count = EmploymentTenure.active
          .joins(:position)
          .where(positions: { title_id: title.id })
          .count
        
        csv << [
          title.id,
          title.external_title,
          title.company.display_name,
          title.position_major_level.major_level,
          positions_count,
          seats_count,
          active_tenures_count,
          title.created_at&.to_s || '',
          title.updated_at&.to_s || ''
        ]
      end
    end
  end

  def download_departments_and_teams_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'Organization ID', 'Name', 'Type', 'Parent Organization',
        'Number of Seats', 'Number of Titles', 'Number of Teammates',
        'Number of Child Departments', 'Number of Child Teams',
        'Created At', 'Updated At'
      ]
      
      org_ids = company.self_and_descendants.map(&:id)
      Organization.where(type: ['Department', 'Team'])
                  .where(id: org_ids)
                  .includes(:parent, :seats, :titles, :teammates, :children)
                  .order(:type, :name)
                  .find_each do |org|
        # Count seats (both through titles and direct associations)
        seats_count = org.seats.count + org.seats_as_department.count + org.seats_as_team.count
        
        # Count titles
        titles_count = org.titles.count
        
        # Count teammates
        teammates_count = org.teammates.count
        
        # Count departments and teams
        departments_count = org.departments.count
        teams_count = org.teams.count
        
        csv << [
          org.id,
          org.name,
          org.type,
          '',  # No parent hierarchy anymore
          seats_count,
          titles_count,
          teammates_count,
          departments_count,
          teams_count,
          org.created_at&.to_s || '',
          org.updated_at&.to_s || ''
        ]
      end
    end
  end
end

