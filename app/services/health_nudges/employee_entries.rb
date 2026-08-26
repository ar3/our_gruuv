# frozen_string_literal: true

module HealthNudges
  # Normalizes per-employee health rows into Slack thread entry hashes.
  module EmployeeEntries
    STATUS_EMOJI = {
      EngagementHealth::HEALTHY => ":large_green_circle:",
      EngagementHealth::WARNING => ":large_yellow_circle:",
      EngagementHealth::NEEDS_ATTENTION => ":red_circle:"
    }.freeze

    SPOTLIGHT_TO_EH = {
      healthy: EngagementHealth::HEALTHY,
      ok: EngagementHealth::WARNING,
      concerning: EngagementHealth::NEEDS_ATTENTION
    }.freeze

    module_function

    def from_goals_rows(rows)
      Array(rows).filter_map { |row| from_goals_row(row) }.then { |entries| sort_entries(entries) }
    end

    def from_check_ins_rows(rows)
      Array(rows).filter_map { |row| from_check_ins_row(row) }.then { |entries| sort_entries(entries) }
    end

    def from_milestones_rows(rows)
      Array(rows).filter_map { |row| from_milestones_row(row) }.then { |entries| sort_entries(entries) }
    end

    def from_observations_rows(rows)
      Array(rows).filter_map { |row| from_observations_row(row) }.then { |entries| sort_entries(entries) }
    end

    def from_protect_flow_people(people)
      Array(people).filter_map { |person| from_protect_flow_person(person) }.then { |entries| sort_entries(entries) }
    end

    def from_goals_row(row)
      teammate = row[:teammate]
      return nil unless teammate

      eh_status = row[:eh_status].presence || spotlight_to_eh(row[:status])
      lines = row[:status_lines] || {}
      detail =
        if row[:empty_reason].present?
          row[:empty_reason].to_s
        else
          parts = EngagementHealth::STATUSES.filter_map do |status|
            counts = lines[status] || {}
            active = counts[:active].to_i
            completed = counts[:completed].to_i
            draft = counts[:draft].to_i
            next if active.zero? && completed.zero? && draft.zero?

            bits = []
            bits << "#{active} active" if active.positive?
            bits << "#{completed} completed" if completed.positive?
            bits << "#{draft} drafts" if draft.positive?
            "#{EngagementHealth::STATUS_LABELS[status]}: #{bits.join(', ')}"
          end
          parts.presence&.join(" · ") || "No scored goals in this view."
        end

      entry(teammate: teammate, eh_status: eh_status, detail: detail, health_object: "goals_health")
    end

    def from_check_ins_row(row)
      teammate = row[:teammate]
      return nil unless teammate

      records = row[:engagement_health_records] || []
      eh_status = CheckInsHealthEngagementHealthSupport.clarity_rollup_status(records) || EngagementHealth::NEEDS_ATTENTION
      breakdown = row[:action_breakdown]
      detail =
        if breakdown
          "Clarity actions ... Healthy: #{breakdown.healthy_slots}, Warning: #{breakdown.warning_slots}, " \
            "Needs Attention: #{breakdown.needs_attention_slots} " \
            "(#{breakdown.ok_percentage.round}% clear)."
        else
          "Required Clarity is #{EngagementHealth::STATUS_LABELS.fetch(eh_status)}."
        end

      entry(teammate: teammate, eh_status: eh_status, detail: detail, health_object: "check_ins_health")
    end

    def from_milestones_row(row)
      teammate = row[:teammate]
      return nil unless teammate

      eh_status = row[:eh_status].presence || spotlight_to_eh(row[:status])
      attention = Array(row[:attention_items]).first
      detail =
        if attention.present?
          level_bits = []
          level_bits << "required L#{attention[:required_level]}" if attention[:required_level].present?
          level_bits << "earned L#{attention[:earned_level]}" if attention[:earned_level].present?
          reason = attention[:reason].presence
          [
            "#{attention[:name]} is #{EngagementHealth::STATUS_LABELS.fetch(attention[:status], attention[:status].to_s.humanize)}",
            level_bits.presence&.join(", "),
            reason
          ].compact.join(" ... ")
        elsif row[:empty_reason].present?
          row[:empty_reason].to_s
        else
          counts = row[:status_counts] || {}
          "Milestone abilities ... Healthy: #{counts[EngagementHealth::HEALTHY].to_i}, " \
            "Warning: #{counts[EngagementHealth::WARNING].to_i}, " \
            "Needs Attention: #{counts[EngagementHealth::NEEDS_ATTENTION].to_i}."
        end

      entry(teammate: teammate, eh_status: eh_status, detail: detail, health_object: "milestones_health")
    end

    def from_observations_row(row)
      teammate = row[:teammate]
      return nil unless teammate

      eh_status = row[:overall_status].presence || spotlight_to_eh(row[:status])
      given = row[:given] || {}
      received = row[:received] || {}
      detail = [
        "Given: #{band_summary(given)}",
        "Received: #{band_summary(received)}"
      ].join(" · ")

      entry(teammate: teammate, eh_status: eh_status, detail: detail, health_object: "observations_health")
    end

    def from_protect_flow_person(person)
      teammate = person[:teammate]
      return nil unless teammate

      eh_status = person[:worst_status].presence || EngagementHealth::WARNING
      hero = person[:hero] || {}
      unhealthy = person[:unhealthy_count].to_i
      detail =
        if hero[:title].present?
          bits = [ hero[:title].to_s ]
          bits << hero[:why].to_s if hero[:why].present?
          bits << "#{unhealthy} unhealthy #{'vector'.pluralize(unhealthy)}" if unhealthy.positive?
          bits.join(" ... ")
        elsif unhealthy.positive?
          "#{unhealthy} unhealthy #{'vector'.pluralize(unhealthy)} this week."
        else
          "All vectors healthy this week."
        end

      entry(teammate: teammate, eh_status: eh_status, detail: detail, health_object: "protect_flow")
    end

    def entry(teammate:, eh_status:, detail:, health_object:)
      status = EngagementHealth::STATUSES.include?(eh_status) ? eh_status : EngagementHealth::NEEDS_ATTENTION
      name = teammate.person&.casual_name.presence || teammate.person&.display_name.presence || "Teammate"
      destination = destination_for(health_object: health_object, teammate: teammate, name: name)
      {
        teammate_id: teammate.id,
        name: name,
        status: status,
        status_label: EngagementHealth::STATUS_LABELS.fetch(status),
        status_emoji: STATUS_EMOJI.fetch(status),
        detail: detail.to_s.truncate(400),
        profile_image_url: teammate.profile_image_url.to_s.presence,
        action_url: destination[:url],
        action_button_label: destination[:button_label]
      }
    end

    def destination_for(health_object:, teammate:, name:)
      organization = teammate.organization
      opts = url_options
      page_name, url =
        case health_object.to_s
        when "goals_health"
          [
            "Goals",
            routes.my_growth_goals_organization_company_teammate_url(organization, teammate, **opts)
          ]
        when "check_ins_health"
          [
            "Check-ins",
            routes.organization_company_teammate_check_ins_url(organization, teammate, **opts)
          ]
        when "milestones_health"
          [
            "Abilities",
            routes.my_growth_abilities_organization_company_teammate_url(organization, teammate, **opts)
          ]
        when "observations_health"
          [
            "OGOs",
            routes.ogos_organization_company_teammate_url(organization, teammate, **opts)
          ]
        else
          [
            "One Thing",
            routes.organization_company_teammate_one_on_one_link_url(organization, teammate, **opts)
          ]
        end

      {
        url: url,
        button_label: "Go to #{name}'s #{page_name} Page"
      }
    end

    def routes
      Rails.application.routes.url_helpers
    end

    def url_options
      base = Rails.application.config.action_mailer.default_url_options.presence ||
             Rails.application.routes.default_url_options || {}
      base = base.symbolize_keys
      base.reverse_merge(host: "localhost", protocol: "http")
    end

    def spotlight_to_eh(status)
      SPOTLIGHT_TO_EH.fetch(status&.to_sym, EngagementHealth::NEEDS_ATTENTION)
    end

    def band_summary(section)
      total = section["observations_count"].to_i
      if section["never"] || total.zero?
        "none yet"
      else
        "Healthy #{section['healthy_count'].to_i} / Warning #{section['warning_count'].to_i} / " \
          "Needs Attention #{section['needs_attention_count'].to_i}"
      end
    end

    def sort_entries(entries)
      entries.sort_by { |entry| [ EngagementHealth.status_severity_rank(entry[:status]), entry[:name].to_s.downcase ] }
    end
  end
end
