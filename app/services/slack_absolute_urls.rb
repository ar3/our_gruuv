# frozen_string_literal: true

# Slack mrkdwn links must use absolute URLs; path-only hrefs do not open correctly in Slack clients.
module SlackAbsoluteUrls
  module InstanceMethods
    def slack_absolute_url(url_or_path)
      SlackAbsoluteUrls.absolute(url_or_path)
    end

    def slack_url_options
      SlackAbsoluteUrls.slack_url_options
    end
  end

  def self.included(base)
    base.include InstanceMethods
  end

  module_function

  def slack_url_options
    base = Rails.application.config.action_mailer.default_url_options.presence ||
           Rails.application.routes.default_url_options || {}
    base.symbolize_keys.reverse_merge(
      host: ENV.fetch("RAILS_HOST", "localhost"),
      protocol: ENV.fetch("RAILS_ACTION_MAILER_DEFAULT_URL_PROTOCOL", "http")
    )
  end

  def absolute(url_or_path)
    s = url_or_path.to_s
    return s if s.blank? || s.match?(/\Ahttps?:\/\//i)

    host = slack_url_options[:host].presence
    return s if host.blank?

    protocol = slack_url_options[:protocol] || "https"
    path = s.start_with?("/") ? s : "/#{s}"
    "#{protocol}://#{host}#{path}"
  end
end
