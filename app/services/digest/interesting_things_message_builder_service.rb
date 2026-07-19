# frozen_string_literal: true

module Digest
  # Builds Slack Block Kit payloads (and an SMS summary) for the Interesting Things digest:
  # things other people have done since the teammate's last visit to the Something Interesting page.
  class InterestingThingsMessageBuilderService
    include SlackAbsoluteUrls

    def initialize(teammate:, organization:, since:)
      @teammate = teammate
      @organization = organization
      @company = organization.root_company || organization
      @since = since
      @query_service = SomethingInterestingQueryService.new(teammate: teammate, since: since)
    end

    def total_count
      @total_count ||= sections.sum { |section| section[:items].size }
    end

    def main_message
      casual_name = slack_escape(@teammate.person.casual_name)
      page_url = slack_app_url(:something_interesting_organization_get_shit_done_url, @organization)
      page_link = "<#{page_url}|interesting #{'thing'.pluralize(total_count)}>"

      lines = ["#{casual_name}, there #{total_count == 1 ? 'is' : 'are'} #{total_count} #{page_link} since you last checked."]
      sections.each do |section|
        count = section[:items].size
        lines << "• #{count} #{section[:label]}" if count.positive?
      end

      fallback_text = "You have #{total_count} interesting #{'thing'.pluralize(total_count)} waiting. Check them out: #{page_url}"
      config_url = slack_app_url(:organization_company_teammate_notifications_url, @organization, @teammate)

      blocks = [
        { type: 'section', text: { type: 'mrkdwn', text: truncate_for_slack_section(lines.join("\n")) } },
        { type: 'context', elements: [{ type: 'mrkdwn', text: "Configure your notifications: <#{config_url}|Notification settings>" }] }
      ]
      { blocks: blocks, text: fallback_text }
    end

    # One thread payload per section that has items, listing the items with links.
    def thread_payloads
      sections.filter_map do |section|
        next if section[:items].empty?

        lines = ["*#{section[:title]}*"]
        section[:items].each { |line| lines << "  • #{line}" }
        text = truncate_for_slack_section(lines.join("\n"))
        { blocks: [{ type: 'section', text: { type: 'mrkdwn', text: text } }], text: text }
      end
    end

    def short_summary_for_sms
      org_name = @company.name.presence || @organization.name.presence
      prefix = org_name.present? ? "#{org_name}: " : ''
      "#{prefix}#{total_count} interesting #{'thing'.pluralize(total_count)} since you last checked. See them by logging into OurGruuv (dot) com."
    end

    private

    def sections
      @sections ||= [
        {
          title: 'Goals updated by those you serve',
          label: 'goal updates from those you serve',
          items: @query_service.goals_updated_by_those_i_serve.map { |activity| goal_activity_line(activity) }
        },
        {
          title: 'Goals updated on your teams',
          label: 'goal updates on your teams',
          items: @query_service.goals_updated_on_my_teams.map { |activity| goal_activity_line(activity) }
        },
        {
          title: "Assignments you're interested in",
          label: 'assignment updates',
          items: @query_service.assignments_updated.map { |a| record_line(a.title, :organization_assignment_url, a) }
        },
        {
          title: "Abilities you're interested in",
          label: 'ability updates',
          items: @query_service.abilities_updated.map { |a| record_line(a.name, :organization_ability_url, a) }
        },
        {
          title: 'Observations about those you serve',
          label: 'observations about those you serve',
          items: @query_service.observations_about_those_i_serve.map { |o| observation_line(o) }
        },
        {
          title: 'Observations about you',
          label: 'observations about you',
          items: @query_service.observations_about_me.map { |o| observation_line(o) }
        },
        {
          title: 'New comments on observations',
          label: 'comments on observations you care about',
          items: @query_service.observation_comments.map { |c| observation_comment_line(c) }
        }
      ]
    end

    def goal_activity_line(activity)
      goal = activity.goal
      line = record_line(goal.title, :organization_goal_url, goal)
      check_in_count = activity.new_check_ins.size
      line += " (#{check_in_count} new #{'check-in'.pluralize(check_in_count)})" if check_in_count.positive?
      line
    end

    def observation_line(observation)
      record_line(observation.story, :organization_observation_url, observation)
    end

    def observation_comment_line(comment)
      observation = comment.root_commentable
      snippet = comment.body.to_s
      snippet = "#{snippet[0, 60]}..." if snippet.length > 60
      url = slack_app_url(:organization_observation_url, @organization, observation)
      author = slack_escape(comment.creator.casual_name)
      "<#{url}|#{author}: #{slack_escape(snippet)}>"
    end

    def record_line(label, url_helper, record)
      snippet = label.to_s
      snippet = "#{snippet[0, 60]}..." if snippet.length > 60
      url = slack_app_url(url_helper, @organization, record)
      "<#{url}|#{slack_escape(snippet)}>"
    end

    def slack_app_url(helper_name, *args)
      slack_absolute_url(Rails.application.routes.url_helpers.public_send(helper_name, *args, slack_url_options))
    end

    def slack_escape(str)
      str.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    SLACK_SECTION_TEXT_LIMIT = 3000

    def truncate_for_slack_section(text)
      s = text.to_s
      return s if s.blank? || s.length <= SLACK_SECTION_TEXT_LIMIT
      "#{s[0, SLACK_SECTION_TEXT_LIMIT - 3]}..."
    end
  end
end
