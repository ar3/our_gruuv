class Observee < ApplicationRecord
  belongs_to :observation
  belongs_to :teammate
  
  validates :observation, :teammate, presence: true
  validates :teammate_id, uniqueness: { scope: :observation_id }
  
  # Ensure the teammate is in the same company as the observation
  validate :teammate_in_same_company
  
  private
  
  def teammate_in_same_company
    return unless observation && teammate
    
    unless teammate.organization == observation.company
      errors.add(:teammate, "must be in the same company as the observation")
    end
  end
end
