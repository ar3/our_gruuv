class Seat < ApplicationRecord
  # Associations
  belongs_to :title
  has_many :employment_tenures, dependent: :nullify
  belongs_to :department, class_name: 'Organization', optional: true
  belongs_to :team, class_name: 'Organization', optional: true
  belongs_to :reports_to_seat, class_name: 'Seat', optional: true
  has_many :reporting_seats, class_name: 'Seat', foreign_key: 'reports_to_seat_id', dependent: :nullify

  # Validations
  validates :seat_needed_by, presence: true
  validates :title, presence: true
  validates :seat_needed_by, uniqueness: { scope: :title_id }

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
  scope :for_organization, ->(organization) { joins(:title).where(titles: { organization: organization }) }

  # Instance methods
  def display_name
    "#{title.external_title} - #{seat_needed_by.strftime('%B %Y')}"
  end

  def to_s
    display_name
  end

  def summary
    title.position_summary
  end

  # Assignment inheritance methods
  def required_assignments
    earliest_position = title.positions.order(:position_level_id).first
    return [] unless earliest_position

    earliest_position.required_assignments.includes(:assignment).joins(:assignment).order('position_assignments.max_estimated_energy DESC NULLS LAST, position_assignments.min_estimated_energy DESC NULLS LAST, assignments.title')
  end

  def suggested_assignments
    # Get all positions for this position type
    positions = title.positions.order(:position_level_id)
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

    # Get required assignment IDs to exclude from suggested
    required_assignment_ids = required_assignments.map(&:assignment_id)

    # Remove duplicates by assignment_id and exclude assignments that are already required
    suggested_assignments.uniq { |pa| pa.assignment_id }.reject { |pa| required_assignment_ids.include?(pa.assignment_id) }.sort_by do |pa|
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
    # Reload to ensure we have the latest employment tenures
    reload if persisted?
    
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

  def has_direct_reports?
    reporting_seats.exists?
  end
end
