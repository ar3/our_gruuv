class EnsureAssignmentTenuresSyncParser
  attr_reader :organization, :errors, :parsed_data

  def initialize(organization)
    @organization = organization
    @errors = []
    @parsed_data = {}
  end

  def parse
    @errors = []
    @parsed_data = {}

    begin
      # Find all active teammates in the organization (those with active employment tenures)
      org_ids = organization.company? ? organization.self_and_descendants.map(&:id) : [organization.id]
      
      active_employment_tenures = EmploymentTenure.active
        .joins(:teammate)
        .where(company_id: org_ids, teammates: { organization_id: org_ids })
        .includes(:teammate, :position)

      assignment_tenures_to_create = []

      active_employment_tenures.each do |employment_tenure|
        teammate = employment_tenure.teammate
        position = employment_tenure.position

        next unless position

        # Get all required assignments for this position
        required_assignments = position.required_assignments.includes(:assignment)

        required_assignments.each do |position_assignment|
          assignment = position_assignment.assignment

          # Check if an active assignment tenure already exists
          existing_tenure = AssignmentTenure.active
            .find_by(teammate: teammate, assignment: assignment)

          # Calculate the estimated percentage (use existing if available, otherwise calculate)
          energy_percentage = existing_tenure&.anticipated_energy_percentage || calculate_energy_percentage(position_assignment)

          assignment_tenures_to_create << {
            'teammate_id' => teammate.id,
            'teammate_name' => teammate.person.display_name,
            'assignment_id' => assignment.id,
            'assignment_title' => assignment.title,
            'position_id' => position.id,
            'position_display_name' => position.display_name,
            'anticipated_energy_percentage' => energy_percentage,
            'min_estimated_energy' => position_assignment.min_estimated_energy,
            'max_estimated_energy' => position_assignment.max_estimated_energy,
            'existing_tenure_id' => existing_tenure&.id,
            'will_create' => existing_tenure.nil?,
            'will_skip' => existing_tenure.present?
          }
        end
      end

      # Build parsed data
      @parsed_data = {
        assignment_tenures: assignment_tenures_to_create.map.with_index(1) do |tenure_data, index|
          tenure_data.merge('row' => index)
        end
      }

      true
    rescue => e
      @errors << "Error parsing data: #{e.message}"
      Rails.logger.error "EnsureAssignmentTenuresSyncParser error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  def enhanced_preview_actions
    {
      'assignment_tenures' => parsed_data[:assignment_tenures] || []
    }
  end

  private

  def calculate_energy_percentage(position_assignment)
    min = position_assignment.min_estimated_energy
    max = position_assignment.max_estimated_energy

    # If both are nil or zero, return default minimum of 5
    return 5 if (min.nil? || min.zero?) && (max.nil? || max.zero?)

    # Calculate average based on what's available
    if min.present? && max.present?
      average = (min + max) / 2.0
    elsif min.present?
      average = min.to_f
    elsif max.present?
      average = max.to_f
    else
      return 5
    end

    # Round to nearest 5
    rounded = round_to_nearest_5(average)

    # Ensure minimum of 5
    [rounded, 5].max
  end

  def round_to_nearest_5(value)
    ((value / 5.0).round * 5).to_i
  end
end
