# frozen_string_literal: true

module Goals
  # Auto-generated Goals Health nudge copy (preview + Slack). Not editable by the sender.
  class HealthNudgeMessage
    include Rails.application.routes.url_helpers

    IMPORTANCE_WHEN_UNHEALTHY =
      "Fresh Goal Confidence check-ins keep goals honest: they surface when priorities " \
      "shift so the team can course-correct before work drifts.".freeze

    def initialize(organization:, manager_teammate:, spotlight_stats:, url_options: nil)
      @organization = organization
      @manager_teammate = manager_teammate
      @stats = spotlight_stats.symbolize_keys
      @url_options = url_options || default_url_options
    end

    def manager_name
      person = @manager_teammate.person
      person&.casual_name.presence || person&.first_name.presence || person&.display_name.presence || "there"
    end

    def dashboard_url
      organization_goals_health_url(
        @organization,
        manager_id: "CompanyTeammate_#{@manager_teammate.id}",
        **@url_options
      )
    end

    def body_mrkdwn
      [
        "*Goals Health check-in*",
        "",
        greeting_line,
        "",
        summary_line,
        *(unhealthy? ? [ "", IMPORTANCE_WHEN_UNHEALTHY ] : []),
        "",
        closing_line,
        "",
        "<#{dashboard_url}|Open Goals Health for your team>"
      ].join("\n")
    end

    def fallback_text
      parts = [
        "Goals Health check-in for #{manager_name}'s team:",
        summary_line,
        *(unhealthy? ? [ IMPORTANCE_WHEN_UNHEALTHY ] : []),
        "Open: #{dashboard_url}"
      ]
      parts.join(" ")
    end

    def slack_blocks
      [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: body_mrkdwn
          }
        }
      ]
    end

    def preview_plain
      body_mrkdwn
        .gsub(/\*(.*?)\*/, '\1')
        .gsub(/<(.*?)\|(.*?)>/, '\2 (\1)')
        .gsub(/<(.*?)>/, '\1')
    end

    private

    def greeting_line
      "Hi #{manager_name} — a quick look at Goal Confidence for your direct reports."
    end

    def summary_line
      total = @stats[:total_employees].to_i
      healthy = @stats[:healthy_count].to_i
      warning = (@stats[:warning_count] || @stats[:ok_count]).to_i
      needs = (@stats[:needs_attention_count] || @stats[:concerning_count]).to_i

      if total.zero?
        "There are no active employees in this view right now."
      else
        "Of *#{total}* #{'person'.pluralize(total)}, *#{healthy}* Healthy, *#{warning}* Warning, " \
          "and *#{needs}* Needs Attention on Goal Confidence."
      end
    end

    def closing_line
      if @stats[:total_employees].to_i.zero?
        "When folks join your team, this view will help you keep Goal Confidence on track."
      elsif unhealthy?
        "You're not alone in this — happy to help untangle anything that needs more context."
      else
        "Nice work keeping Goal Confidence current — that habit makes the harder conversations easier."
      end
    end

    def unhealthy?
      (@stats[:needs_attention_count] || @stats[:concerning_count]).to_i.positive? ||
        (@stats[:warning_count] || @stats[:ok_count]).to_i.positive?
    end

    def default_url_options
      base = Rails.application.config.action_mailer.default_url_options.presence ||
             Rails.application.routes.default_url_options || {}
      base = base.symbolize_keys
      base.reverse_merge(host: "localhost", protocol: "http")
    end
  end
end
