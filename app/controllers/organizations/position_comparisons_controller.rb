class Organizations::PositionComparisonsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_positions
  before_action :set_selected_positions

  def show
    authorize :eligibility_requirement, :index?

    @assignment_rows = build_assignment_rows
    @left_combined_description = @left_position&.combined_summary
    @right_combined_description = @right_position&.combined_summary
    @left_eligibility_sentences = @left_position ? helpers.eligibility_requirements_sentences_from_config(@left_position) : []
    @right_eligibility_sentences = @right_position ? helpers.eligibility_requirements_sentences_from_config(@right_position) : []

    @left_ability_requirements = @left_position ? helpers.ability_milestone_requirements_for_position(@left_position) : []
    @right_ability_requirements = @right_position ? helpers.ability_milestone_requirements_for_position(@right_position) : []
    @left_seat_snapshot = seat_snapshot_for(@left_position)
    @right_seat_snapshot = seat_snapshot_for(@right_position)
  end

  private

  def set_positions
    @positions = Position.for_company(organization).unarchived.ordered
  end

  def set_selected_positions
    @left_position = find_selected_position(params[:left_position_id])
    @right_position = find_selected_position(params[:right_position_id])
  end

  def find_selected_position(param_value)
    return nil if param_value.blank?

    @positions.find { |position| position.id == param_value.to_i }
  end

  def build_assignment_rows
    left_assignments = assignments_by_id_for(@left_position)
    right_assignments = assignments_by_id_for(@right_position)
    assignment_ids = (left_assignments.keys + right_assignments.keys).uniq

    assignments_by_id = Assignment.where(id: assignment_ids).index_by(&:id)

    assignment_ids
      .sort_by { |assignment_id| assignments_by_id[assignment_id]&.title.to_s.downcase }
      .map do |assignment_id|
        {
          assignment: assignments_by_id[assignment_id],
          left: left_assignments[assignment_id],
          right: right_assignments[assignment_id]
        }
      end
  end

  def assignments_by_id_for(position)
    return {} unless position

    position.position_assignments
      .includes(assignment: [:assignment_outcomes, { assignment_abilities: :ability }])
      .index_by(&:assignment_id)
  end

  def seat_snapshot_for(position)
    return nil unless position

    seats = position.title.seats.active.ordered.includes(:title).to_a
    filled_seat_ids = seats.select(&:filled?).map(&:id)
    occupant_by_seat_id = if filled_seat_ids.any?
      EmploymentTenure.active
        .where(seat_id: filled_seat_ids)
        .includes(company_teammate: :person)
        .index_by(&:seat_id)
    else
      {}
    end

    {
      title: position.title,
      seats: seats,
      open_seats: seats.select(&:open?),
      filled_seats: seats.select(&:filled?),
      occupant_by_seat_id: occupant_by_seat_id
    }
  end
end
