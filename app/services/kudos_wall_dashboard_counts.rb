# frozen_string_literal: true

# Observation counts for the Start Here Kudos Wall widget (matches wall link: public kudos only).
class KudosWallDashboardCounts
  WALL_PRIVACY = %w[public_to_company public_to_world].freeze

  def initialize(organization:, person:)
    @organization = organization
    @person = person
  end

  # [ [ label, week_count, ninety_count, all_count ], ... ]
  def rows(org_display_name:)
    return zero_rows(org_display_name) if @organization.blank? || @person.blank?

    g = given_base
    a = all_base

    [
      ["I've given", count_since(g, 1.week.ago), count_since(g, 90.days.ago), g.count],
      ["All of #{org_display_name}", count_since(a, 1.week.ago), count_since(a, 90.days.ago), a.count]
    ]
  end

  private

  def zero_rows(org_display_name)
    z = 0
    [
      ["I've given", z, z, z],
      ["All of #{org_display_name}", z, z, z]
    ]
  end

  def wall_base
    Observation
      .for_company(@organization)
      .published
      .not_soft_deleted
      .where(privacy_level: WALL_PRIVACY)
      .kudos_observations
  end

  def given_base
    wall_base.where(observer_id: @person.id)
  end

  def all_base
    wall_base
  end

  def count_since(scope, time)
    scope.where("observations.observed_at >= ?", time).count
  end
end
