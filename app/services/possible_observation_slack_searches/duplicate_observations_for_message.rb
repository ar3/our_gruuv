# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Soft-duplicate lookup: Observations already linked to the same Slack message via ObservationTrigger.
  class DuplicateObservationsForMessage
    def self.call(organization:, channel_id:, message_ts:)
      new(organization: organization, channel_id: channel_id, message_ts: message_ts).call
    end

    def initialize(organization:, channel_id:, message_ts:)
      @organization = organization
      @channel_id = channel_id.to_s
      @message_ts = message_ts.to_s
    end

    def call
      return Observation.none if @channel_id.blank? || @message_ts.blank?

      company = @organization.root_company || @organization
      Observation
        .joins(:observation_trigger)
        .where(company_id: company.id)
        .where(observation_triggers: { trigger_source: "slack" })
        .where(
          "observation_triggers.trigger_data @> ?",
          { channel_id: @channel_id, message_ts: @message_ts }.to_json
        )
        .includes(:observer, :observed_teammates)
        .order(observed_at: :desc)
        .limit(5)
    end
  end
end
