# frozen_string_literal: true

module OgAcademy
  # Computes demo (pedagogical) OG Academy milestone progress from product usage.
  # Never creates Ability or TeammateMilestone records.
  class ProgressService
    LEVELS = (1..5).to_a.freeze
    RATING_FOUR = %w[strongly_agree agree disagree strongly_disagree].freeze
    MAAP_VERSION_TYPES = %w[Position Assignment Ability Aspiration Seat].freeze
    MAAP_COMMENTABLE_TYPES = %w[Position Assignment Ability Aspiration].freeze
    EMPLOYMENT_VERSION_TYPES = %w[Seat EmploymentTenure].freeze
    CHECK_IN_KLASSES = [AssignmentCheckIn, PositionCheckIn, AspirationCheckIn].freeze
    # Paths under /organizations/:id/… that count as the Insights suite (namespace pages).
    INSIGHT_PATH_SEGMENTS = %w[
      insights
      insights/og_scorecard
      insights/real_og_leaders
      insights/who_is_doing_what
      insights/observations
      insights/feedback_requests
      insights/og_consultations
      insights/seats_titles_positions
      insights/assignments
      insights/abilities
      insights/goals
      insights/prompts
      insights/check_ins_progress
    ].freeze
    OTHER_TEAMMATE_INTERNALS_REQUIRED = 5
    # M1–M3 are for everyone; M4+ (admin / cross-company) stay behind the advanced fold.
    ADVANCED_FROM_LEVEL = 4

    WHY = {
      logged_in: "Showing up is the first habit — Academy can celebrate progress the moment you arrive.",
      check_in_types: "Clarity starts when you’ve practiced each check-in type on your side of the conversation.",
      published_ogo: "Continuous feedback only works if you publish observations into the shared record.",
      added_goal: "A goal gives weekly confidence checks somewhere concrete to land.",
      real_milestone: "Job Ability milestones are the real ceremony you’re practicing toward with OG Mastery.",
      confidence_checks: "Confidence over time is how goals stay alive instead of becoming set-and-forget.",
      notifications: "Digests keep clarity and growth in your weekly rhythm without hunting for them.",
      check_in_depth: "Repeating all three check-in types builds fluency as employee or manager.",
      visited_my_growth: "My Growth is where experiences, abilities, and goals come together for development.",
      visited_my_one_thing: "My One Thing is the weekly focus for you and your manager — visiting it starts that rhythm.",
      visited_teammates_index: "The teammates directory is how you find people to support across the company.",
      visited_teammate_internals: "Spending time on other teammates’ internal pages builds context before you coach or observe.",
      linked_goals: "Connecting goals to Assignments and Abilities ties outcomes to the operating system.",
      observe_three: "Observing different people builds a broader, fairer sense of what’s on display.",
      four_ratings: "Using the full rating range means you can celebrate and course-correct with honesty.",
      maap_comment: "Improving MAAP definitions is how the company stays clear for everyone who follows.",
      maap_edits: "Editing MAAP objects is stewardship of the company’s shared language of work.",
      employment_stewardship: "Seats and tenures are how structure and people stay aligned over time.",
      visited_insights_and_billing: "Insights and Value/Billing show whether the operating system is creating clarity and value."
    }.freeze

    Criterion = Struct.new(
      :key, :label, :done, :hint, :seal, :what, :why_important, :attained_at,
      keyword_init: true
    )
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
      !admin_track?
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
        criterion(
          :logged_in,
          "Logged in to OurGruuv",
          true,
          "You're here.",
          "Logged in",
          what: "Opened OurGruuv and landed in OG Academy.",
          attained_at: Time.current
        ),
        criterion(
          :check_in_types,
          "Completed employee check-ins for Values, Assignments, and Position",
          employee_check_in_types_done?,
          "Finish at least one Values (aspiration), Assignment, and Position check-in on your side.",
          "Check-ins",
          what: "Finished employee-side Values, Assignment, and Position check-ins.",
          attained_at: employee_check_in_types_attained_at
        ),
        criterion(
          :published_ogo,
          "Published an OGO",
          published_ogo?,
          "Share kudos, feedback, or another observation.",
          "OGO",
          what: "Published an observation (OGO) in this company.",
          attained_at: first_published_ogo_at
        ),
        criterion(
          :added_goal,
          "Added a goal",
          has_goal?,
          "Create a goal you can check confidence on weekly.",
          "Goal",
          what: "Created or own a goal in this company.",
          attained_at: first_goal_at
        )
      ]
      Level.new(
        level: 1,
        title: "Get unstuck in OG",
        audience: :everyone,
        complete: criteria.all?(&:done),
        criteria: criteria,
        marketing_why: why_for(criteria, "showing up, clearing first check-ins, starting continuous feedback, and owning a goal"),
        placeholder: false
      )
    end

    def level_two
      criteria = [
        criterion(
          :real_milestone,
          "Earned a real Ability Milestone",
          real_job_milestone?,
          "Have a manager certify a milestone on a company Ability.",
          "Milestone",
          what: "A manager certified a milestone on a company Ability.",
          attained_at: first_teammate_milestone_at
        ),
        criterion(
          :confidence_checks,
          "At least 2 goal confidence checks",
          confidence_check_count >= 2,
          "Log confidence on your goals over multiple weeks.",
          "Confidence",
          what: "Logged at least two goal confidence checks.",
          attained_at: second_confidence_check_at
        ),
        criterion(
          :notifications,
          "GSD, Interesting Things, and Weekly digests on",
          all_three_notifications?,
          "Turn on all three on your Notifications page.",
          "Digests",
          what: "Enabled GSD, Interesting Things, and Weekly digests.",
          attained_at: nil
        ),
        criterion(
          :visited_my_growth,
          "Visited My Growth",
          visited_my_growth?,
          "Open My Growth · Abilities, Experiences, or Goals.",
          "My Growth",
          what: "Visited a My Growth page (Abilities, Experiences, or Goals).",
          attained_at: first_my_growth_visit_at
        ),
        criterion(
          :visited_my_one_thing,
          "Visited My One Thing",
          visited_my_one_thing?,
          "Open your One Thing (1:1) hub.",
          "One Thing",
          what: "Visited My One Thing.",
          attained_at: first_my_one_thing_visit_at
        )
      ]
      Level.new(
        level: 2,
        title: "Make OG a habit",
        audience: :everyone,
        complete: criteria.all?(&:done),
        criteria: criteria,
        marketing_why: why_for(criteria, "owning growth signals, weekly confidence, digests, and visiting My Growth and One Thing"),
        placeholder: false
      )
    end

    def level_three
      criteria = [
        criterion(
          :check_in_depth,
          "Participated in 2 completed check-ins of each type (Values, Assignments, Position)",
          check_in_depth_done?,
          "As employee or manager, take part in two officially completed check-ins for each of the three types.",
          "Check-in depth",
          what: "Participated in two officially completed check-ins for each type.",
          attained_at: check_in_depth_attained_at
        ),
        criterion(
          :visited_teammates_index,
          "Visited the teammates directory",
          visited_teammates_index?,
          "Open the teammates / employees index for your company.",
          "Teammates index",
          what: "Visited the company teammates directory.",
          attained_at: first_teammates_index_visit_at
        ),
        criterion(
          :visited_teammate_internals,
          "Visited at least 5 other teammates' internal pages",
          visited_other_teammate_internals_count >= OTHER_TEAMMATE_INTERNALS_REQUIRED,
          "Open the Internal page for five different teammates (not yourself).",
          "5 internals",
          what: "Visited Internal pages for at least 5 other teammates.",
          attained_at: fifth_other_teammate_internal_visit_at
        ),
        criterion(
          :linked_goals,
          "Connected a goal to an Assignment and a goal to an Ability",
          linked_assignment_and_ability_goals?,
          "Link one of your goals to an Assignment and one to an Ability.",
          "Linked goals",
          what: "Linked goals to both an Assignment and an Ability.",
          attained_at: linked_goals_attained_at
        ),
        criterion(
          :observe_three,
          "Observed 3 different teammates",
          observed_teammate_count >= 3,
          "Publish OGOs for three distinct people.",
          "Observe 3",
          what: "Published OGOs about three different teammates.",
          attained_at: third_observee_ogo_at
        ),
        criterion(
          :four_ratings,
          "Used each of the four OGO ratings",
          four_ratings_published?,
          "Publish with Exceptional, Strong, Mis-aligned, and Concerning.",
          "Four ratings",
          what: "Used Exceptional, Strong, Mis-aligned, and Concerning ratings on published OGOs.",
          attained_at: four_ratings_attained_at
        ),
        criterion(
          :maap_comment,
          "Helped improve MAAP with a comment",
          maap_comment?,
          "Comment on a Position, Assignment, Ability, or Value.",
          "MAAP comment",
          what: "Commented on a Position, Assignment, Ability, or Value.",
          attained_at: first_maap_comment_at
        )
      ]
      Level.new(
        level: 3,
        title: "Lead with clarity",
        audience: :everyone,
        complete: criteria.all?(&:done),
        criteria: criteria,
        marketing_why: why_for(criteria, "deepening check-ins, knowing teammates, linking goals to MAAP, richer observations, and improving definitions"),
        placeholder: false
      )
    end

    def level_four
      criteria = [
        criterion(
          :maap_edits,
          "Created or edited 2+ MAAP object types (seat, position, assignment, ability, or value)",
          maap_object_types_touched >= 2,
          "Author or update at least two different MAAP building blocks.",
          "MAAP edits",
          what: "Created or updated at least two different MAAP object types.",
          attained_at: second_maap_type_touched_at
        ),
        criterion(
          :employment_stewardship,
          "Managed a Seat or Employment Tenure",
          employment_stewardship_done?,
          "Create or update a Seat or Employment Tenure (hire, seat change, or open/fill a seat).",
          "Seats & employment",
          what: "Created or updated a Seat or Employment Tenure (or logged a hire/seat-change moment).",
          attained_at: employment_stewardship_attained_at
        ),
        criterion(
          :visited_insights_and_billing,
          "Visited all Insights pages and Value / Billing",
          visited_insights_and_billing?,
          "Open every page under Insights, plus Value / Billing.",
          "Insights & billing",
          what: "Visited all Insights suite pages and Value / Billing.",
          attained_at: insights_and_billing_attained_at
        )
      ]
      Level.new(
        level: 4,
        title: "Shape the operating system",
        audience: :admin,
        complete: criteria.all?(&:done),
        criteria: criteria,
        marketing_why: why_for(criteria, "stewarding MAAP, employment structure, and company insight"),
        placeholder: false
      )
    end

    def level_five
      global_repo_hint = "When the global MAAP repository ships, we'll check this automatically if other organizations adopt your published work. Until then this stays open."
      criteria = [
        criterion(
          :published_position_other_orgs,
          "Published a Position that is in use by other organizations",
          false,
          global_repo_hint,
          "Position"
        ),
        criterion(
          :published_assignment_other_orgs,
          "Published an Assignment that is in use by other organizations",
          false,
          global_repo_hint,
          "Assignment"
        ),
        criterion(
          :published_ability_other_orgs,
          "Published an Ability that is in use by other organizations",
          false,
          global_repo_hint,
          "Ability"
        )
      ]
      Level.new(
        level: 5,
        title: "Cross-company adoption",
        audience: :future,
        complete: false,
        criteria: criteria,
        marketing_why: why_for(criteria, "contributing MAAP pieces that scale beyond one company"),
        placeholder: false
      )
    end

    def criterion(key, label, done, hint, seal = nil, what: nil, attained_at: nil)
      Criterion.new(
        key: key,
        label: label,
        done: done,
        hint: hint,
        seal: seal.presence || label,
        what: done ? what : nil,
        why_important: done ? WHY[key] : nil,
        attained_at: done ? attained_at : nil
      )
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

    def employee_check_in_types_done?
      tid = @company_teammate.id
      AssignmentCheckIn.where(teammate_id: tid).employee_completed.exists? &&
        PositionCheckIn.where(teammate_id: tid).employee_completed.exists? &&
        AspirationCheckIn.where(teammate_id: tid).employee_completed.exists?
    end

    def employee_check_in_types_attained_at
      return nil unless employee_check_in_types_done?

      tid = @company_teammate.id
      dates = [
        AssignmentCheckIn.where(teammate_id: tid).employee_completed.minimum(:employee_completed_at),
        PositionCheckIn.where(teammate_id: tid).employee_completed.minimum(:employee_completed_at),
        AspirationCheckIn.where(teammate_id: tid).employee_completed.minimum(:employee_completed_at)
      ]
      dates.compact.max
    end

    def check_in_depth_done?
      CHECK_IN_KLASSES.all? { |klass| participated_closed_check_in_count(klass) >= 2 }
    end

    def check_in_depth_attained_at
      return nil unless check_in_depth_done?

      CHECK_IN_KLASSES.map { |klass| second_participated_closed_at(klass) }.compact.max
    end

    def participated_closed_check_in_count(klass)
      participated_closed_scope(klass).count
    end

    def participated_closed_scope(klass)
      tid = @company_teammate.id
      klass.closed.where(
        "teammate_id = :tid OR manager_completed_by_teammate_id = :tid OR finalized_by_teammate_id = :tid",
        tid: tid
      )
    end

    def second_participated_closed_at(klass)
      participated_closed_scope(klass).order(:official_check_in_completed_at).offset(1).limit(1).pick(:official_check_in_completed_at)
    end

    def published_ogo?
      Observation.by_observer(@person).for_company(@organization).published.not_soft_deleted.exists?
    end

    def first_published_ogo_at
      Observation.by_observer(@person).for_company(@organization).published.not_soft_deleted.minimum(:published_at)
    end

    def real_job_milestone?
      TeammateMilestone.where(teammate_id: @company_teammate.id).exists?
    end

    def first_teammate_milestone_at
      TeammateMilestone.where(teammate_id: @company_teammate.id).minimum(:attained_at)
    end

    def has_goal?
      goals_scope.exists?
    end

    def goals_scope
      Goal.where(company: @organization)
          .where("creator_id = :tid OR (owner_type = 'CompanyTeammate' AND owner_id = :tid)", tid: @company_teammate.id)
    end

    def first_goal_at
      goals_scope.minimum(:created_at)
    end

    def confidence_check_count
      confidence_checks_scope.count
    end

    def confidence_checks_scope
      GoalCheckIn
        .joins(:goal)
        .where(goals: { company_id: @organization.id })
        .where(confidence_reporter_id: @person.id)
    end

    def second_confidence_check_at
      confidence_checks_scope.order(:created_at).offset(1).limit(1).pick(:created_at)
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

    def visited_my_growth?
      my_growth_visits_scope.exists?
    end

    def my_growth_visits_scope
      prefix = "/organizations/#{@organization.id}/company_teammates/#{@company_teammate.id}/my_growth"
      PageVisit.where(person_id: @person.id).where("url LIKE ?", "#{prefix}%")
    end

    def first_my_growth_visit_at
      my_growth_visits_scope.minimum(:visited_at)
    end

    def visited_my_one_thing?
      my_one_thing_visits_scope.exists?
    end

    def my_one_thing_visits_scope
      prefix = "/organizations/#{@organization.id}/company_teammates/#{@company_teammate.id}/one_on_one_link"
      PageVisit.where(person_id: @person.id).where("url = :exact OR url LIKE :prefix OR url LIKE :with_query",
                                                   exact: prefix,
                                                   prefix: "#{prefix}/%",
                                                   with_query: "#{prefix}?%")
    end

    def first_my_one_thing_visit_at
      my_one_thing_visits_scope.minimum(:visited_at)
    end

    def visited_teammates_index?
      teammates_index_visits_scope.exists?
    end

    def teammates_index_visits_scope
      path = "/organizations/#{@organization.id}/employees"
      page_visits_for_exact_path(path)
    end

    def first_teammates_index_visit_at
      teammates_index_visits_scope.minimum(:visited_at)
    end

    def visited_other_teammate_internals_count
      other_teammate_internal_visit_ids.size
    end

    def other_teammate_internal_visit_ids
      @other_teammate_internal_visit_ids ||= begin
        prefix = "/organizations/#{@organization.id}/company_teammates/"
        PageVisit.where(person_id: @person.id)
                 .where("url LIKE ?", "#{prefix}%/internal%")
                 .pluck(:url)
                 .filter_map do |url|
                   path = url.to_s.split("?", 2).first
                   match = path.match(%r{\A/organizations/\d+/company_teammates/(\d+)/internal\z})
                   next unless match

                   id = match[1].to_i
                   id unless id == @company_teammate.id
                 end
                 .uniq
      end
    end

    def fifth_other_teammate_internal_visit_at
      return nil if visited_other_teammate_internals_count < OTHER_TEAMMATE_INTERNALS_REQUIRED

      prefix = "/organizations/#{@organization.id}/company_teammates/"
      seen = []
      PageVisit.where(person_id: @person.id)
               .where("url LIKE ?", "#{prefix}%/internal%")
               .order(:visited_at)
               .pluck(:url, :visited_at)
               .each do |url, visited_at|
        path = url.to_s.split("?", 2).first
        match = path.match(%r{\A/organizations/\d+/company_teammates/(\d+)/internal\z})
        next unless match

        id = match[1].to_i
        next if id == @company_teammate.id || seen.include?(id)

        seen << id
        return visited_at if seen.size == OTHER_TEAMMATE_INTERNALS_REQUIRED
      end
      nil
    end

    def visited_insights_and_billing?
      required_insight_and_billing_paths.all? { |path| page_visited_exact?(path) }
    end

    def required_insight_and_billing_paths
      oid = @organization.id
      INSIGHT_PATH_SEGMENTS.map { |segment| "/organizations/#{oid}/#{segment}" } +
        ["/organizations/#{oid}/value_billing"]
    end

    def insights_and_billing_attained_at
      return nil unless visited_insights_and_billing?

      required_insight_and_billing_paths.filter_map { |path| page_visits_for_exact_path(path).minimum(:visited_at) }.max
    end

    def page_visited_exact?(path)
      page_visits_for_exact_path(path).exists?
    end

    def page_visits_for_exact_path(path)
      PageVisit.where(person_id: @person.id).where("url = :path OR url LIKE :with_query", path: path, with_query: "#{path}?%")
    end

    def linked_assignment_and_ability_goals?
      goal_linked_to?("Assignment") && goal_linked_to?("Ability")
    end

    def goal_linked_to?(associable_type)
      goals_linked_scope(associable_type).exists?
    end

    def goals_linked_scope(associable_type)
      Goal.joins(:goal_associations)
          .where(company: @organization)
          .where(goal_associations: { associable_type: associable_type })
          .where("goals.creator_id = :tid OR (goals.owner_type = 'CompanyTeammate' AND goals.owner_id = :tid)", tid: @company_teammate.id)
    end

    def linked_goals_attained_at
      return nil unless linked_assignment_and_ability_goals?

      [
        goals_linked_scope("Assignment").minimum("goal_associations.created_at"),
        goals_linked_scope("Ability").minimum("goal_associations.created_at")
      ].compact.max
    end

    def maap_comment?
      maap_comments_scope.exists?
    end

    def maap_comments_scope
      Comment.where(organization: @organization, creator: @person)
             .where(commentable_type: MAAP_COMMENTABLE_TYPES)
    end

    def first_maap_comment_at
      maap_comments_scope.minimum(:created_at)
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

    def third_observee_ogo_at
      return nil if observed_teammate_count < 3

      seen = []
      Observation.by_observer(@person)
                 .for_company(@organization)
                 .published
                 .not_soft_deleted
                 .joins(:observees)
                 .order(Arel.sql("observations.published_at ASC NULLS LAST, observations.id ASC"))
                 .pluck("observations.published_at", "observees.teammate_id")
                 .each do |published_at, teammate_id|
        next if seen.include?(teammate_id)

        seen << teammate_id
        return published_at if seen.size == 3
      end
      nil
    end

    def four_ratings_published?
      published_rating_values.size == RATING_FOUR.size && (RATING_FOUR - published_rating_values).empty?
    end

    def published_rating_values
      @published_rating_values ||= ObservationRating
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
    end

    def four_ratings_attained_at
      return nil unless four_ratings_published?

      RATING_FOUR.map do |rating|
        ObservationRating
          .joins(:observation)
          .where(observations: { observer_id: @person.id, company_id: @organization.id })
          .merge(Observation.published.not_soft_deleted)
          .where(rating: rating)
          .minimum("observations.published_at")
      end.compact.max
    end

    def maap_object_types_touched
      maap_types_from_versions.size
    end

    def maap_types_from_versions
      types = PaperTrail::Version
              .where(whodunnit: @company_teammate.id.to_s, item_type: MAAP_VERSION_TYPES)
              .where(event: %w[create update])
              .distinct
              .pluck(:item_type)

      if Ability.where(company: @organization).where("created_by_id = :pid OR updated_by_id = :pid", pid: @person.id).exists?
        types |= ["Ability"]
      end
      types
    end

    def second_maap_type_touched_at
      return nil if maap_object_types_touched < 2

      PaperTrail::Version
        .where(whodunnit: @company_teammate.id.to_s, item_type: MAAP_VERSION_TYPES)
        .where(event: %w[create update])
        .order(:created_at)
        .each_with_object([]) do |version, seen|
          next if seen.include?(version.item_type)

          seen << version.item_type
          return version.created_at if seen.size == 2
        end
      Ability.where(company: @organization)
             .where("created_by_id = :pid OR updated_by_id = :pid", pid: @person.id)
             .minimum(:updated_at)
    end

    def employment_stewardship_done?
      employment_version_scope.exists? || employment_moment_scope.exists?
    end

    def employment_version_scope
      PaperTrail::Version
        .where(whodunnit: @company_teammate.id.to_s, item_type: EMPLOYMENT_VERSION_TYPES)
        .where(event: %w[create update])
    end

    def employment_moment_scope
      ObservableMoment.where(
        company: @organization,
        created_by: @person,
        moment_type: %w[new_hire seat_change]
      )
    end

    def employment_stewardship_attained_at
      [
        employment_version_scope.minimum(:created_at),
        employment_moment_scope.minimum(:occurred_at) || employment_moment_scope.minimum(:created_at)
      ].compact.min
    end
  end
end
