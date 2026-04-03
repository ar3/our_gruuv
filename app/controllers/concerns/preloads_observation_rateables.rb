module PreloadsObservationRateables
  extend ActiveSupport::Concern

  private

  def preload_rateables_for_observations(observations)
    rating_ids_by_type = observations.flat_map(&:observation_ratings).group_by(&:rateable_type)
    rating_ids_by_type.each do |rateable_type, ratings|
      ids = ratings.map(&:rateable_id).uniq
      next if ids.empty?

      case rateable_type
      when "Assignment"
        Assignment.where(id: ids).load
      when "Ability"
        Ability.where(id: ids).load
      when "Aspiration"
        Aspiration.where(id: ids).load
      end
    end
  end
end
