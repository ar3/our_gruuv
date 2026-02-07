# STI subclass of KudosTransaction
# Records when an observer gives points from their balance to observees (observation award flow)
# company_teammate is the observer; points_to_give_delta is negative
class ObserverGiveTransaction < KudosTransaction
  validates :observation_id, presence: true
  validate :negative_points_to_give

  scope :for_observation, ->(observation) { where(observation: observation) }

  private

  def negative_points_to_give
    return if points_to_give_delta.blank?
    if points_to_give_delta >= 0
      errors.add(:points_to_give_delta, "must be negative for observer give")
    end
    if points_to_spend_delta.to_f != 0
      errors.add(:points_to_spend_delta, "must be zero for observer give")
    end
  end
end
