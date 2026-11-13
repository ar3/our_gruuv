# frozen_string_literal: true

module ProtectFlow
  # Middle-column opportunity: one natural sentence with an inline action link.
  # Returns a hash: { before:, link_text:, link_path:, link_method:, after: }
  class OpportunitySentence
    include Rails.application.routes.url_helpers

    DATE_FORMAT = "%b %-d, %Y"

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(
      organization:,
      teammate:,
      viewer:,
      category:,
      short_title:,
      status:,
      role:,
      items: [],
      item_links: [],
      reference_date: Date.current
    )
      @organization = organization
      @teammate = teammate
      @viewer = viewer
      @category = category.to_s
      @short_title = short_title
      @status = status.to_s
      @role = role.to_sym
      @items = Array(items)
      @item_links = Array(item_links)
      @reference_date = reference_date
    end

    def call
      @role == :clear ? clear_sentence : attention_sentence
    end

    private

    def attention_sentence
      case @category
      when "pending_health"
        sentence(
          before: "Engagement Health has not been calculated yet — ",
          link_text: "open their One Thing",
          link_path: organization_company_teammate_one_on_one_link_path(@organization, @teammate),
          after: "."
        )
      when EngagementHealth::CATEGORY_OGO_RECEIVED
        ogo_received_attention
      when EngagementHealth::CATEGORY_OGO_GIVEN
        sentence(
          before: "Haven't given an OGO in a while — ",
          link_text: "write an observation",
          link_path: ogos_from_organization_company_teammate_path(@organization, @teammate),
          after: "."
        )
      when EngagementHealth::CATEGORY_REQUIRED_CLARITY
        clarity_attention
      when EngagementHealth::CATEGORY_GOAL_CONFIDENCE
        goal_attention
      when EngagementHealth::CATEGORY_MILESTONES
        milestone_attention
      else
        plain("#{@short_title} needs a closer look.")
      end
    end

    def clear_sentence
      focus = soonest_focus_item(prefer_warning_date: true)
      return plain("#{@short_title} is steady — keep it that way.") if focus.blank?

      name = focus[:name].to_s.presence
      path = focus[:path]
      by_clause = by_clause_for(focus[:warning_on])

      case @category
      when EngagementHealth::CATEGORY_REQUIRED_CLARITY
        return plain("#{@short_title} is steady — keep it that way.") if name.blank?

        sentence(
          before: "#{@short_title} is steady — consider ",
          link_text: "checking in on #{name}",
          link_path: path.presence || up_next_organization_company_teammate_check_ins_path(@organization, @teammate),
          after: "#{by_clause}."
        )
      when EngagementHealth::CATEGORY_GOAL_CONFIDENCE
        return plain("#{@short_title} is steady — keep it that way.") if name.blank?

        sentence(
          before: "#{@short_title} is steady — consider ",
          link_text: "updating confidence on #{name}",
          link_path: path.presence || my_growth_goals_organization_company_teammate_path(@organization, @teammate),
          after: "#{by_clause}."
        )
      when EngagementHealth::CATEGORY_OGO_GIVEN
        sentence(
          before: "#{@short_title} is steady — consider ",
          link_text: "giving an OGO",
          link_path: ogos_from_organization_company_teammate_path(@organization, @teammate),
          after: "#{by_clause}."
        )
      when EngagementHealth::CATEGORY_OGO_RECEIVED
        clear_ogo_received(by_clause)
      when EngagementHealth::CATEGORY_MILESTONES
        return plain("#{@short_title} is steady — keep it that way.") if name.blank?

        sentence(
          before: "#{@short_title} is steady — consider the next stretch on ",
          link_text: name,
          link_path: path.presence || my_growth_abilities_organization_company_teammate_path(@organization, @teammate),
          after: "."
        )
      else
        plain("#{@short_title} is steady — keep it that way.")
      end
    end

    def ogo_received_attention
      if viewing_self?
        sentence(
          before: "Haven't received an OGO in a while — ",
          link_text: "request feedback about yourself",
          link_path: new_organization_feedback_request_path(
            @organization,
            subject_of_feedback_teammate_id: @teammate.id
          ),
          after: "."
        )
      else
        sentence(
          before: "Haven't received an OGO in a while — ",
          link_text: "send a feedback request",
          link_path: accept_feedback_offer_organization_company_teammate_path(
            @organization,
            @teammate,
            offer_key: "values"
          ),
          link_method: :post,
          after: "."
        )
      end
    end

    def clear_ogo_received(by_clause)
      if viewing_self?
        sentence(
          before: "#{@short_title} is steady — consider ",
          link_text: "requesting feedback",
          link_path: new_organization_feedback_request_path(
            @organization,
            subject_of_feedback_teammate_id: @teammate.id
          ),
          after: "#{by_clause}."
        )
      else
        sentence(
          before: "#{@short_title} is steady — consider ",
          link_text: "sending a feedback request",
          link_path: accept_feedback_offer_organization_company_teammate_path(
            @organization,
            @teammate,
            offer_key: "values"
          ),
          link_method: :post,
          after: "#{by_clause}."
        )
      end
    end

    def clarity_attention
      focus = soonest_focus_item(prefer_warning_date: false)
      name = focus&.dig(:name).presence || "required check-ins"
      object_type = focus&.dig(:entity_type).presence || "item"
      path = focus&.dig(:path).presence ||
             up_next_organization_company_teammate_check_ins_path(@organization, @teammate)
      last_clause = last_finalized_clause(focus&.dig(:last_event_on), label: "check-in")

      if @status == EngagementHealth::NEEDS_ATTENTION
        sentence(
          before: "",
          link_text: "Check in on the #{object_type} #{name}",
          link_path: path,
          after: last_clause
        )
      else
        sentence(
          before: "Clarity is getting stale — ",
          link_text: "check in on #{name}",
          link_path: path,
          after: last_clause
        )
      end
    end

    def goal_attention
      focus = soonest_focus_item(prefer_warning_date: false)
      name = focus&.dig(:name).presence || "their goals"
      path = focus&.dig(:path).presence ||
             my_growth_goals_organization_company_teammate_path(@organization, @teammate)
      last_clause = last_finalized_clause(focus&.dig(:last_event_on), label: "confidence check-in")

      if @status == EngagementHealth::NEEDS_ATTENTION
        sentence(
          before: "",
          link_text: "Update confidence on the goal #{name}",
          link_path: path,
          after: last_clause
        )
      else
        sentence(
          before: "Goal confidence is getting stale — ",
          link_text: "update confidence on #{name}",
          link_path: path,
          after: last_clause
        )
      end
    end

    def milestone_attention
      if @status == EngagementHealth::NEEDS_ATTENTION && !initial_ability_milestone_calibration_completed?
        return sentence(
          before: "",
          link_text: "Complete the initial Ability Milestone calibration",
          link_path: ability_milestone_calibration_organization_company_teammate_path(
            @organization,
            @teammate
          ),
          after: "."
        )
      end

      focus = soonest_focus_item(prefer_warning_date: false)
      name = focus&.dig(:name).presence || "required abilities"
      path = focus&.dig(:path).presence ||
             my_growth_abilities_organization_company_teammate_path(@organization, @teammate)

      if @status == EngagementHealth::NEEDS_ATTENTION
        sentence(
          before: "",
          link_text: "Review the ability #{name}",
          link_path: path,
          after: "."
        )
      else
        sentence(
          before: "Milestones could use a nudge — ",
          link_text: "review #{name}",
          link_path: path,
          after: "."
        )
      end
    end

    def initial_ability_milestone_calibration_completed?
      calibration = AbilityMilestoneCalibration.find_by(teammate_id: @teammate.id)
      return false if calibration.blank?

      calibration.employee_completed_at.present? || calibration.manager_completed_at.present?
    end

    def last_finalized_clause(last_event_on, label:)
      if last_event_on.present?
        " — last finalized #{label} on this was #{last_event_on.strftime(DATE_FORMAT)}."
      else
        " — no finalized #{label} yet."
      end
    end

    def soonest_focus_item(prefer_warning_date:)
      scored = @items.filter_map do |item|
        inputs = item_inputs(item)
        name = inputs["name"].to_s.presence
        next if name.blank? && !ogo_category?

        warning_on = warning_date_for(inputs)
        path = path_for_item(item)
        entity_type = item_entity_type(item)
        {
          name: name,
          warning_on: warning_on,
          path: path,
          entity_type: entity_type,
          last_event_on: parse_date(inputs["last_event_at"]),
          sort_key: prefer_warning_date ? (warning_on || Date.new(9999, 12, 31)) : severity_sort(item)
        }
      end
      return scored.min_by { |row| [row[:sort_key], row[:name].to_s.downcase] } if prefer_warning_date

      # Attention: worst severity first, then name. Prefer matching item_links path.
      scored.min_by { |row| [row[:sort_key], row[:name].to_s.downcase] }
    end

    def item_entity_type(item)
      raw =
        if item.respond_to?(:entity_type)
          item.entity_type
        else
          item[:entity_type] || item["entity_type"]
        end
      raw.to_s.presence || "item"
    end

    def severity_sort(item)
      status =
        if item.respond_to?(:status)
          item.status
        else
          item[:status] || item["status"]
        end
      EngagementHealth.status_severity_rank(status)
    end

    def path_for_item(item)
      entity_type = item.respond_to?(:entity_type) ? item.entity_type : item[:entity_type]
      entity_id = item.respond_to?(:entity_id) ? item.entity_id : item[:entity_id]
      match = @item_links.find { |link| link[:label].to_s == item_inputs(item)["name"].to_s }
      return match[:path] if match&.dig(:path).present?

      case @category
      when EngagementHealth::CATEGORY_GOAL_CONFIDENCE
        return nil if entity_id.blank?

        organization_goal_path(@organization, entity_id)
      when EngagementHealth::CATEGORY_MILESTONES
        return nil if entity_id.blank?

        organization_teammate_ability_path(@organization, @teammate, entity_id)
      when EngagementHealth::CATEGORY_REQUIRED_CLARITY
        case entity_type.to_s
        when "Position"
          position_check_in_organization_teammate_path(@organization, @teammate)
        when "Assignment"
          return nil if entity_id.blank?

          organization_teammate_assignment_path(@organization, @teammate, entity_id)
        when "Aspiration"
          return nil if entity_id.blank?

          organization_teammate_aspiration_path(@organization, @teammate, entity_id)
        end
      end
    end

    def warning_date_for(inputs)
      case @category
      when EngagementHealth::CATEGORY_REQUIRED_CLARITY
        healthy_until = parse_date(inputs["healthy_until_at"])
        return healthy_until + 1.day if healthy_until.present?

        parse_date(inputs["needs_attention_at"])
      when EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
           EngagementHealth::CATEGORY_OGO_GIVEN,
           EngagementHealth::CATEGORY_OGO_RECEIVED
        last_event = parse_date(inputs["last_event_at"])
        healthy_within = positive_int(inputs["healthy_within_days"])
        return nil if last_event.blank? || healthy_within.blank?

        last_event + healthy_within.days + 1.day
      end
    end

    def by_clause_for(warning_on)
      return "" if warning_on.blank?
      return "" unless warning_on > @reference_date

      " by #{warning_on.strftime(DATE_FORMAT)}"
    end

    def ogo_category?
      @category.in?([
        EngagementHealth::CATEGORY_OGO_GIVEN,
        EngagementHealth::CATEGORY_OGO_RECEIVED
      ])
    end

    def viewing_self?
      @viewer.present? && @teammate.present? && @viewer.id == @teammate.id
    end

    def sentence(before:, link_text:, link_path:, after:, link_method: nil)
      {
        before: before,
        link_text: link_text,
        link_path: link_path,
        link_method: link_method,
        after: after
      }
    end

    def plain(text)
      { before: text, link_text: nil, link_path: nil, link_method: nil, after: nil }
    end

    def item_inputs(item)
      raw =
        if item.respond_to?(:inputs)
          item.inputs
        elsif item.is_a?(Hash)
          item[:inputs] || item["inputs"] || item
        else
          {}
        end
      raw.is_a?(Hash) ? raw.stringify_keys : {}
    end

    def parse_date(value)
      return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def positive_int(value)
      return nil if value.blank?

      int = Integer(value)
      int.positive? ? int : nil
    rescue ArgumentError, TypeError
      nil
    end
  end
end
