class Prompt < ApplicationRecord
  # Associations
  belongs_to :company_teammate, class_name: 'CompanyTeammate'
  belongs_to :prompt_template
  has_many :prompt_answers, dependent: :destroy
  has_many :prompt_goals, dependent: :destroy
  has_many :goals, through: :prompt_goals

  # Validations
  validates :company_teammate, presence: true
  validates :prompt_template, presence: true
  validate :only_one_open_prompt_per_teammate

  # Scopes
  scope :open, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }
  scope :for_teammate, ->(teammate) { where(company_teammate: teammate) }
  scope :for_template, ->(template) { where(prompt_template: template) }
  scope :ordered, -> { order(created_at: :desc) }

  # Instance methods
  def open?
    closed_at.nil?
  end

  def closed?
    !open?
  end

  def close!
    update!(closed_at: Time.current)
  end

  private

  def only_one_open_prompt_per_teammate
    return unless open?
    return unless company_teammate_id.present?

    existing_open = Prompt
      .where(company_teammate_id: company_teammate_id)
      .open
      .where.not(id: id)

    if existing_open.exists?
      errors.add(:base, 'Only one open prompt allowed per teammate')
    end
  end
end

