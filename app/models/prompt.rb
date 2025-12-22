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
  validate :only_one_open_prompt_per_teammate_per_template

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

  def next_prompt_for_teammate(teammate)
    company = teammate.organization.root_company || teammate.organization
    
    # Get the current template
    current_template = prompt_template
    
    # Determine next template based on hierarchy
    next_template = nil
    
    if current_template.is_primary
      # Primary → Secondary
      next_template = PromptTemplate.where(company: company).available.secondary.first
    elsif current_template.is_secondary
      # Secondary → Tertiary
      next_template = PromptTemplate.where(company: company).available.tertiary.first
    end
    
    # If no next template found, return nil (will redirect to index)
    return nil unless next_template
    
    # Find open prompt for the next template
    next_prompt = Prompt.where(company_teammate: teammate, prompt_template: next_template).open.first
    
    # If no open prompt exists, create one so the button can show
    unless next_prompt
      next_prompt = Prompt.create!(
        company_teammate: teammate,
        prompt_template: next_template
      )
    end
    
    next_prompt
  end

  private

  def only_one_open_prompt_per_teammate_per_template
    return unless open?
    return unless company_teammate_id.present?
    return unless prompt_template_id.present?

    existing_open = Prompt
      .where(company_teammate_id: company_teammate_id, prompt_template_id: prompt_template_id)
      .open
      .where.not(id: id)

    if existing_open.exists?
      errors.add(:base, 'Only one open prompt allowed per teammate per template')
    end
  end
end

