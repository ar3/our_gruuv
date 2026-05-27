# frozen_string_literal: true

class ObservationHealthCacheBuilder
  def self.call(teammate, organization)
    new(teammate, organization).call
  end

  def initialize(teammate, organization)
    @teammate = teammate
    @organization = organization
  end

  def call
    given_payload = build_given_payload
    received_payload = build_received_payload
    authored = authored_observations
    {
      "given" => given_payload,
      "received" => received_payload,
      "kudos_mix" => build_kudos_mix_payload(authored),
      "rating_intensity" => build_rating_intensity_payload(authored),
      "overall_status" => Observations::HealthRecency.overall_status(
        given_payload["status"],
        received_payload["status"]
      )
    }
  end

  def build_and_save
    payload = call
    cache = ObservationHealthCache.find_or_initialize_by(teammate: teammate, organization: organization)
    cache.payload = payload
    cache.refreshed_at = Time.current
    cache.save!
    cache
  end

  private

  attr_reader :teammate, :organization

  def build_given_payload
    last_published_at = Observations::HealthScopes.given_scope(teammate, organization).maximum(:published_at)
    Observations::HealthRecency.payload_for(last_published_at)
  end

  def build_received_payload
    last_published_at = Observations::HealthScopes.received_scope(teammate, organization).maximum(:published_at)
    Observations::HealthRecency.payload_for(last_published_at)
  end

  def authored_observations
    Observations::HealthScopes
      .given_scope(teammate, organization)
      .includes(:observation_ratings)
      .to_a
  end

  def build_kudos_mix_payload(authored_observations)
    tallies = Insights::ObservationsRatingHealth.kudos_constructive_counts_from_observations(authored_observations)
    band = if authored_observations.empty?
      :no_data
    else
      Insights::ObservationsRatingHealth.kudos_constructive_ratio_band(tallies[:kudos], tallies[:constructive])
    end

    {
      "band" => band.to_s,
      "kudos_count" => tallies[:kudos],
      "constructive_count" => tallies[:constructive],
      "display_ratio" => Insights::ObservationsRatingHealth.rounded_ratio_display(tallies[:kudos], tallies[:constructive])
    }
  end

  def build_rating_intensity_payload(authored_observations)
    if authored_observations.empty?
      return {
        "band" => "no_data",
        "less_extreme_count" => 0,
        "most_extreme_count" => 0,
        "display_ratio" => "0:0"
      }
    end

    counts = Insights::ObservationsRatingHealth.rating_counts_from_observations(authored_observations)
    less_extreme = counts[:agree] + counts[:disagree]
    most_extreme = counts[:strongly_agree] + counts[:strongly_disagree]
    band = Insights::ObservationsRatingHealth.combined_rating_intensity_band(counts)

    {
      "band" => band.to_s,
      "less_extreme_count" => less_extreme,
      "most_extreme_count" => most_extreme,
      "display_ratio" => Insights::ObservationsRatingHealth.rounded_ratio_display(less_extreme, most_extreme)
    }
  end
end
