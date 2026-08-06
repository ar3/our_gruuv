# frozen_string_literal: true

module OgAcademy
  # Computes demo (pedagogical) OG Academy milestone progress from product usage.
  # Never creates Ability or TeammateMilestone records.
  class ProgressService
    LEVELS = (1..5).to_a.freeze
    RATING_FOUR = %w[strongly_agree agree disagree strongly_disagree].freeze
    MAAP_VERSION_TYPES = %w[Position Assignment Ability Aspiration Seat].freeze
    MAAP_COMMENTABLE_TYPES = %w[Position Assignment Ability Aspiration].freeze
    ADVANCED_FROM_LEVEL = 3

    Criterion = Struct.new(:key, :label, :done, :hint, keyword_init: true)
    Level = Struct.new(
      :level, :title, :audience, :complete, :criteria, :marketing_why, :placeholder,
      keyword_init: true
    ) do
      def complete?
        complete
      end

      def done_count
        criteria.count(&:done)
      end

      def total_count
        criteria.size
      end
    end

    def initialize(organization:, company_teammate:)
      @organization = organization
      @company_teammate = company_teammate
      @person = company_teammate.person
    end

    def levels
      @levels ||= LEVELS.map { |n| build_level(n) }
    end

    def earned_levels
      levels.select(&:complete?)
    end

    def current_level
      levels.find { |l| !l.complete? && visible_for?(l) } || levels.reverse.find(&:complete?)
    end

    def has_direct_reports?
      @has_direct_reports ||= @company_teammate.has_direct_reports?
    end

    def admin_track?
      return @admin_track if defined?(@admin_track)

      @admin_track = @company_teammate.can_manage_employment? || @person.og_admin?
    end

    def visible_for?(level)
      case level.audience
      when :everyone then true
      when :manager then has_direct_reports?
      when :admin then admin_track?
      when :future then true
      else true
      end
    end

    def collapsed_advanced?
      !has_direct_reports? && !admin_track?
    end

    private

    def build_level(n)
      case n
      when 1 then level_one
      when 2 then level_two
      when 3 then level_three
      when 4 then level_four
      when 5 then level_five
      end
    end

    def level_one
      criteria = [
        criterion(:logged_in, "Logged in to OurGruuv", true, "You're here."),
        criterion(:zero_actions, "Check-in clarity actions at zero", zero_clarity_actions?, "Complete clarity check-ins until no actions remain."),
        criterion(:published_ogo, "Published an OGO", published_ogo?, "Share kudos, feedback, or another observation.")
      ]
      Level.new(
        level: 1,
        title: "Get unstuck in OG",
        audience: :everyone,
        complete: criteria.all?(&:done),
        criteria: criteria,
        marketing_why: why_for(criteria, "showing up, clearing their check-in load, and starting continuous feedback"),
        placeholder: false
      )
    end

    def level_two
      criteria = [
        criterion(:real_milestone, "Earned a real Ability Milestone", real_job_milestone?, "Have a manager certify a milestone on a company Ability."),
        criterion(:added_goal, "Added a goal", has_goal?, "Create a goal you can check confidence on weekly."),
        criterion(:confidence_checks, "At least 2 goal confidence checks", confidence_check_count >= 2, "Log confidence on your goals over multiple weeks."),
        criterion(:notifications, "GSD, Interesting Things, and Weekly digests on", all_three_notifications?, "Turn on all three on your Notifications page.")
      ]
      Level.new(
        level: 2,
        title: "Make OG a habit",
        audience: :everyone,
        complete: criteria.all?(&:done),
        criteria: criteria,
        marketing_why: why_for(criteria, "owning growth signals, goals, and staying plugged into weekly rhythm"),
        placeholder: false
      )
    end

    def level_three
      criteria = [
        criterion(:manager_check_in, "Completed a check-in as a manager", manager_check_in_done?, "Complete the manager side of a report's clarity check-in."),
        criterion(:completed_goal, "Completed a goal", completed_goal?, "Mark a goal complete when the work is done."),
        criterion(:maap_comment, "Helped improve MAAP with a comment", maap_comment?, "Comment on a Position, Assignment, Ability, or Value."),
        criterion(:observe_three, "Observed 3 different teammates", observed_teammate_count >= 3, "Publish OGOs for three distinct people."),
        criterion(:four_ratings, "Used each of the four OGO ratings", four_ratings_published?, "Publish with Exceptional, Strong, Mis-aligned, and Concerning.")
      ]
      Level.new(
        level: 3,
        title: "Lead with clarity (managers)",
        audience: :manager,
        complete: criteria.all?(&:done),
        criteria: criteria,
        marketing_why: why_for(criteria, "leading others through check-ins, goals, MAAP improvement, and richer observations"),
        placeholder: false
      )
    end

    def level_four
      criteria = [
        criterion(
          :maap_edits,
          "Created or edited 2+ MAAP object types (seat, position, assignment, ability, or value)",
          maap_object_types_touched >= 2,
          "Author or update at least two different MAAP building blocks."
        )
      ]
      Level.new(
        level: 4,
        title: "Shape the operating system (admins)",
        audience: :admin,
        complete: criteria.all?(&:done),
        criteria: criteria,
        marketing_why: why_for(criteria, "stewarding the company's MAAP definitions"),
        placeholder: false
      )
    end

    def level_five
      Level.new(
        level: 5,
        title: "Cross-company adoption (coming soon)",
        audience: :future,
        complete: false,
        criteria: [
          criterion(
            :cross_company,
            "Publish a Position, Assignment, or Ability adopted by another company",
            false,
            "Not available yet — placeholder for industry-level sharing."
          )
        ],
        marketing_why: nil,
        placeholder: true
      )
    end

    def criterion(key, label, done, hint)
      Criterion.new(key: key, label: label, done: done, hint: hint)
    end

    def why_for(criteria, marketing_words)
      done_labels = criteria.select(&:done).map(&:label)
      casual = @person.casual_name.presence || "This teammate"
      if done_labels.empty?
        "#{casual} is working toward this OG Academy level — a demonstration of #{marketing_words}."
      else
        "#{casual} completed #{done_labels.to_sentence} — a demonstration of #{marketing_words}."
      end
    end

    def zero_clarity_actions?
      stats = EngagementHealth::ClarityActionMetrics.spotlight_stats(
        organization: @organization,
        teammate_ids: [@company_teammate.id]
      )
      stats.actions_to_full_maap.to_i.zero?
    end

    def published_ogo?
      Observation.by_observer(@person).for_company(@organization).published.not_soft_deleted.exists?
    end

    def real_job_milestone?
      TeammateMilestone.where(teammate_id: @company_teammate.id).exists?
    end

    def has_goal?
      Goal.where(company: @organization)
          .where("creator_id = :tid OR (owner_type = 'CompanyTeammate' AND owner_id = :tid)", tid: @company_teammate.id)
          .exists?
    end

    def confidence_check_count
      GoalCheckIn
        .joins(:goal)
        .where(goals: { company_id: @organization.id })
        .where(confidence_reporter_id: @person.id)
        .count
    end

    def all_three_notifications?
      prefs = UserPreference.for_person(@person)
      weekly_day = prefs.preference(:about_me_weekly_day).to_s
      weekly_day_ok = weekly_day.match?(/\A[0-6]\z/)
      weekly_content = prefs.weekly_digest_enabled?(:about_me_digest_enabled) ||
                       prefs.weekly_digest_enabled?(:one_on_one_digest_enabled)
      prefs.gsd_digest_enabled? &&
        prefs.interesting_things_digest_enabled? &&
        weekly_day_ok &&
        weekly_content
    end

    def manager_check_in_done?
      return true if AssignmentCheckIn.where(manager_completed_by_teammate_id: @company_teammate.id).where.not(manager_completed_at: nil).exists?
      return true if PositionCheckIn.where(manager_completed_by_teammate_id: @company_teammate.id).where.not(manager_completed_at: nil).exists?
      return true if AspirationCheckIn.where(manager_completed_by_teammate_id: @company_teammate.id).where.not(manager_completed_at: nil).exists?

      false
    end

    def completed_goal?
      Goal.where(company: @organization)
          .where("creator_id = :tid OR (owner_type = 'CompanyTeammate' AND owner_id = :tid)", tid: @company_teammate.id)
          .where.not(completed_at: nil)
          .exists?
    end

    def maap_comment?
      Comment.where(organization: @organization, creator: @person)
             .where(commentable_type: MAAP_COMMENTABLE_TYPES)
             .exists?
    end

    def observed_teammate_count
      Observation.by_observer(@person)
                 .for_company(@organization)
                 .published
                 .not_soft_deleted
                 .joins(:observees)
                 .distinct
                 .count("observees.teammate_id")
    end

    def four_ratings_published?
      ratings = ObservationRating
                .joins(:observation)
                .where(observations: {
                  observer_id: @person.id,
                  company_id: @organization.id
                })
                .merge(Observation.published.not_soft_deleted)
                .where(rating: RATING_FOUR)
                .distinct
                .pluck(:rating)
                .map(&:to_s)
      (RATING_FOUR - ratings).empty?
    end

    def maap_object_types_touched
      types = PaperTrail::Version
              .where(whodunnit: @company_teammate.id.to_s, item_type: MAAP_VERSION_TYPES)
              .where(event: %w[create update])
              .distinct
              .pluck(:item_type)

      # Ability also has explicit author columns when PaperTrail was not active.
      if Ability.where(company: @organization).where("created_by_id = :pid OR updated_by_id = :pid", pid: @person.id).exists?
        types |= ["Ability"]
      end

      types.size
    end
  end
end
