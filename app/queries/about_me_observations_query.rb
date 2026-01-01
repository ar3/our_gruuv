class AboutMeObservationsQuery
  def initialize(teammate, organization)
    @teammate = teammate
    @organization = organization
    @since_date = 30.days.ago
    @teammate_ids = @teammate.person.teammates.where(organization: @organization).pluck(:id)
  end

  def observations_given
    Observation
      .where(observer_id: @teammate.person.id, company: @organization)
      .where.not(published_at: nil)
      .where.not(privacy_level: 'observer_only')
      .where('observed_at >= ?', @since_date)
      .where(deleted_at: nil)
      .where.not(id: self_observation_ids)
      .order(observed_at: :desc)
  end

  def observations_received
    Observation
      .joins(:observees)
      .where(observees: { teammate_id: @teammate_ids })
      .where(company: @organization)
      .where.not(published_at: nil)
      .where.not(privacy_level: 'observer_only')
      .where('observed_at >= ?', @since_date)
      .where(deleted_at: nil)
      .distinct
      .order(observed_at: :desc)
  end

  private

  def self_observation_ids
    Observation.joins(:observees)
               .where(observer_id: @teammate.person.id)
               .where(observees: { teammate_id: @teammate_ids })
               .select(:id)
  end
end

