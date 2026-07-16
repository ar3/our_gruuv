class AssignmentSurveySubmission < ApplicationRecord
  STATUSES = %w[draft finalized].freeze

  belongs_to :organization
  belongs_to :company_teammate, class_name: "CompanyTeammate", foreign_key: :teammate_id
  alias_method :teammate, :company_teammate

  has_many :responses,
           -> { order(:snapshot_title) },
           class_name: "AssignmentSurveyResponse",
           dependent: :destroy,
           inverse_of: :submission

  accepts_nested_attributes_for :responses

  validates :status, inclusion: { in: STATUSES }
  validates :company_teammate, uniqueness: { conditions: -> { where(status: "draft") } }, if: :draft?
  validate :teammate_belongs_to_organization
  validate :all_responses_complete, if: :finalized?
  validate :finalized_submission_is_immutable, on: :update

  scope :draft, -> { where(status: "draft") }
  scope :finalized, -> { where(status: "finalized") }
  scope :latest_first, -> { order(finalized_at: :desc, created_at: :desc) }

  def draft?
    status == "draft"
  end

  def finalized?
    status == "finalized"
  end

  def complete_response_count
    responses.count(&:complete?)
  end

  def progress_percentage
    return 0 if responses.empty?

    ((complete_response_count.to_f / responses.size) * 100).round
  end

  def finalize!
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless draft?

      self.status = "finalized"
      self.finalized_at = Time.current
      save!
    end
  end

  private

  def teammate_belongs_to_organization
    return if company_teammate.blank? || organization.blank?
    return if company_teammate.organization_id == organization_id

    errors.add(:company_teammate, "must belong to the survey organization")
  end

  def all_responses_complete
    errors.add(:base, "Every assignment needs all three ratings before finalizing") if responses.empty? || responses.any?(&:incomplete?)
  end

  def finalized_submission_is_immutable
    return unless status_in_database == "finalized"

    errors.add(:base, "Finalized survey submissions cannot be changed")
  end
end
