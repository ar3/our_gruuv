# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Promotes a durable SlackPossibleObservation to a draft Observation.
  # Provenance via ObservationTrigger — docs/ogo-creation-attribution.md
  class PromoteSlackPossibleObservation
    TRIGGER_SOURCE = "slack"
    TRIGGER_TYPE = "ogo_source_search"
    ALLOWED_KINDS = %w[kudos feedback].freeze

    Result = Data.define(:ok?, :observation, :error, :already_draft)

    def self.call(moment:, creator:)
      new(moment: moment, creator: creator).call
    end

    def initialize(moment:, creator:)
      @moment = moment
      @creator = creator
      @company = moment.organization.root_company || moment.organization
    end

    def call
      return Result.new(ok?: false, observation: nil, error: "Sign in as a teammate.", already_draft: false) if @creator.nil?

      published = linked_observations.select(&:published?).first
      if published
        return Result.new(ok?: false, observation: published, error: "A published OGO already exists for this Slack message.", already_draft: false)
      end

      existing_draft = linked_observations.find(&:draft?)
      if existing_draft
        return Result.new(ok?: true, observation: existing_draft, error: nil, already_draft: true)
      end

      create_draft
    end

    private

    def linked_observations
      @linked_observations ||= DuplicateObservationsForMessage.call(
        organization: @moment.organization,
        channel_id: @moment.channel_id,
        message_ts: @moment.message_ts
      ).to_a
    end

    def create_draft
      item = item_hash_from_moment
      item = OgCandidateReview::DefaultObserverToViewer.apply_one(item, viewer: @creator)

      sid = item["subject_company_teammate_id"].presence&.to_i
      rid = item["responder_company_teammate_id"].presence&.to_i
      rid = @creator.id if rid.blank?
      sid = @moment.subject_company_teammate_id if sid.blank?

      subject = CompanyTeammate.find_by(id: sid)
      responder = CompanyTeammate.find_by(id: rid)
      unless teammate_in_company_tree?(subject) && teammate_in_company_tree?(responder)
        return Result.new(ok?: false, observation: nil, error: "Could not resolve observer and subject.", already_draft: false)
      end

      kind = ALLOWED_KINDS.include?(item["kind"].to_s) ? item["kind"].to_s : "feedback"
      permalink = item["permalink"].to_s.presence

      observation = nil
      ActiveRecord::Base.transaction do
        trigger = ObservationTrigger.create!(
          trigger_source: TRIGGER_SOURCE,
          trigger_type: TRIGGER_TYPE,
          trigger_data: {
            "channel_id" => @moment.channel_id,
            "message_ts" => @moment.message_ts,
            "permalink" => permalink,
            "slack_possible_observation_id" => @moment.id,
            "possible_observation_slack_search_id" => @moment.possible_observation_slack_search_id,
            "possible_observation_slack_search_batch_id" => @moment.possible_observation_slack_search_batch_id,
            "extraction_item_id" => @moment.extraction_item_id
          }.compact
        )

        observation = @company.observations.build(
          observer: responder.person,
          creator_company_teammate: @creator,
          story: story_for(item, permalink),
          privacy_level: :observed_and_managers,
          observed_at: observed_at_for(@moment.message_ts),
          published_at: nil,
          observation_type: kind,
          created_as_type: Observation::CREATED_AS_SLACK_SOURCE,
          observation_trigger: trigger
        )

        unless observation.save
          raise ActiveRecord::RecordInvalid, observation
        end

        observation.observees.create!(teammate_id: subject.id)
        seed_suggested_rating!(observation, item)
      end

      Result.new(ok?: true, observation: observation, error: nil, already_draft: false)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(
        ok?: false,
        observation: nil,
        error: Array(e.record.errors.full_messages).presence&.join(", ") || e.message,
        already_draft: false
      )
    end

    def item_hash_from_moment
      payload = @moment.payload_hash
      {
        "id" => @moment.extraction_item_id.presence || @moment.id.to_s,
        "kind" => payload[:kind].to_s,
        "quote" => @moment.quote,
        "summary" => @moment.summary,
        "permalink" => @moment.permalink,
        "channel_id" => @moment.channel_id,
        "ts" => @moment.message_ts,
        "subject_company_teammate_id" => @moment.subject_company_teammate_id,
        "responder_company_teammate_id" => payload[:responder_company_teammate_id],
        "suggested_rateable_type" => payload[:suggested_rateable_type],
        "suggested_rateable_id" => payload[:suggested_rateable_id],
        "suggested_rating" => payload[:suggested_rating],
        "suggested_goal_id" => payload[:suggested_goal_id]
      }
    end

    def seed_suggested_rating!(observation, item)
      rateable_type = item["suggested_rateable_type"].to_s
      return unless %w[Ability Assignment Aspiration].include?(rateable_type)

      rateable_id = item["suggested_rateable_id"].presence&.to_i
      return if rateable_id.blank? || rateable_id <= 0

      rating = item["suggested_rating"].to_s
      return unless %w[strongly_agree agree disagree strongly_disagree].include?(rating)

      rateable = rateable_type.constantize.find_by(id: rateable_id)
      return unless rateable
      return unless rateable_in_company_tree?(rateable)

      observation.observation_ratings.find_or_initialize_by(
        rateable_type: rateable_type,
        rateable_id: rateable_id
      ).update!(rating: rating)
    end

    def rateable_in_company_tree?(rateable)
      rateable_company = rateable.try(:company) || rateable.try(:organization)
      return false unless rateable_company

      obs_root = @company.root_company || @company
      rateable_root = rateable_company.root_company || rateable_company
      rateable_root.id == obs_root.id
    end

    def story_for(item, permalink)
      quote = item["quote"].to_s.strip
      parts = []
      parts << quote if quote.present?
      parts << "=========="
      parts << "Sourced from Slack"
      parts << "Link to message: #{permalink}" if permalink.present?
      parts.join("\n\n")
    end

    def observed_at_for(message_ts)
      return Time.current if message_ts.blank?

      Time.zone.at(message_ts.to_f)
    rescue ArgumentError, TypeError
      Time.current
    end

    def teammate_in_company_tree?(teammate)
      return false unless teammate

      teammate.organization == @company || teammate.organization.root_company == @company
    end
  end
end
