class Seat < ApplicationRecord
  # Associations
  belongs_to :title
  has_many :seat_titles, dependent: :destroy
  has_many :titles, -> { distinct }, through: :seat_titles
  has_many :employment_tenures, dependent: :nullify
  belongs_to :team, optional: true
  belongs_to :reports_to_seat, class_name: 'Seat', optional: true
  has_many :reporting_seats, class_name: 'Seat', foreign_key: 'reports_to_seat_id', dependent: :nullify

  # Validations
  validates :seat_needed_by, presence: true
  validates :title, presence: true
  validates :seat_needed_by, uniqueness: { scope: :title_id }
  validate :at_least_one_title_selected
  validate :all_titles_belong_to_same_company

  after_commit :ensure_primary_title_associated, on: [:create, :update]

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
  scope :for_organization, ->(organization) { joins(:title).where(titles: { company_id: organization.id }) }
  scope :for_department, ->(department) { joins(:title).where(titles: { department_id: department.id }) }

  # Instance methods
  def display_name
    "#{title_label} - #{seat_needed_by.strftime('%B %Y')}"
  end

  def to_s
    display_name
  end

  def summary
    title.position_summary
  end

  def title_label
    associated_titles.map(&:external_title).uniq.join(', ')
  end

  def associated_titles
    loaded_titles = titles.to_a
    loaded_titles << title if title.present?
    loaded_titles.compact.uniq(&:id)
  end

  def includes_title_id?(candidate_title_id)
    candidate_id = candidate_title_id.to_i
    return false if candidate_id.zero?

    return true if title_id == candidate_id

    if association(:seat_titles).loaded?
      seat_titles.any? { |seat_title| seat_title.title_id == candidate_id }
    else
      seat_titles.where(title_id: candidate_id).exists?
    end
  end

  # Assignment inheritance methods
  def required_assignments
    earliest_position = title.positions.order(:position_level_id).first
    return [] unless earliest_position

    earliest_position.required_assignments
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
      [-(pa.max_estimated_energy || 0), pa.assignment.title]
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

  # Derive department from title
  def department
    title&.department
  end

  def department_id
    title&.department_id
  end

  def title_ids=(ids)
    normalized_ids = Array(ids).reject(&:blank?).map(&:to_i).uniq
    self.title_id = normalized_ids.first if normalized_ids.present?
    super(normalized_ids)
  end

  private

  def at_least_one_title_selected
    return if title_id.present?
    return if titles.any?

    errors.add(:titles, 'must include at least one title')
  end

  def all_titles_belong_to_same_company
    return unless title.present?

    invalid_titles = titles.reject { |associated_title| associated_title.company_id == title.company_id }
    return if invalid_titles.empty?

    errors.add(:titles, 'must belong to the same company as the seat')
  end

  def ensure_primary_title_associated
    return if title_id.blank?

    seat_titles.find_or_create_by(title_id: title_id)
  end
end
