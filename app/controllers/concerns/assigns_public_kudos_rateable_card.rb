module AssignsPublicKudosRateableCard
  extend ActiveSupport::Concern

  private

  def assign_public_kudos_for_rateable_card!(organization:, rateable_type:, rateable_id:, rateable_display_name:)
    @public_kudos_for_rateable = Observations::PublicKudosForRateable.call(
      organization: organization,
      rateable_type: rateable_type,
      rateable_id: rateable_id
    )
    preload_rateables_for_observations(@public_kudos_for_rateable)
    return_params = { return_url: request.original_url, return_text: "Back to #{rateable_display_name}" }
    @public_kudos_all_kudos_observations_url = organization_observations_path(
      organization,
      {
        rateable_type: rateable_type,
        rateable_id: rateable_id,
        observation_type: "kudos",
        timeframe: "all",
        view: "wall"
      }.merge(return_params)
    )
    @public_kudos_all_types_observations_url = organization_observations_path(
      organization,
      {
        rateable_type: rateable_type,
        rateable_id: rateable_id,
        timeframe: "all",
        view: "wall"
      }.merge(return_params)
    )
    @public_kudos_rateable_display_name = rateable_display_name
  end
end
