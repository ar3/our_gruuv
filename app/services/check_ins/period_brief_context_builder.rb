# frozen_string_literal: true

module CheckIns
  # Packs viewer-visible check-in research context for a period brief consult.
  class PeriodBriefContextBuilder
    RATEABLE_KINDS = {
      "assignment" => "Assignment",
      "aspiration" => "Aspiration",
      "position" => "Position"
    }.freeze

    Result = Data.define(
      :object_kind,
      :object_type_label,
      :object_name,
      :object_label,
      :casual_name,
      :period_start_on,
      :period_end_on,
      :preface,
      :position_algorithm_paragraph,
      :user_prompt
    )

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, viewer_person:, teammate:, check_in:, check_in_kind:)
      @organization = organization
      @viewer_person = viewer_person
      @teammate = teammate
      @check_in = check_in
      @check_in_kind = check_in_kind.to_s
    end

    def call
      raise ArgumentError, "Unknown check_in_kind: #{@check_in_kind}" unless RATEABLE_KINDS.key?(@check_in_kind)

      period_start = period_start_on
      period_end = Date.current
      object_type_label = object_type_label_for
      object_name = object_name_for
      casual = @teammate.person.casual_name
      object_label = "#{object_type_label} #{object_name}"
      preface = build_preface(
        casual_name: casual,
        object_label: object_label,
        period_start_on: period_start,
        period_end_on: period_end
      )
      algorithm = position_algorithm_paragraph

      Result.new(
        object_kind: @check_in_kind,
        object_type_label: object_type_label,
        object_name: object_name,
        object_label: object_label,
        casual_name: casual,
        period_start_on: period_start,
        period_end_on: period_end,
        preface: preface,
        position_algorithm_paragraph: algorithm,
        user_prompt: build_user_prompt(
          casual_name: casual,
          object_label: object_label,
          period_start_on: period_start,
          period_end_on: period_end,
          algorithm: algorithm
        )
      )
    end

    private

    def build_preface(casual_name:, object_label:, period_start_on:, period_end_on:)
      start_label = period_start_on.strftime("%B %-d, %Y")
      end_label = period_end_on.strftime("%B %-d, %Y")
      "OG's brief of #{casual_name} and #{object_label} between #{start_label} - now #{end_label}:"
    end

    def build_user_prompt(casual_name:, object_label:, period_start_on:, period_end_on:, algorithm:)
      sections = []
      sections << "Teammate: #{casual_name} (#{@teammate.person.preferred_first_then_last_display_name})"
      sections << "Object: #{object_label}"
      sections << "Period: #{period_start_on} through #{period_end_on}"
      sections << "Viewer role: #{viewer_is_employee? ? 'employee (self check-in)' : 'manager / other rater'}"
      sections << ""
      sections << "TENURE / TIME ON OBJECT:"
      sections << tenure_section
      sections << ""
      sections << "LAST FINALIZED CHECK-IN:"
      sections << last_check_in_section
      sections << ""
      sections << "PERIOD OBSERVATIONS (viewer-visible only):"
      sections << observations_section(period_start_on)
      if @check_in_kind == "assignment"
        sections << ""
        sections << "LINKED GOALS:"
        sections << linked_goals_section
      end
      if algorithm.present?
        sections << ""
        sections << "NOTE: The product will prepend a deterministic Position algorithm paragraph to the brief."
        sections << "Do not repeat it. Write only a vaguer whole-person / period summary from the context above."
        sections << "Still never recommend a rating."
      end
      sections << ""
      sections << "Prompt version: #{PeriodBriefPrompts::PROMPT_VERSION}"
      sections.join("\n")
    end

    def object_type_label_for
      case @check_in_kind
      when "assignment" then "Assignment"
      when "aspiration" then "Value"
      when "position" then "Position"
      end
    end

    def object_name_for
      case @check_in_kind
      when "assignment"
        @check_in.assignment.title
      when "aspiration"
        @check_in.aspiration.name
      when "position"
        position = @check_in.employment_tenure&.position
        position&.title&.external_title.presence || "Position"
      end
    end

    def period_start_on
      latest = latest_finalized
      if latest&.official_check_in_completed_at.present?
        latest.official_check_in_completed_at.to_date
      else
        earliest_tenure_start || @check_in.check_in_started_on
      end
    end

    def earliest_tenure_start
      case @check_in_kind
      when "assignment"
        AssignmentTenure.where(company_teammate: @teammate, assignment: @check_in.assignment)
                        .minimum(:started_at)&.to_date
      when "aspiration"
        nil
      when "position"
        @teammate.employment_tenures.minimum(:started_at)&.to_date
      end
    end

    def latest_finalized
      case @check_in_kind
      when "assignment"
        AssignmentCheckIn.latest_finalized_for(@teammate, @check_in.assignment)
      when "aspiration"
        AspirationCheckIn.latest_finalized_for(@teammate, @check_in.aspiration)
      when "position"
        PositionCheckIn.latest_finalized_for(@teammate)
      end
    end

    def tenure_section
      case @check_in_kind
      when "assignment"
        tenures = AssignmentTenure
          .where(company_teammate: @teammate, assignment: @check_in.assignment)
          .order(started_at: :desc)
          .limit(10)
        return "(No tenure history on record.)" if tenures.none?

        tenures.map do |tenure|
          ended = tenure.ended_at ? tenure.ended_at.to_date : "active"
          "- Started #{tenure.started_at.to_date}; ended #{ended}; anticipated energy #{tenure.anticipated_energy_percentage}%"
        end.join("\n")
      when "aspiration"
        "(Values check-ins do not use assignment tenure; summarize from observations and prior check-ins.)"
      when "position"
        tenures = @teammate.employment_tenures.order(started_at: :desc).limit(5)
        return "(No employment tenure on record.)" if tenures.none?

        tenures.map do |tenure|
          title = tenure.position&.title&.external_title.presence || "Position"
          ended = tenure.ended_at ? tenure.ended_at.to_date : "active"
          "- #{title}: started #{tenure.started_at.to_date}; ended #{ended}"
        end.join("\n")
      end
    end

    def last_check_in_section
      latest = latest_finalized
      return "(No prior finalized check-in.)" if latest.nil?

      lines = [
        "- Finalized on: #{latest.official_check_in_completed_at&.to_date}",
        "- Official rating: #{rating_label_for(latest)}"
      ]
      lines << "- Shared notes: #{latest.shared_notes.to_s.truncate(1_500)}" if latest.shared_notes.present?
      lines.join("\n")
    end

    def rating_label_for(check_in)
      case check_in
      when AssignmentCheckIn, AspirationCheckIn
        check_in.official_rating.to_s.humanize.presence || "(none)"
      when PositionCheckIn
        data = EmploymentTenure::POSITION_RATINGS[check_in.official_rating]
        data ? "#{data[:emoji]} #{data[:label]}" : check_in.official_rating.to_s
      else
        "(none)"
      end
    end

    def observations_section(period_start_on)
      observations = visible_period_observations(period_start_on)
      return "(No viewer-visible observations in this period.)" if observations.none?

      observations.map { |observation| format_observation(observation) }.join("\n\n")
    end

    def visible_period_observations(period_start_on)
      params = {
        observee_ids: [@teammate.id],
        timeframe: "between",
        timeframe_start_date: period_start_on.to_s,
        timeframe_end_date: Date.current.to_s,
        include_viewer_drafts: true
      }
      if @check_in_kind == "assignment"
        params[:rateable_type] = "Assignment"
        params[:rateable_id] = @check_in.assignment_id
      elsif @check_in_kind == "aspiration"
        params[:rateable_type] = "Aspiration"
        params[:rateable_id] = @check_in.aspiration_id
      end

      scope = ObservationsQuery.new(@organization, params, current_person: @viewer_person).call
      if @check_in_kind == "assignment"
        scope = scope.joins(:observation_ratings)
                     .where(observation_ratings: { rateable_type: "Assignment", rateable_id: @check_in.assignment_id })
                     .distinct
      elsif @check_in_kind == "aspiration"
        scope = scope.joins(:observation_ratings)
                     .where(observation_ratings: { rateable_type: "Aspiration", rateable_id: @check_in.aspiration_id })
                     .distinct
      end

      scope.includes(:observer, :observation_ratings)
           .order(observed_at: :desc)
           .limit(40)
           .to_a
    end

    def format_observation(observation)
      ratings = observation.observation_ratings.map do |rating|
        name = rating.rateable.try(:title) || rating.rateable.try(:name) || rating.rateable_type
        "#{rating.rating} on #{rating.rateable_type} #{name}"
      end
      [
        "- #{observation.observed_at&.to_date} · #{observation.observation_type} · observer #{observation.observer&.display_name}",
        "  Story: #{observation.story.to_s.squish.truncate(800)}",
        ("  Ratings: #{ratings.join('; ')}" if ratings.any?)
      ].compact.join("\n")
    end

    def linked_goals_section
      data = Goals::VisibleAssociableGoalsForDisplay.new(
        associable: @check_in.assignment,
        viewer: @viewer_person,
        goals_scope: Goal.where(company_id: @organization.id),
        subject_teammate: @teammate
      ).call
      goals = Array(data[:goals]).first(20)
      return "(No linked goals.)" if goals.none?

      goals.map do |goal|
        "- #{goal.title.to_s.presence || '(untitled)'}"
      end.join("\n")
    rescue StandardError
      "(Linked goals unavailable.)"
    end

    def position_algorithm_paragraph
      return nil unless @check_in_kind == "position"

      summary = MyGrowth::ExperiencesSummary.for_teammate(
        @teammate,
        organization: @organization,
        viewer_teammate: viewer_company_teammate
      )
      guidance = summary.guidance_position_rating
      return nil unless guidance

      buckets = summary.guidance_rating_energy_buckets || {}
      total = buckets.values.sum
      return nil if total <= 0

      exceeding_pct = ((buckets.fetch("exceeding", 0).to_f / total) * 100).round
      meeting_pct = ((buckets.fetch("meeting", 0).to_f / total) * 100).round
      wtm_pct = ((buckets.fetch("working_to_meet", 0).to_f / total) * 100).round
      bucket_label = EmploymentTenure::POSITION_RATINGS.dig(guidance, :label) || guidance.to_s
      manager_name = Goals::HealthManagerPerson.manager_teammate_for(@teammate)&.person&.casual_name.presence || "the manager"

      "OG will never make a recommendation on how to rate a teammate… however, based on this simple algorithm, since #{manager_name} has rated #{exceeding_pct}% Exceeding, #{meeting_pct}% Meeting, and #{wtm_pct}% Working to Meet, that would fall into the #{bucket_label} bucket. However, there are other non-OG aware and values-based concerns that would cause the final rating to differ from this."
    end

    def viewer_is_employee?
      @viewer_person.id == @teammate.person_id
    end

    def viewer_company_teammate
      CompanyTeammate.find_by(person: @viewer_person, organization: @organization)
    end
  end
end
