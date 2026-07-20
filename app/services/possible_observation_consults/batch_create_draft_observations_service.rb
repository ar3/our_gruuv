# frozen_string_literal: true

module PossibleObservationConsults
  # Promote included consult candidates to draft OGOs (Slack-parity outcome).
  # Provenance via ObservationTrigger — docs/ogo-creation-attribution.md
  class BatchCreateDraftObservationsService
    TRIGGER_SOURCE = "ogo_consult"
    TRIGGER_TYPE = "ogo_source_search"
    ALLOWED_KINDS = %w[kudos feedback].freeze

    def self.call(consult:, creator:, extraction_ids: nil)
      new(consult: consult, creator: creator, extraction_ids: extraction_ids).call
    end

    def initialize(consult:, creator:, extraction_ids:)
      @consult = consult
      @creator = creator
      @company = consult.organization.root_company || consult.organization
      @extraction_ids =
        if extraction_ids.nil?
          nil
        else
          Array(extraction_ids).map(&:to_s).reject(&:blank?).to_set
        end
    end

    def call
      items = @consult.extraction_items.map(&:to_h).map(&:stringify_keys)
      errors = []
      created = 0
      skipped_already = 0

      items.each do |item|
        next unless promote_item?(item)
        next skipped_already += 1 if item["observation_id"].present?

        result = create_draft_for(item)
        if result.ok?
          item["observation_id"] = result.value.id
          created += 1
        else
          errors << "Row #{item['id']}: #{Array(result.error).join(', ')}"
        end
      end

      @consult.replace_extraction_items!(items) if created.positive? || errors.any?

      Result.ok(created: created, skipped_already: skipped_already, errors: errors)
    end

    private

    def promote_item?(item)
      return false unless ActiveModel::Type::Boolean.new.cast(item["include"])
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

      observation = nil
      ActiveRecord::Base.transaction do
        trigger = ObservationTrigger.create!(
          trigger_source: TRIGGER_SOURCE,
          trigger_type: TRIGGER_TYPE,
          trigger_data: {
            "possible_observation_consult_id" => @consult.id,
            "extraction_item_id" => item["id"],
            "display_name" => @consult.display_name
          }.compact
        )

        observation = @company.observations.build(
          observer: responder.person,
          creator_company_teammate: @creator,
          story: story_for(item),
          privacy_level: :observed_and_managers,
          observed_at: Time.current,
          published_at: nil,
          observation_type: kind,
          created_as_type: Observation::CREATED_AS_OGO_CONSULT,
          observation_trigger: trigger,
          goal_id: valid_goal_id(item["suggested_goal_id"], subject)
        )
        raise ActiveRecord::RecordInvalid, observation unless observation.save

        observation.observees.create!(teammate_id: subject.id)
        seed_suggested_rating!(observation, item)
      end

      Result.ok(observation)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.presence || e.message)
    end

    def story_for(item)
      quote = item["quote"].to_s.strip
      parts = []
      parts << quote if quote.present?
      parts << "=========="
      parts << "Sourced from Consult OG to Find OGOs"
      parts << @consult.display_name if @consult.display_name.present?
      parts.join("\n\n")
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

      rateable_company = rateable.try(:company) || rateable.try(:organization)
      return unless rateable_company

      obs_root = @company.root_company || @company
      rateable_root = rateable_company.root_company || rateable_company
      return unless rateable_root.id == obs_root.id

      observation.observation_ratings.find_or_initialize_by(
        rateable_type: rateable_type,
        rateable_id: rateable_id
      ).update!(rating: rating)
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

    def teammate_in_company_tree?(teammate)
      return false unless teammate

      teammate.organization == @company || teammate.organization.root_company == @company
    end
  end
end
