# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Promotes included batch candidates to draft Observations.
  # Provenance: ObservationTrigger (not a Slack FK on observations).
  # See docs/ogo-creation-attribution.md
  class BatchCreateDraftObservationsService
    TRIGGER_SOURCE = "slack"
    TRIGGER_TYPE = "ogo_source_search"
    ALLOWED_KINDS = %w[kudos feedback].freeze

    def self.call(batch:, creator:, extraction_ids: nil)
      new(batch: batch, creator: creator, extraction_ids: extraction_ids).call
    end

    def initialize(batch:, creator:, extraction_ids:)
      @batch = batch
      @search = batch.possible_observation_slack_search
      @creator = creator
      @company = @search.organization.root_company || @search.organization
      @extraction_ids =
        if extraction_ids.nil?
          nil
        else
          Array(extraction_ids).map(&:to_s).reject(&:blank?).to_set
        end
    end

    def call
      items = @batch.extraction_items.map(&:to_h).map(&:stringify_keys)
      errors = []
      created = 0
      skipped_already = 0
      soft_duplicate_count = 0

      items.each do |item|
        next unless promote_item?(item)
        next skipped_already += 1 if item["observation_id"].present?

        channel_id = item["channel_id"].to_s.presence
        message_ts = item["ts"].to_s.presence
        was_duplicate = duplicate_exists?(channel_id, message_ts)

        result = create_draft_for(item)
        if result.ok?
          item["observation_id"] = result.value.id
          created += 1
          soft_duplicate_count += 1 if was_duplicate
        else
          errors << "Row #{item["id"]}: #{Array(result.error).join(", ")}"
        end
      end

      @batch.replace_extraction_items!(items) if created.positive? || errors.any?

      Result.ok(
        created: created,
        skipped_already: skipped_already,
        soft_duplicate_count: soft_duplicate_count,
        errors: errors
      )
    end

    private

    def promote_item?(item)
      included = ActiveModel::Type::Boolean.new.cast(item["include"])
      return false unless included
      return true if @extraction_ids.nil?

      @extraction_ids.include?(item["id"].to_s)
    end

    def create_draft_for(item)
      sid = item["subject_company_teammate_id"].presence&.to_i
      rid = item["responder_company_teammate_id"].presence&.to_i
      return Result.err("choose both observer and subject.") if sid.blank? || rid.blank?

      subject = CompanyTeammate.find_by(id: sid)
      responder = CompanyTeammate.find_by(id: rid)
      unless teammate_in_company_tree?(subject) && teammate_in_company_tree?(responder)
        return Result.err("invalid teammate selection.")
      end

      kind = ALLOWED_KINDS.include?(item["kind"].to_s) ? item["kind"].to_s : "feedback"
      channel_id = item["channel_id"].to_s.presence
      message_ts = item["ts"].to_s.presence
      permalink = item["permalink"].to_s.presence

      observation = nil
      ActiveRecord::Base.transaction do
        trigger = ObservationTrigger.create!(
          trigger_source: TRIGGER_SOURCE,
          trigger_type: TRIGGER_TYPE,
          trigger_data: {
            "channel_id" => channel_id,
            "message_ts" => message_ts,
            "permalink" => permalink,
            "possible_observation_slack_search_id" => @search.id,
            "possible_observation_slack_search_batch_id" => @batch.id,
            "extraction_item_id" => item["id"]
          }.compact
        )

        observation = @company.observations.build(
          observer: responder.person,
          creator_company_teammate: @creator,
          story: story_for(item, permalink),
          privacy_level: :observed_and_managers,
          observed_at: observed_at_for(message_ts),
          published_at: nil,
          observation_type: kind,
          created_as_type: Observation::CREATED_AS_SLACK_SOURCE,
          observation_trigger: trigger,
          goal_id: valid_goal_id(item["suggested_goal_id"], subject)
        )

        unless observation.save
          raise ActiveRecord::RecordInvalid, observation
        end

        observation.observees.create!(teammate_id: subject.id)
      end

      Result.ok(observation)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.presence || e.message)
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

    def valid_goal_id(raw_id, subject)
      goal_id = raw_id.presence&.to_i
      return nil if goal_id.blank?

      goal = Goal.find_by(id: goal_id)
      return nil unless goal
      return nil unless goal.owner_type == "CompanyTeammate" && goal.owner_id == subject.id

      obs_root = @company.root_company || @company
      goal_root = goal.company&.root_company || goal.company
      return nil unless goal_root && obs_root && goal_root.id == obs_root.id

      goal.id
    end

    def duplicate_exists?(channel_id, message_ts)
      return false if channel_id.blank? || message_ts.blank?

      DuplicateObservationsForMessage.call(
        organization: @company,
        channel_id: channel_id,
        message_ts: message_ts
      ).any?
    end

    def teammate_in_company_tree?(teammate)
      return false unless teammate

      teammate.organization == @company || teammate.organization.root_company == @company
    end
  end
end
