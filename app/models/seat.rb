class Seat < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :title
  has_many :seat_titles, dependent: :destroy
  has_many :titles, through: :seat_titles
  has_many :employment_tenures, dependent: :nullify
  belongs_to :team, optional: true
  belongs_to :reports_to_seat, class_name: 'Seat', optional: true
  has_many :reporting_seats, class_name: 'Seat', foreign_key: 'reports_to_seat_id', dependent: :nullify

  # Validations
  validates :seat_needed_by, presence: true
  validates :title, presence: true
  validate :at_least_one_title_selected
  validate :all_titles_belong_to_same_company
  validate :associated_titles_unique_for_needed_by

  after_save :sync_pending_title_ids
  after_commit :ensure_primary_title_associated, on: [:create, :update]
  before_validation :normalize_job_description_hr_blanks

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
    return true if Array(@pending_title_ids).include?(candidate_id)

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

  # HR text cascade: seat → title → organization
  def job_description_hr_text
    JobDescriptionHrText.for(organization: title.company, title: title, seat: self)
  end

  def seat_disclaimer_with_default
    job_description_hr_text.disclaimer
  end

  def work_environment_with_default
    job_description_hr_text.work_environment
  end

  def physical_requirements_with_default
    job_description_hr_text.physical_requirements
  end

  def travel_with_default
    job_description_hr_text.travel
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

  def title_ids
    return @pending_title_ids if defined?(@pending_title_ids) && !@pending_title_ids.nil?

    associated_title_ids
  end

  def title_ids=(ids)
    normalized_ids = Array(ids).reject(&:blank?).map(&:to_i).uniq
    @pending_title_ids = normalized_ids
    self.title_id = normalized_ids.first if normalized_ids.present?
  end

  # Title ids currently selected for this seat (primary + join-table), including
  # unsaved title_ids= assignments used during validation.
  def associated_title_ids
    ids = []
    ids.concat(@pending_title_ids) if defined?(@pending_title_ids) && @pending_title_ids
    ids << title_id if title_id.present?
    ids.concat(seat_titles.map(&:title_id)) if seat_titles.loaded? || (persisted? && seat_titles.any?)
    ids.compact.map(&:to_i).uniq.reject(&:zero?)
  end

  private

  def normalize_job_description_hr_blanks
    self.seat_disclaimer = seat_disclaimer.presence
    self.work_environment = work_environment.presence
    self.physical_requirements = physical_requirements.presence
    self.travel = travel.presence
  end

  def at_least_one_title_selected
    return if associated_title_ids.any?

    errors.add(:titles, 'must include at least one title')
  end

  def all_titles_belong_to_same_company
    return unless title.present?

    company_id = title.company_id
    other_ids = associated_title_ids - [title_id]
    return if other_ids.empty?

    invalid = Title.where(id: other_ids).where.not(company_id: company_id)
    return if invalid.none?

    errors.add(:titles, 'must belong to the same company as the seat')
  end

  def associated_titles_unique_for_needed_by
    return if seat_needed_by.blank?

    candidate_ids = associated_title_ids
    return if candidate_ids.empty?

    conflicting = Seat.left_joins(:seat_titles)
      .where(seat_needed_by: seat_needed_by)
      .where("seats.title_id IN (:ids) OR seat_titles.title_id IN (:ids)", ids: candidate_ids)
    conflicting = conflicting.where.not(id: id) if persisted?

    return unless conflicting.exists?

    errors.add(:titles, "cannot share a title with another seat that has the same needed-by date")
  end

  def sync_pending_title_ids
    return unless defined?(@pending_title_ids) && !@pending_title_ids.nil?

    desired_ids = @pending_title_ids.dup
    desired_ids << title_id if title_id.present?
    desired_ids = desired_ids.compact.map(&:to_i).uniq

    seat_titles.where.not(title_id: desired_ids).delete_all
    desired_ids.each do |tid|
      seat_titles.find_or_create_by!(title_id: tid)
    end

    @pending_title_ids = nil
    titles.reset
    seat_titles.reset
  end

  def ensure_primary_title_associated
    return if title_id.blank?

    seat_titles.find_or_create_by!(title_id: title_id)
  end
end
