# frozen_string_literal: true

module CheckIns
  # Resolves the single "Just tell me what to do next" action for Up Next.
  # Actionable set = Gruuv Health warning / needs_attention only.
  # Priority: review → my incomplete → waiting nudge → all clear.
  class UpNextTellMeNextService
    ACTIONABLE_STATUSES = [
      EngagementHealth::WARNING,
      EngagementHealth::NEEDS_ATTENTION
    ].freeze

    OBJECT_TYPE_LABELS = {
      aspiration: "Aspirational Value",
      assignment: "Assignment",
      position: "Position"
    }.freeze

    def self.call(teammate:, organization:, viewing_person:, viewing_teammate:, eh_by_key: nil)
      new(
        teammate: teammate,
        organization: organization,
        viewing_person: viewing_person,
        viewing_teammate: viewing_teammate,
        eh_by_key: eh_by_key
      ).call
    end

    def initialize(teammate:, organization:, viewing_person:, viewing_teammate:, eh_by_key: nil)
      @teammate = teammate
      @organization = organization
      @viewing_person = viewing_person
      @viewing_teammate = viewing_teammate
      @eh_by_key = eh_by_key
    end

    def call
      rows = actionable_rows
      return all_clear_payload if rows.empty?

      ready = rows.select { |row| row[:ready_for_review] }
      return review_payload(ready) if ready.any?

      incomplete = rows.select { |row| row[:my_side_incomplete] }
      return incomplete_payload(incomplete) if incomplete.any?

      waiting = rows.reject { |row| row[:my_side_incomplete] }
      return nudge_payload(waiting) if waiting.any?

      all_clear_payload
    end

    private

    attr_reader :teammate, :organization, :viewing_person, :viewing_teammate

    def manager_perspective?
      viewing_person&.id != teammate.person_id
    end

    def casual_name
      teammate.person.casual_name.presence || "this teammate"
    end

    def eh_by_key
      @eh_by_key ||= begin
        records = EngagementHealth::ClarityMetrics.records_for_teammate(
          organization: organization,
          teammate_id: teammate.id
        )
        EngagementHealth::UpNextSupport.index_items_by_key(records)
      end
    end

    def next_result
      @next_result ||= SingleItemCheckInNextItemService.call(
        teammate: teammate,
        organization: organization,
        current_person: viewing_person,
        current_type: :position,
        current_id: nil
      )
    end

    def actionable_rows
      next_result[:ordered_items].to_a.filter_map do |item|
        eh_item = EngagementHealth::UpNextSupport.find_item(eh_by_key, item)
        next unless eh_item && ACTIONABLE_STATUSES.include?(eh_item.status)

        inputs = eh_item.inputs || {}
        workflow = EngagementHealth::UpNextSupport.workflow_completion(eh_item: eh_item, latest_open: nil)
        my_done = manager_perspective? ? workflow[:manager_done] : workflow[:employee_done]
        open_present = ActiveModel::Type::Boolean.new.cast(inputs["open_check_in_present"])
        # No open check-in on an unhealthy item ⇒ viewer still owes starting their side.
        my_side_incomplete = open_present ? !my_done : true
        both_done = workflow[:employee_done] && workflow[:manager_done]
        ready_for_review = workflow[:ready_for_joint_review] || both_done

        {
          item: item,
          eh_item: eh_item,
          my_side_incomplete: my_side_incomplete,
          ready_for_review: ready_for_review
        }
      end
    end

    def all_clear_payload
      {
        state: :all_clear,
        note: nil,
        button_label: "All clear here! Check out #{casual_name}'s overall clarity health",
        button_url: hub_path,
        button_method: :get,
        preview_text: nil,
        last_nudge: nil,
        count: 0
      }
    end

    def review_payload(ready_rows)
      count = ready_rows.size
      {
        state: :review,
        note: "#{casual_name} and their manager have both completed their side of #{count} " \
              "#{"check-in".pluralize(count)}... go review them together right now!",
        button_label: "Review #{count} #{"check-in".pluralize(count)} together",
        button_url: finalization_path,
        button_method: :get,
        preview_text: nil,
        last_nudge: nil,
        count: count
      }
    end

    def incomplete_payload(incomplete_rows)
      # Prefer next-item algorithm order among viewer-incomplete actionable items.
      ordered_keys = next_result[:ordered_items].to_a.map { |i| EngagementHealth::UpNextSupport.item_key(i) }
      best = incomplete_rows.min_by do |row|
        ordered_keys.index(EngagementHealth::UpNextSupport.item_key(row[:item])) || 999
      end
      item = best[:item]
      type = item[:type].to_sym
      type_label = OBJECT_TYPE_LABELS.fetch(type, type.to_s.humanize)
      {
        state: :incomplete,
        note: nil,
        button_label: "Check-in on #{casual_name} and the #{type_label} #{item[:name]}",
        button_url: url_for_item(item),
        button_method: :get,
        preview_text: nil,
        last_nudge: nil,
        count: incomplete_rows.size,
        next_item: item
      }
    end

    def nudge_payload(waiting_rows)
      count = waiting_rows.size
      last_nudge = UpNextWaitingNudgeService.last_delivered_between(
        employee_teammate: teammate,
        viewer_teammate: viewing_teammate,
        other_teammate: other_party_teammate
      )
      previously_sent = last_nudge.present?
      {
        state: :nudge,
        note: "Your side is clear on the #{count} #{"check-in".pluralize(count)} that need attention. " \
              "Nudge the other person so you can schedule the review together.",
        button_label: previously_sent ? "Send Again" : "Send Slack nudge for #{count} #{"check-in".pluralize(count)}",
        button_url: nudge_path,
        button_method: :post,
        preview_text: UpNextWaitingNudgeService.message_body(
          waiting_count: count,
          up_next_url: up_next_url
        ),
        last_nudge: last_nudge,
        count: count
      }
    end

    def other_party_teammate
      if manager_perspective?
        teammate
      else
        teammate.employment_tenures.active.first&.manager_teammate
      end
    end

    def hub_path
      Rails.application.routes.url_helpers.hub_organization_company_teammate_check_ins_path(
        organization,
        teammate
      )
    end

    def finalization_path
      Rails.application.routes.url_helpers.organization_company_teammate_finalization_path(
        organization,
        teammate
      )
    end

    def nudge_path
      Rails.application.routes.url_helpers.waiting_nudge_organization_company_teammate_check_ins_path(
        organization,
        teammate
      )
    end

    def up_next_url
      helpers = Rails.application.routes.url_helpers
      opts = mail_url_options
      helpers.up_next_organization_company_teammate_check_ins_url(organization, teammate, opts)
    end

    def mail_url_options
      base = Rails.application.config.action_mailer.default_url_options.presence ||
             Rails.application.routes.default_url_options || {}
      base = base.symbolize_keys
      base.reverse_merge(host: "localhost", protocol: "http")
    end

    def url_for_item(item)
      case item[:type]&.to_sym
      when :aspiration
        Rails.application.routes.url_helpers.organization_teammate_aspiration_path(
          organization, teammate, item[:id]
        )
      when :assignment
        Rails.application.routes.url_helpers.organization_teammate_assignment_path(
          organization, teammate, item[:id]
        )
      when :position
        Rails.application.routes.url_helpers.position_check_in_organization_teammate_path(
          organization, teammate
        )
      else
        hub_path
      end
    end
  end
end
