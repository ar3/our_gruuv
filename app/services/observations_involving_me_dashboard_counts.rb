# frozen_string_literal: true

# Counts for Start Here "OGO's involving me" widget (matches involving_teammate_id filter: I observed OR I'm an observee).
class ObservationsInvolvingMeDashboardCounts
  def initialize(organization:, person:, company_teammate:, current_person: nil)
    @organization = organization
    @person = person
    @company_teammate = company_teammate
    @current_person = current_person || person
  end

  # [ [ label, last_90_days, all_time ], ... ]
  def rows
    return zero_rows if @organization.blank? || @person.blank? || @company_teammate.blank?

    base = ObservationVisibilityQuery.new(@current_person, @organization).visible_observations

    given = base.where(observer_id: @person.id)
    about_ids = Observee.where(teammate_id: @company_teammate.id).select(:observation_id)
    about = base.where(id: about_ids)

    [
      ["I've given", count_since(given, 90.days.ago), given.count],
      ["About me", count_since(about, 90.days.ago), about.count]
    ]
  end

  private

  def zero_rows
    z = 0
    [
      ["I've given", z, z],
      ["About me", z, z]
    ]
  end

  def count_since(scope, time)
    scope.where("observations.observed_at >= ?", time).count
  end
end
