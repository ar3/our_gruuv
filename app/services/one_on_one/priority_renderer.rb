# frozen_string_literal: true

module OneOnOne
  # Renders priority-card content (reason text and item lines) from the structured data
  # produced by OneOnOne::PriorityCarouselBuilder.
  #
  # Two parallel renderers live here so the carousel partial and the Slack digest
  # share a single source of truth for copy and link targets:
  #
  #   - `reason_html` / `item_html` produce HTML SafeBuffers for the view layer.
  #   - `reason_plain` / `item_plain` produce plain text for Slack (and future renderers).
  #
  # `data_kind:` is nil for priorities that have not been migrated to the data-first
  # contract yet; those still rely on `priority[:reason]` and the legacy
  # `priority[:concrete_items]` shape (strings or `{ label:, url:, add_goal_* }` hashes).
  class PriorityRenderer
    include Rails.application.routes.url_helpers

    RATEABLE_TYPE_RANK = { "Assignment" => 0, "Aspiration" => 1, "Ability" => 2 }.freeze

    attr_reader :priority, :organization, :teammate

    def initialize(priority:, organization:, teammate:)
      @priority = priority
      @organization = organization
      @teammate = teammate
    end

    def reason_html
      case priority[:data_kind]
      when :observation_given_success
        observation_given_success_reason_html
      when :wtm_received_success
        wtm_received_success_reason_html
      when :no_active_goals_success
        no_active_goals_success_reason_html
      end
    end

    def reason_lines
      case priority[:data_kind]
      when :wtm_all_clear_success
        wtm_all_clear_success_reason_lines
      else
        []
      end
    end

    def reason_plain
      case priority[:data_kind]
      when :observation_given_success
        observation_given_success_reason_plain
      when :observation_received_success
        observation_received_success_reason_plain
      when :wtm_received_success
        wtm_received_success_reason_plain
      when :no_active_goals_success
        no_active_goals_success_reason_plain
      when :wtm_all_clear_success
        reason_lines.join(" ")
      end
    end

    def items
      Array(priority[:items])
    end

    # :html -> use item_html, :link -> use item_label_url, else nil (legacy concrete_items path)
    def items_render_mode
      case priority[:data_kind]
      when :observation_received_success, :wtm_received_success
        :html
      when :blurred_or_obscured_attention,
           :wtm_with_goals_success,
           :wtm_gap_without_goals_attention,
           :milestone_gap_attention,
           :wtm_missing_observation_attention,
           :stale_goals_attention,
           :asana_tasks_attention
        :link
      end
    end

    def item_html(item)
      case priority[:data_kind]
      when :observation_received_success
        observation_received_item_html(item)
      when :wtm_received_success
        wtm_received_item_html(item)
      end
    end

    def item_label_url(item)
      case priority[:data_kind]
      when :blurred_or_obscured_attention
        blurred_or_obscured_item_label_url(item)
      when :wtm_with_goals_success
        wtm_with_goals_item_label_url(item)
      when :wtm_gap_without_goals_attention
        wtm_gap_without_goals_item_label_url(item)
      when :milestone_gap_attention
        milestone_gap_item_label_url(item)
      when :wtm_missing_observation_attention
        wtm_missing_observation_item_label_url(item)
      when :stale_goals_attention
        stale_goal_item_label_url(item)
      when :asana_tasks_attention
        asana_task_item_label_url(item)
      end
    end

    def item_plain(item)
      case priority[:data_kind]
      when :observation_received_success
        observation_received_item_plain(item)
      when :wtm_received_success
        wtm_received_item_plain(item)
      else
        attrs = item_label_url(item)
        case attrs
        when Hash then attrs[:label]
        when String then attrs
        end
      end
    end

    private

    def h
      ActionController::Base.helpers
    end

    def casual_name
      teammate.person.casual_name
    end

    # ---------- Priority 5: observation given (success) ----------

    def observation_given_success_reason_html
      data = priority[:data] || {}
      given_count = data[:given_count].to_i
      observees = Array(data[:observees])
      rateables = sort_rateables(Array(data[:rateables]))

      casual_link = h.link_to(casual_name, ogos_involving_me_path(teammate))
      observee_links = observees.map { |tm| h.link_to(tm.person.casual_name, internal_teammate_path(tm)) }
      rateable_links = rateables.map { |r| h.link_to(rateable_label(r), rateable_path(r)) }

      ogos_phrase = h.pluralize(given_count, "published OGO")
      observees_fragment = join_html_sentence(observee_links)
      rateables_fragment = join_html_sentence(rateable_links)

      casual_link +
        " has given #{ogos_phrase}, to ".html_safe +
        observees_fragment +
        (rateable_links.any? ? ", about ".html_safe + rateables_fragment : "".html_safe) +
        " in the last 30 days!!".html_safe
    end

    def observation_given_success_reason_plain
      data = priority[:data] || {}
      given_count = data[:given_count].to_i
      observees = Array(data[:observees])
      rateables = sort_rateables(Array(data[:rateables]))

      ogos_phrase = h.pluralize(given_count, "published OGO")
      observee_names = observees.map { |tm| tm.person.casual_name }
      rateable_names = rateables.map { |r| rateable_label(r) }

      line = +"#{casual_name} has given #{ogos_phrase}, to #{observee_names.to_sentence}"
      line << ", about #{rateable_names.to_sentence}" if rateable_names.any?
      line << " in the last 30 days!!"
      line
    end

    # ---------- Priority 6: observation received (success) ----------
    # `reason` is already a plain string set by the service; we only render items.

    def observation_received_success_reason_plain
      priority[:reason].to_s.presence
    end

    def observation_received_item_html(item)
      observation = item[:observation]
      observer_teammate = item[:observer_teammate]
      rateables = sort_rateables(Array(item[:rateables]))
      observation_org = observation.company

      observer_fragment =
        if observer_teammate
          involving_href = organization_observations_path(observation_org, involving_teammate_id: observer_teammate.id)
          h.link_to(observation.observer.casual_name, involving_href)
        else
          ERB::Util.html_escape(observation.observer.casual_name)
        end

      date_link = h.link_to(observation_date_label(observation), organization_observation_path(observation_org, observation))

      about_suffix =
        if rateables.any?
          links = rateables.map { |r| h.link_to(rateable_label(r), rateable_path_for_org(observation_org, r)) }
          " about: ".html_safe + join_html_sentence(links)
        else
          "".html_safe
        end

      observer_fragment + " on ".html_safe + date_link + about_suffix
    end

    def observation_received_item_plain(item)
      observation = item[:observation]
      rateables = sort_rateables(Array(item[:rateables]))
      observer_name = observation.observer.casual_name
      date_label = observation_date_label(observation)
      rateable_names = rateables.map { |r| rateable_label(r) }

      line = +"#{observer_name} on #{date_label}"
      line << " about: #{rateable_names.to_sentence}" if rateable_names.any?
      line
    end

    # ---------- Priority 7: WTM observations received (success) ----------

    def wtm_received_success_reason_html
      data = priority[:data] || {}
      x = data[:x].to_i
      y = data[:y].to_i
      lead =
        if x == 1
          "1 Working-to-meet assignment/aspiration area has #{y} recent published "
        else
          "#{x} Working-to-meet assignment/aspiration areas have #{y} recent published "
        end
      lead.html_safe + h.link_to("observations", ogos_involving_me_path(teammate)) + ".".html_safe
    end

    def wtm_received_success_reason_plain
      data = priority[:data] || {}
      x = data[:x].to_i
      y = data[:y].to_i
      if x == 1
        "1 Working-to-meet assignment/aspiration area has #{y} recent published observations."
      else
        "#{x} Working-to-meet assignment/aspiration areas have #{y} recent published observations."
      end
    end

    def wtm_received_item_html(item)
      associable = item[:associable]
      observers = Array(item[:observers_with_observations])
      name_fragment = wtm_area_name_fragment(associable)
      return name_fragment if observers.blank?

      observer_segments = observers.filter_map do |entry|
        person = entry[:person]
        next if person.blank?

        ordered = Array(entry[:observations]).sort_by(&:observed_at)
        number_links = ordered.each_with_index.map do |obs, idx|
          h.link_to("[#{idx + 1}]", organization_observation_path(obs.company, obs))
        end
        ERB::Util.html_escape("#{person.casual_name} ") + h.safe_join(number_links, ", ".html_safe)
      end

      name_fragment + " — ".html_safe + h.safe_join(observer_segments, "; ".html_safe)
    end

    def wtm_received_item_plain(item)
      associable = item[:associable]
      observers = Array(item[:observers_with_observations])
      name_label =
        case associable
        when Assignment then "Assignment: #{associable.title}"
        when Aspiration then "Aspiration: #{associable.name}"
        else ""
        end
      return name_label if observers.blank?

      observer_strs = observers.filter_map do |entry|
        person = entry[:person]
        next if person.blank?

        count = Array(entry[:observations]).size
        "#{person.casual_name} (#{count})"
      end
      "#{name_label} — #{observer_strs.join('; ')}"
    end

    def wtm_area_name_fragment(associable)
      case associable
      when Assignment
        "Assignment: ".html_safe + h.link_to(associable.title, organization_teammate_assignment_path(organization, teammate, associable))
      when Aspiration
        "Aspiration: ".html_safe + h.link_to(associable.name, organization_teammate_aspiration_path(organization, teammate, associable))
      else
        "".html_safe
      end
    end

    # ---------- Priority 9: no active goals (success) ----------

    def no_active_goals_success_reason_html
      count = (priority[:data] || {})[:active_goal_count].to_i
      link_label = count == 1 ? "1 active goal" : "#{count} active goals"
      lead = count == 1 ? "There is ".html_safe : "There are ".html_safe
      lead + h.link_to(link_label, my_growth_goals_organization_company_teammate_path(organization, teammate)) + " in progress.".html_safe
    end

    def no_active_goals_success_reason_plain
      count = (priority[:data] || {})[:active_goal_count].to_i
      count == 1 ? "There is 1 active goal in progress." : "There are #{count} active goals in progress."
    end

    # ---------- Priority 2: blurred/obscured (attention) ----------

    def blurred_or_obscured_item_label_url(item)
      prefix = blurred_or_obscured_kind_prefix(item[:kind])
      label = "#{prefix} #{item[:display_title]} (Last check-in: #{blurred_or_obscured_words(item[:finalized_at])})"
      { label: label, url: blurred_or_obscured_url(item) }
    end

    def blurred_or_obscured_kind_prefix(kind)
      case kind
      when :aspiration then "Aspiration:"
      when :assignment then "Assignment:"
      when :position then "Position:"
      else "Check-in:"
      end
    end

    def blurred_or_obscured_words(completed_at)
      return "never" if completed_at.blank?

      "#{h.time_ago_in_words(completed_at)} ago"
    end

    def blurred_or_obscured_url(item)
      case item[:kind]
      when :aspiration
        organization_teammate_aspiration_path(organization, teammate, item[:record_id])
      when :assignment
        organization_teammate_assignment_path(organization, teammate, item[:record_id])
      when :position
        position_check_in_organization_teammate_path(organization, teammate)
      end
    end

    # ---------- Priority 3: WTM with active goals (success) ----------

    def wtm_with_goals_item_label_url(item)
      associable = item[:associable]
      goal_phrase = h.pluralize(item[:active_goal_count].to_i, "active goal")
      label =
        case associable
        when Assignment then "Assignment: #{associable.title} (#{goal_phrase})"
        when Aspiration then "Aspiration: #{associable.name} (#{goal_phrase})"
        else raise ArgumentError, "Unsupported associable for WTM with goals item: #{associable.class.name}"
        end
      url =
        case associable
        when Assignment then organization_teammate_assignment_path(organization, teammate, associable)
        when Aspiration then organization_teammate_aspiration_path(organization, teammate, associable)
        end
      { label: label, url: url }
    end

    # ---------- Priority 3: WTM all clear (success) ----------

    def wtm_all_clear_success_reason_lines
      data = priority[:data] || {}
      x = data[:x].to_i
      y = data[:y].to_i
      assignments_missing = data[:assignments_missing].to_i
      aspirations_missing = data[:aspirations_missing].to_i

      expectations_line =
        "#{casual_name} is meeting or exceeding expectations for " \
        "#{h.pluralize(x, 'required and active assignment')} and #{h.pluralize(y, 'aspirational value')}."

      check_ins_line =
        if assignments_missing.zero? && aspirations_missing.zero?
          "#{casual_name} has had all relevant check-ins."
        elsif assignments_missing.positive? && aspirations_missing.positive?
          "#{casual_name} has not had a check-in on " \
            "#{h.pluralize(assignments_missing, 'required or active assignment')} and " \
            "#{h.pluralize(aspirations_missing, 'aspirational value')}."
        elsif assignments_missing.positive?
          "#{casual_name} has not had a check-in on #{h.pluralize(assignments_missing, 'required or active assignment')}."
        else
          "#{casual_name} has not had a check-in on #{h.pluralize(aspirations_missing, 'aspirational value')}."
        end

      [expectations_line, check_ins_line]
    end

    # ---------- Priority 3 / 12: WTM gap without goals (attention) ----------

    def wtm_gap_without_goals_item_label_url(item)
      associable = item[:associable]
      label =
        case associable
        when Assignment then "Assignment: #{associable.title}"
        when Aspiration then "Aspiration: #{associable.name}"
        else raise ArgumentError, "Unsupported associable for WTM gap item: #{associable.class.name}"
        end
      lens_url =
        case associable
        when Assignment then organization_teammate_assignment_path(organization, teammate, associable)
        when Aspiration then organization_teammate_aspiration_path(organization, teammate, associable)
        end
      kind_phrase = associable.is_a?(Assignment) ? "assignment" : "aspirational value"
      add_goal_label = "Add goal for #{teammate_initials} + this #{kind_phrase}"
      add_goal_url =
        case associable
        when Assignment
          choose_manage_goals_organization_assignment_path(
            organization, associable,
            return_url: one_on_one_hub_return_path,
            return_text: "Back to 1:1 Hub",
            for_company_teammate_id: teammate.id
          )
        when Aspiration
          choose_manage_goals_organization_aspiration_path(
            organization, associable,
            return_url: one_on_one_hub_return_path,
            return_text: "Back to 1:1 Hub",
            for_company_teammate_id: teammate.id
          )
        end
      {
        label: label,
        url: lens_url,
        add_goal_label: add_goal_label,
        add_goal_url: add_goal_url
      }
    end

    # ---------- Priority 4 / 10: milestone gap without goals (attention) ----------

    def milestone_gap_item_label_url(item)
      ability = item[:ability]
      required = item[:required_level]
      earned = item[:earned_level]
      {
        label: "Ability: #{ability.name} (need M#{required}, earned M#{earned})",
        url: organization_teammate_ability_path(organization, teammate, ability),
        add_goal_label: "Add goal for #{teammate_initials} + this ability",
        add_goal_url: choose_manage_goals_organization_ability_path(
          organization, ability,
          return_url: one_on_one_hub_return_path,
          return_text: "Back to 1:1 Hub",
          for_company_teammate_id: teammate.id
        )
      }
    end

    # ---------- Priority 7: WTM missing observation (attention) ----------

    def wtm_missing_observation_item_label_url(item)
      case item[:kind]
      when :assignment
        record = item[:record]
        label = "Assignment: #{record&.title || "Assignment ##{item[:fallback_id]}"}"
        url = record.present? ? organization_teammate_assignment_path(organization, teammate, record) : nil
      when :aspiration
        record = item[:record]
        label = "Aspiration: #{record&.name || "Aspiration ##{item[:fallback_id]}"}"
        url = record.present? ? organization_teammate_aspiration_path(organization, teammate, record) : nil
      end
      url.present? ? { label: label, url: url } : label
    end

    # ---------- Priority 8: stale active goals (attention) ----------

    def stale_goal_item_label_url(item)
      goal = item[:goal]
      { label: goal.title, url: organization_goal_path(organization, goal) }
    end

    # ---------- Priority 1 / 11: Asana tasks (attention) ----------

    def asana_task_item_label_url(item)
      task = item[:task] || {}
      due_on = parse_asana_due(task["due_on"])
      due_label = due_on ? " (due #{due_on.strftime('%b %d')})" : ""
      label = "#{task["name"]}#{due_label}"
      gid = task["gid"].presence
      return label if gid.blank?

      { label: label, url: AsanaService.task_url(gid, item[:project_id]) }
    end

    def parse_asana_due(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def teammate_initials
      teammate.person.max_two_initials.presence || "?"
    end

    def one_on_one_hub_return_path
      organization_company_teammate_one_on_one_link_path(organization, teammate)
    end

    # ---------- shared helpers ----------

    def sort_rateables(rateables)
      sorted = rateables.uniq { |r| [r.class.name, r.id] }
      sorted.sort_by { |r| [RATEABLE_TYPE_RANK[r.class.name] || 99, rateable_sort_key(r)] }
    end

    def rateable_sort_key(rateable)
      case rateable
      when Assignment then rateable.title.to_s.downcase
      when Aspiration, Ability then rateable.name.to_s.downcase
      else ""
      end
    end

    def rateable_label(rateable)
      case rateable
      when Assignment then rateable.title.presence || "Assignment"
      when Aspiration then rateable.name.presence || "Aspiration"
      when Ability then rateable.name.presence || "Ability"
      else rateable.class.name
      end
    end

    def rateable_path(rateable)
      rateable_path_for_org(organization, rateable)
    end

    def rateable_path_for_org(org, rateable)
      case rateable
      when Assignment then organization_assignment_path(org, rateable)
      when Aspiration then organization_aspiration_path(org, rateable)
      when Ability then organization_ability_path(org, rateable)
      else raise ArgumentError, "Unsupported rateable: #{rateable.class.name}"
      end
    end

    def join_html_sentence(fragments)
      frags = fragments.compact
      return "".html_safe if frags.empty?

      case frags.size
      when 1
        frags.first
      when 2
        frags[0] + " and ".html_safe + frags[1]
      else
        h.safe_join(frags[0..-2], ", ".html_safe) + ", and ".html_safe + frags.last
      end
    end

    def observation_date_label(observation)
      observation.observed_at.to_date.strftime("%b %d")
    end

    def ogos_involving_me_path(tm)
      organization_observations_path(organization, involving_teammate_id: tm.id)
    end

    def internal_teammate_path(tm)
      internal_organization_company_teammate_path(organization, tm)
    end
  end
end
