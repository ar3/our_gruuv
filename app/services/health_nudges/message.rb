# frozen_string_literal: true

module HealthNudges
  # Auto-generated health nudge copy (preview + Slack). Not editable by the sender.
  class Message
    include Rails.application.routes.url_helpers

    def initialize(health_object:, organization:, manager_teammate:, spotlight_stats:, url_options: nil)
      @health_object = health_object.to_s
      @config = Registry.fetch(@health_object)
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
      public_send(
        @config.fetch(:dashboard_url_name),
        @organization,
        manager_id: "CompanyTeammate_#{@manager_teammate.id}",
        **dashboard_url_options
      )
    end

    def dashboard_link_label
      @config.fetch(:dashboard_link_label)
    end

    def body_mrkdwn
      [
        "*#{@config.fetch(:title)}*",
        "",
        greeting_line,
        "",
        summary_line,
        *(unhealthy? ? [ "", @config.fetch(:importance) ] : []),
        "",
        closing_line,
        "",
        "<#{dashboard_url}|#{dashboard_link_label}>"
      ].join("\n")
    end

    def fallback_text
      parts = [
        "#{@config.fetch(:title)} for #{manager_name}'s team:",
        summary_line,
        *(unhealthy? ? [ @config.fetch(:importance) ] : []),
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
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: dashboard_link_label,
                emoji: true
              },
              style: "primary",
              url: dashboard_url,
              action_id: "health_nudge_open_dashboard"
            }
          ]
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
      "Hi #{manager_name} — #{@config.fetch(:greeting)}."
    end

    def summary_line
      if @config[:summary_style] == :protect_flow
        protect_flow_summary_line
      else
        standard_summary_line
      end
    end

    def standard_summary_line
      total = @stats[:total_employees].to_i
      healthy = @stats[:healthy_count].to_i
      warning = (@stats[:warning_count] || @stats[:ok_count]).to_i
      needs = (@stats[:needs_attention_count] || @stats[:concerning_count]).to_i
      metric = @config.fetch(:metric_label)

      if total.zero?
        "There are no active employees in this view right now."
      else
        "Of *#{total}* #{'person'.pluralize(total)}, *#{healthy}* Healthy, *#{warning}* Warning, " \
          "and *#{needs}* Needs Attention on #{metric}."
      end
    end

    def protect_flow_summary_line
      total = @stats[:total_employees].to_i
      healthy = @stats[:healthy_count].to_i
      needs = (@stats[:needs_attention_count] || @stats[:concerning_count]).to_i
      vectors = @stats[:current_unhealthy_vectors].to_i
      improved = @stats[:improved_vector_count].to_i

      if total.zero?
        "There are no people in this view right now."
      else
        parts = [
          "Of *#{total}* #{'person'.pluralize(total)}, *#{healthy}* fully healthy this week",
          "*#{needs}* with unhealthy vectors"
        ]
        parts << "*#{vectors}* unhealthy vectors across the team" if vectors.positive?
        parts << "*#{improved}* vectors improved so far" if improved.positive?
        "#{parts.join(', ')}."
      end
    end

    def closing_line
      if @stats[:total_employees].to_i.zero?
        @config.fetch(:empty_closing)
      elsif unhealthy?
        "You're not alone in this — happy to help untangle anything that needs more context."
      else
        @config.fetch(:healthy_closing)
      end
    end

    def unhealthy?
      return protect_flow_unhealthy? if @config[:summary_style] == :protect_flow

      (@stats[:needs_attention_count] || @stats[:concerning_count]).to_i.positive? ||
        (@stats[:warning_count] || @stats[:ok_count]).to_i.positive?
    end

    def protect_flow_unhealthy?
      (@stats[:needs_attention_count] || @stats[:concerning_count]).to_i.positive? ||
        @stats[:current_unhealthy_vectors].to_i.positive?
    end

    def dashboard_url_options
      options = @url_options.dup
      options[:week_start] = @stats[:week_start] if @stats[:week_start].present?
      options
    end

    def default_url_options
      base = Rails.application.config.action_mailer.default_url_options.presence ||
             Rails.application.routes.default_url_options || {}
      base = base.symbolize_keys
      base.reverse_merge(host: "localhost", protocol: "http")
    end
  end
end
