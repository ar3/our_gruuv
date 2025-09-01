class Seat < ApplicationRecord
  # Associations
  belongs_to :position_type
  has_many :employment_tenures, dependent: :nullify

  # Validations
  validates :seat_needed_by, presence: true
  validates :position_type, presence: true
  validates :seat_needed_by, uniqueness: { scope: :position_type_id }

  # Enums
  enum :state, {
    draft: 'draft',
    open: 'open',
    filled: 'filled',
    archived: 'archived'
  }

  # Scopes
  scope :ordered, -> { order(:seat_needed_by) }
  scope :active, -> { where(state: [:open, :filled]) }
  scope :available, -> { where(state: :open) }
  scope :for_organization, ->(organization) { joins(:position_type).where(position_types: { organization: organization }) }

  # Instance methods
  def display_name
    "#{position_type.external_title} - #{seat_needed_by.strftime('%B %Y')}"
  end

  def title
    position_type.external_title
  end

  def summary
    position_type.description
  end

  # Assignment inheritance methods
  def required_assignments
    earliest_position = position_type.positions.order(:position_level_id).first
    return [] unless earliest_position

    earliest_position.required_assignments.includes(:assignment).order('position_assignments.max_estimated_energy DESC NULLS LAST, position_assignments.min_estimated_energy DESC NULLS LAST, assignments.title')
  end

  def suggested_assignments
    # Get all positions for this position type
    positions = position_type.positions.order(:position_level_id)
    return [] if positions.empty?

    earliest_position = positions.first
    other_positions = positions[1..-1] || []

    suggested_assignments = []

    # Add suggested assignments from earliest position
    suggested_assignments.concat(earliest_position.suggested_assignments.includes(:assignment))

    # Add all assignments from other positions
    other_positions.each do |position|
      suggested_assignments.concat(position.required_assignments.includes(:assignment))
      suggested_assignments.concat(position.suggested_assignments.includes(:assignment))
    end

    # Remove duplicates and sort
    suggested_assignments.uniq.sort_by do |pa|
      [
        -(pa.max_estimated_energy || 0),
        -(pa.min_estimated_energy || 0),
        pa.assignment.title
      ]
    end
  end

  def required_assignments_count
    required_assignments.count
  end

  def suggested_assignments_count
    suggested_assignments.count
  end

  # State management
  def needs_reconciliation?
    case state
    when 'filled'
      !employment_tenures.active.exists?
    when 'open'
      employment_tenures.active.exists?
    when 'archived'
      employment_tenures.active.exists?
    when 'draft'
      employment_tenures.exists?
    else
      false
    end
  end

  def reconcile_state!
    active_tenures = employment_tenures.active

    if active_tenures.exists?
      update!(state: :filled)
    elsif employment_tenures.exists?
      update!(state: :archived)
    else
      update!(state: :open)
    end
  end

  # HR text defaults - these will use database defaults if nil
  def seat_disclaimer_with_default
    seat_disclaimer || self.class.column_defaults['seat_disclaimer']
  end

  def work_environment_with_default
    work_environment || self.class.column_defaults['work_environment']
  end

  def physical_requirements_with_default
    physical_requirements || self.class.column_defaults['physical_requirements']
  end

  def travel_with_default
    travel || self.class.column_defaults['travel']
  end
end
