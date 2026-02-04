class Observee < ApplicationRecord
  belongs_to :observation
  belongs_to :company_teammate, class_name: 'CompanyTeammate', foreign_key: 'teammate_id'
  alias_method :teammate, :company_teammate
  alias_method :teammate=, :company_teammate=

  validates :observation, :company_teammate, presence: true
  validates :teammate_id, uniqueness: { scope: :observation_id }
  
  # Ensure the teammate is in the same company as the observation
  validate :teammate_in_same_company
  
  private
  
  def teammate_in_same_company
    return unless observation && company_teammate
    
    # Allow moment-based observations to bypass this validation if moment provides context
    return if observation.observable_moment_id.present? || observation.observable_moment.present?
    
    unless company_teammate.organization == observation.company
      errors.add(:company_teammate, "must be in the same company as the observation")
    end
  end
end
