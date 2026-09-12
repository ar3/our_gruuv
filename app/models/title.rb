class Title < ApplicationRecord
  include PgSearch::Model
  has_paper_trail

  # Associations
  belongs_to :company, class_name: 'Organization'
  belongs_to :position_major_level
  belongs_to :department, optional: true
  has_many :positions, dependent: :destroy
  has_many :seats, dependent: :destroy
  has_many :seat_titles, dependent: :destroy
  has_many :associated_seats, through: :seat_titles, source: :seat
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :outbound_title_paths,
           class_name: "TitlePath",
           foreign_key: :from_title_id,
           dependent: :destroy,
           inverse_of: :from_title
  has_many :inbound_title_paths,
           class_name: "TitlePath",
           foreign_key: :to_title_id,
           dependent: :destroy,
           inverse_of: :to_title
  has_many :outbound_titles, through: :outbound_title_paths, source: :to_title
  has_many :inbound_titles, through: :inbound_title_paths, source: :from_title
  has_one :expectation_alignment_score_cache,
          class_name: "TitleExpectationAlignmentScore",
          dependent: :destroy
  has_one :published_external_reference, -> { where(reference_type: 'published') },
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  has_one :draft_external_reference, -> { where(reference_type: 'draft') },
          class_name: 'ExternalReference', as: :referable, dependent: :destroy

  # Validations
  validates :company, presence: true
  validates :position_major_level, presence: true
  validates :external_title, presence: true
  validates :external_title, uniqueness: { scope: [:company_id, :position_major_level_id] }
  validate :company_must_be_company_type
  validate :department_must_belong_to_company
  validate :end_cap_has_no_outbound_paths

  before_validation :normalize_job_description_hr_blanks

  # pg_search configuration
  pg_search_scope :search_by_full_text,
    against: { external_title: 'A' },
    using: { tsearch: { prefix: true, any_word: true } }

  multisearchable against: [:external_title]

  # Scopes
  scope :ordered, -> { order(:external_title) }
  scope :for_company, ->(company) { where(company_id: company.is_a?(Integer) ? company : company.id) }
  scope :for_department, ->(department) { where(department: department) }
  scope :unarchived, -> { where(deleted_at: nil) }
  scope :archived, -> { where.not(deleted_at: nil) }

  # Archive (soft delete) – block if unarchived positions, non-archived seats, or title paths remain
  def archived?
    deleted_at.present?
  end

  def archive!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def archivable?
    blocking_positions.none? && blocking_seats.none? && blocking_title_paths.none?
  end

  def blocking_positions
    positions.unarchived
  end

  # Seats still tied as primary or via seat_titles, excluding already-archived seats
  def blocking_seats
    Seat.left_joins(:seat_titles)
      .where('seats.title_id = :id OR seat_titles.title_id = :id', id: id)
      .where.not(state: Seat.states[:archived])
      .distinct
  end

  # Any inbound or outbound career-path edge must be cleared before archive
  def blocking_title_paths
    TitlePath.where(from_title_id: id).or(TitlePath.where(to_title_id: id))
  end

  # Instance methods
  def display_name
    external_title
  end

  def display_name_with_major_level
    title_including_level
  end

  def title_including_level
    "#{external_title} [L#{position_major_level.major_level}]"
  end

  def job_description_hr_text
    JobDescriptionHrText.for(organization: company, title: self)
  end

  # MAAP Maturity methods
  def maap_maturity_phase
    TitleMaturityService.calculate_phase(self)
  end

  def maap_maturity_phase_display
    "Phase #{maap_maturity_phase}"
  end

  def maap_maturity_next_steps
    TitleMaturityService.next_steps_message(self)
  end

  def maap_maturity_phase_status
    TitleMaturityService.phase_status(self)
  end

  def maap_maturity_phase_health_status
    TitleMaturityService.phase_health_status(self)
  end

  def maap_maturity_phase_health_reason(phase)
    TitleMaturityService.phase_health_reason(self, phase)
  end

  # External reference convenience methods
  def published_url
    published_external_reference&.url
  end

  def draft_url
    draft_external_reference&.url
  end

  private

  def normalize_job_description_hr_blanks
    self.job_description_disclaimer = job_description_disclaimer.presence
    self.work_environment = work_environment.presence
    self.physical_requirements = physical_requirements.presence
    self.travel = travel.presence
  end

  def company_must_be_company_type
    return unless company

    unless company.company?
      errors.add(:company, 'must be a company')
    end
  end

  def department_must_belong_to_company
    return unless department.present?
    
    if department.company_id != company_id
      errors.add(:department, 'must belong to the same company')
    end
  end

  def end_cap_has_no_outbound_paths
    return unless end_cap?
    return unless outbound_title_paths.exists?

    errors.add(:end_cap, "cannot be enabled while after paths exist")
  end
end
