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
      csv << ['First Name', 'Middle Name', 'Last Name', 'Suffix', 'Preferred Name', 'External Title']
      
      CompanyTeammate.includes(person: [], employment_tenures: { position: :position_type })
                     .for_organization_hierarchy(company)
                     .find_each do |teammate|
        person = teammate.person
        latest_tenure = teammate.employment_tenures.order(started_at: :desc).first
        external_title = latest_tenure&.position&.position_type&.external_title || ''
        
        csv << [
          person.first_name || '',
          person.middle_name || '',
          person.last_name || '',
          person.suffix || '',
          person.preferred_name || '',
          external_title
        ]
      end
    end
  end

  def download_assignments_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Title', 'Tagline', 'Department', 'Positions', 'Milestones', 'Outcomes', 'Required Activities', 'Handbook', 'Version', 'Changes Count', 'Public URL', 'Created At', 'Updated At']
      
      Assignment.includes(:company, :department, :published_external_reference, positions: [:position_type, :position_level], assignment_abilities: :ability, assignment_outcomes: [])
                .where(company: company.self_and_descendants)
                .order(:title)
                .find_each do |assignment|
        # Department or company name
        department_or_company = assignment.department&.display_name || assignment.company&.display_name || ''
        
        # Positions: "External Title - Level" separated by newlines
        positions = assignment.positions.map do |position|
          "#{position.position_type.external_title} - #{position.position_level.level}"
        end.join("\n")
        
        # Milestones: "Ability Name - Milestone X" separated by newlines
        milestones = assignment.assignment_abilities.by_milestone_level.map do |aa|
          "#{aa.ability.name} - Milestone #{aa.milestone_level}"
        end.join("\n")
        
        # Outcomes: descriptions separated by newlines
        outcomes = assignment.assignment_outcomes.ordered.map(&:description).join("\n")
        
        csv << [
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
          assignment.published_url || '',
          assignment.created_at&.to_s || '',
          assignment.updated_at&.to_s || ''
        ]
      end
    end
  end

  def download_abilities_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Name', 'Description', 'Organization', 'Semantic Version', 'Created At', 'Updated At']
      
      Ability.includes(:organization)
             .where(organization: company.self_and_descendants)
             .order(:name)
             .find_each do |ability|
        csv << [
          ability.name || '',
          ability.description || '',
          ability.organization&.display_name || '',
          ability.semantic_version || '',
          ability.created_at&.to_s || '',
          ability.updated_at&.to_s || ''
        ]
      end
    end
  end

  def download_positions_csv
    CSV.generate(headers: true) do |csv|
      csv << ['External Title', 'Level', 'Company', 'Semantic Version', 'Created At', 'Updated At']
      
      Position.includes(position_type: :organization, position_level: [])
              .joins(position_type: :organization)
              .where(organizations: { id: company.self_and_descendants.map(&:id) })
              .order('position_types.external_title, position_levels.level')
              .find_each do |position|
        csv << [
          position.position_type&.external_title || '',
          position.position_level&.level || '',
          position.company&.display_name || '',
          position.semantic_version || '',
          position.created_at&.to_s || '',
          position.updated_at&.to_s || ''
        ]
      end
    end
  end
end

