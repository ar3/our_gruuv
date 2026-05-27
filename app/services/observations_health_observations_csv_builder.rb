# frozen_string_literal: true

require "csv"

# One row per published OGO in scope for the filtered employees (Given as author, Received as observee).
# Rows are limited to observations the downloader can view (ObservationVisibilityQuery, same as index).
class ObservationsHealthObservationsCsvBuilder
  STORY_LIMIT = 500

  def initialize(organization, teammates, current_person:)
    @organization = organization
    @teammates = teammates.respond_to?(:to_ary) ? teammates.to_ary : teammates.to_a
    @current_person = current_person
  end

  def call
    CSV.generate(headers: true) do |csv|
      csv << headers
      each_data_row { |row| csv << row }
    end
  end

  private

  attr_reader :organization, :teammates, :current_person

  def headers
    [
      "Health Employee Name",
      "Health Employee Email",
      "Manager Name",
      "Manager Email",
      "Direction",
      "Observation ID",
      "Published At",
      "Observer Name",
      "Observer Email",
      "Observee Names",
      "Privacy Level",
      "Observation Type",
      "Kudos Mix Classification",
      "Rating Intensity Band",
      "Story Excerpt"
    ]
  end

  def each_data_row
    includes = [:observer, { observees: { company_teammate: :person } }, :observation_ratings]

    teammates.each do |teammate|
      manager = Goals::HealthManagerPerson.for(teammate)
      base_employee = [
        teammate.person&.display_name.to_s,
        teammate.person&.email.to_s,
        manager&.display_name.to_s,
        manager&.email.to_s
      ]

      Observations::HealthScopes.given_scope_for_person(teammate, organization, current_person: current_person)
        .includes(includes).find_each do |observation|
        yield observation_row(base_employee, "Given", observation)
      end

      Observations::HealthScopes.received_scope_for_person(teammate, organization, current_person: current_person)
        .includes(includes).find_each do |observation|
        yield observation_row(base_employee, "Received", observation)
      end
    end
  end

  def observation_row(base_employee, direction, observation)
    counts = Insights::ObservationsRatingHealth.rating_counts_from_observations([observation])
    intensity_band = Insights::ObservationsRatingHealth.combined_rating_intensity_band(counts)
    kudos_side = Insights::ObservationsRatingHealth.kudos_mix_side(observation)

    observee_names = observation.observees.filter_map { |o| o.company_teammate&.person&.display_name }.uniq.join("; ")

    base_employee + [
      direction,
      observation.id.to_s,
      datetime(observation.published_at),
      observation.observer&.display_name.to_s,
      observation.observer&.email.to_s,
      observee_names,
      observation.privacy_level.to_s,
      observation.observation_type.to_s,
      kudos_side.to_s,
      intensity_band.to_s,
      story_excerpt(observation.story)
    ]
  end

  def datetime(value)
    return "" if value.blank?

    value.respond_to?(:strftime) ? value.strftime("%Y-%m-%d %H:%M") : value.to_s
  end

  def story_excerpt(story)
    text = story.to_s.gsub(/\s+/, " ").strip
    return "" if text.blank?
    return text if text.length <= STORY_LIMIT

    "#{text[0, STORY_LIMIT]}…"
  end
end
