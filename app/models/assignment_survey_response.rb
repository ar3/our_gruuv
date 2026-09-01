class AssignmentSurveyResponse < ApplicationRecord
  SOURCES = %w[active required active_and_required].freeze
  RATING_RANGE = (1..6).freeze
  PERSONAL_ALIGNMENTS = %w[love like neutral prefer_not only_if_necessary].freeze
  PERSONAL_ALIGNMENT_OPTIONS = [
    [ "Love", "love" ],
    [ "Like", "like" ],
    [ "Neutral", "neutral" ],
    [ "Only If Necessary", "only_if_necessary" ]
  ].freeze
  PERSONAL_ALIGNMENT_BUTTONS = [
    [ "Only If Necessary", "only_if_necessary", 1 ],
    [ "Neutral", "neutral", 3 ],
    [ "Like", "like", 4 ],
    [ "Love", "love", 6 ]
  ].freeze
  # Numeric scores for aggregating personal alignment (results averages / charts).
  PERSONAL_ALIGNMENT_SCORES = {
    "only_if_necessary" => 1,
    "neutral" => 3,
    "like" => 5,
    "love" => 6
  }.freeze

  belongs_to :company_teammate, class_name: "CompanyTeammate", foreign_key: :teammate_id
  alias_method :teammate, :company_teammate
  belongs_to :organization
  belongs_to :assignment
  belongs_to :source_assignment_check_in, class_name: "AssignmentCheckIn", optional: true

  validates :assignment_source, inclusion: { in: SOURCES }
  validates :snapshot_title, presence: true
  validates :understandable_rating, :possible_rating, :relevant_rating,
            inclusion: { in: RATING_RANGE },
            allow_nil: true
  validates :personal_alignment, inclusion: { in: PERSONAL_ALIGNMENTS }, allow_nil: true
  validates :assignment,
            uniqueness: { scope: :teammate_id, conditions: -> { in_progress } },
            if: :in_progress?
  validate :submitted_response_is_immutable, on: :update

  scope :in_progress, -> { where(submitted_at: nil) }
  scope :submitted, -> { where.not(submitted_at: nil) }
  scope :latest_submitted_first, -> { order(submitted_at: :desc, id: :desc) }
  scope :for_organization, ->(organization) { where(organization: organization) }

  def in_progress?
    submitted_at.nil?
  end

  def submitted?
    submitted_at.present?
  end

  def content?
    understandable_rating.present? ||
      possible_rating.present? ||
      relevant_rating.present? ||
      personal_alignment.present?
  end

  alias complete? content?

  def incomplete?
    !content?
  end

  def submit!
    raise ActiveRecord::RecordInvalid, self unless in_progress?
    raise ActiveRecord::RecordInvalid, self unless content?

    update!(submitted_at: Time.current)
  end

  def source_label
    {
      "active" => "Actively held",
      "required" => "Required by position",
      "active_and_required" => "Actively held + required by position"
    }.fetch(assignment_source)
  end

  private

  def submitted_response_is_immutable
    return unless submitted_at_in_database.present?

    errors.add(:base, "Submitted feedback cannot be changed")
  end
end
