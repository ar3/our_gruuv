# frozen_string_literal: true

module Digest
  # Builds Slack Block Kit payloads for the GSD digest: main message plus one thread per GSD section and one About Me thread.
  # Uses company label for "Get shit done"; main message includes a link to configure the digest.
  class SlackMessageBuilderService
    include ActionView::Helpers::DateHelper

    GSD_CATEGORY_LABELS = {
      observable_moments: 'Observable Moments',
      maap_snapshots: 'Check-ins Awaiting Acknowledgement',
      observation_drafts: 'Observation Drafts',
      goals_needing_check_in: 'Goal Check-ins',
      check_ins_awaiting_input: 'Check-ins Awaiting Your Input'
    }.freeze

    def initialize(teammate:, organization:)
      @teammate = teammate
      @organization = organization
      @company = organization.root_company || organization
      @gsd_label = @company.label_for('get_shit_done', 'Get Shit Done')
      @items = GetShitDoneQueryService.new(teammate: teammate).all_pending_items
      @about_me_sections = AboutMeContentService.new(teammate: teammate, organization: organization).sections
    end

    def main_message
      casual_name = slack_escape(@teammate.person.casual_name)
      total = @items[:total_pending].to_i
      gsd_page_url = Rails.application.routes.url_helpers.organization_get_shit_done_url(@organization)
      gsd_list_link = "<#{gsd_page_url}|#{slack_escape(@gsd_label)} list>"

      # Block content: "<casual name>, you have <total> items in the <label> list." (label is a link) then bullet list of count per category
      block_lines = if total.positive?
        lines = ["#{casual_name}, you have #{total} #{'item'.pluralize(total)} in the #{gsd_list_link}."]
        GSD_CATEGORY_LABELS.each do |key, label|
          count = category_count(key)
          lines << "• #{count} in #{label}" if count.positive?
        end
        lines.join("\n")
      else
        "Great job — you have no items on your #{gsd_list_link}."
      end

      # Fallback text (plain): "Your <org name> <org label for get shit done> list contains <count of items> items. Check them out: <link to the get shit done page>"
      org_name = @company.name.presence || @organization.name.presence
      list_phrase = org_name.present? ? "Your #{org_name} #{@gsd_label} list" : "Your #{@gsd_label} list"
      fallback_text = if total.positive?
        "#{list_phrase} contains #{total} #{'item'.pluralize(total)}. Check them out: #{gsd_page_url}"
      else
        "#{list_phrase} has no items. View it: #{gsd_page_url}"
      end

      digest_config_url = digest_config_url_for_organization
      caption_text = "Configure your digest: #{digest_config_url}"

      blocks = [
        { type: 'section', text: { type: 'mrkdwn', text: truncate_for_slack_section(block_lines) } },
        { type: 'context', elements: [{ type: 'mrkdwn', text: truncate_for_slack_section(caption_text) }] }
      ]
      { blocks: blocks, text: fallback_text }
    end

    # Returns one thread payload per GSD category that has items (each section in its own thread). If no category has items, returns one "All categories are clear." payload.
    def gsd_thread_payloads
      payloads = []
      GSD_CATEGORY_LABELS.each do |key, label|
        next if category_count(key).zero?

        lines = ["*#{label}*"]
        item_lines = item_labels_for(key)
        item_lines.each { |line| lines << "  • #{line}" }
        text = truncate_for_slack_section(lines.join("\n"))
        payloads << { blocks: [{ type: 'section', text: { type: 'mrkdwn', text: text } }], text: text }
      end
      if payloads.empty?
        text = "All categories are clear."
        payloads << { blocks: [{ type: 'section', text: { type: 'mrkdwn', text: text } }], text: text }
      end
      payloads
    end

    # SMS message: "Your <org name> <org label for get shit done> list contains <count of items> items. Check them out." (no URL)
    def short_summary_for_sms
      total = @items[:total_pending].to_i
      org_name = @company.name.presence || @organization.name.presence
      list_phrase = org_name.present? ? "Your #{org_name} #{@gsd_label} list" : "Your #{@gsd_label} list"
      if total.positive?
        "#{list_phrase} contains #{total} #{'item'.pluralize(total)}. Check them out by logging into OurGruuv (dot) com."
      else
        "#{list_phrase} has no items."
      end
    end

    CHECK_IN_SECTION_KEYS = %i[aspirations_check_in assignments_check_in position_check_in].freeze

    def thread2_about_me
      lines = []
      red_sections = @about_me_sections.select { |s| s[:status] == :red }
      yellow_sections = @about_me_sections.select { |s| s[:status] == :yellow }
      green_sections = @about_me_sections.select { |s| s[:status] == :green }
      summary_parts = []
      summary_parts << "#{green_sections.size} #{'section'.pluralize(green_sections.size)} #{green_sections.size == 1 ? 'is' : 'are'} healthy" if green_sections.any?
      summary_parts << "#{yellow_sections.size} #{'section'.pluralize(yellow_sections.size)} need some attention" if yellow_sections.any?
      summary_parts << "#{red_sections.size} #{'section'.pluralize(red_sections.size)} need the most attention" if red_sections.any?
      lines << summary_parts.join(', ') + '.' if summary_parts.any?
      lines << ''

      if red_sections.any?
        lines << "*NEEDS MOST ATTENTION (#{red_sections.size} #{'section'.pluralize(red_sections.size)}):*"
        red_sections.each { |s| lines << "• #{about_me_section_line(s)}" }
        lines << ''
      end
      if yellow_sections.any?
        lines << "*NEEDS SOME ATTENTION (#{yellow_sections.size} #{'section'.pluralize(yellow_sections.size)}):*"
        yellow_sections.each { |s| lines << "• #{about_me_section_line(s)}" }
        lines << ''
      end
      if green_sections.any?
        lines << "*HEALTHY (#{green_sections.size} #{'section'.pluralize(green_sections.size)}):*"
        green_sections.each { |s| lines << "• #{about_me_section_line(s)}" }
      end

      text = lines.join("\n")
      text = truncate_for_slack_section(text)
      blocks = [{ type: 'section', text: { type: 'mrkdwn', text: text } }]
      { blocks: blocks, text: text }
    end

    private

    # Slack mrkdwn treats &, <, > as control characters. Escape user-generated content to avoid invalid_blocks.
    def slack_escape(str)
      str.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    # Slack section block text is limited to 3000 chars; exceeding causes invalid_blocks.
    SLACK_SECTION_TEXT_LIMIT = 3000

    def truncate_for_slack_section(text)
      s = text.to_s
      return s if s.blank? || s.length <= SLACK_SECTION_TEXT_LIMIT
      "#{s[0, SLACK_SECTION_TEXT_LIMIT - 3]}..."
    end

    def digest_config_url_for_organization
      url = Rails.application.routes.url_helpers.edit_organization_digest_url(@organization)
      "<#{url}|Digest settings>"
    end

    # Formats one section for the About Me thread: link (and optional explanation). Check-in sections use ":" before explanation; others use ". ".
    def about_me_section_line(section)
      link_text, url = about_me_section_link(section[:key])
      link_part = url.present? ? "<#{url}|#{slack_escape(link_text)}>" : slack_escape(link_text)
      explanation = section[:explanation_sentence].to_s
      separator = CHECK_IN_SECTION_KEYS.include?(section[:key]) ? ': ' : '. '
      explanation.present? ? "#{link_part}#{separator}#{slack_escape(explanation)}" : link_part
    end

    # Returns [link_text, url] for the About Me section. URL is full URL for Slack mrkdwn links.
    def about_me_section_link(key)
      helpers = Rails.application.routes.url_helpers
      case key
      when :aspirations_check_in
        ['Aspirational Values Check-In', helpers.organization_company_teammate_check_ins_url(@organization, @teammate)]
      when :assignments_check_in
        ['Assignments/Outcomes Check-In', helpers.organization_company_teammate_check_ins_url(@organization, @teammate)]
      when :position_check_in
        ['Position/Overall', helpers.organization_company_teammate_check_ins_url(@organization, @teammate)]
      when :goals
        ['Active Goals', helpers.organization_goals_url(@organization, owner_id: "CompanyTeammate_#{@teammate.id}")]
      when :prompts
        label = @company.label_for('prompt', 'Prompts/Reflections')
        [label, helpers.organization_prompts_url(@organization)]
      when :stories
        ['Observations (OGOs)', helpers.organization_observations_url(@organization, involving_teammate_id: @teammate.id)]
      when :one_on_one
        ['1:1 Area', helpers.organization_company_teammate_one_on_one_link_url(@organization, @teammate)]
      when :abilities
        current_position = EmploymentTenure.where(company_teammate: @teammate, ended_at: nil).first&.position
        if current_position
          [ 'Abilities/Skills/Knowledge',
            helpers.organization_eligibility_requirement_url(@organization, current_position, teammate_id: @teammate.id) ]
        else
          ['Abilities/Skills/Knowledge', helpers.organization_eligibility_requirements_url(@organization)]
        end
      else
        [key.to_s.humanize, nil]
      end
    end

    def category_count(key)
      collection = @items[key]
      return 0 if collection.nil?
      collection.respond_to?(:count) ? collection.count : collection.size
    end

    def item_labels_for(key)
      collection = @items[key]
      return [] if collection.blank?

      case key
      when :observable_moments
        collection.map { |m| slack_escape(m.digest_sentence) }
      when :maap_snapshots
        collection.map { |s| "#{s.change_type.humanize}: #{slack_escape(s.reason.to_s.truncate(60))}" }
      when :observation_drafts
        collection.map { |o| observation_draft_label(o) }
      when :goals_needing_check_in
        collection.map { |goal| goal_check_in_label(goal) }
      when :check_ins_awaiting_input
        collection.map { |c| check_in_label(c) }
      else
        []
      end
    end

    def goal_check_in_label(goal)
      last_check_in = goal.goal_check_ins.recent.first
      time_ago = last_check_in ? "#{time_ago_in_words(last_check_in.created_at)} ago" : 'never'
      title = goal.title.to_s
      snippet = title.length > 40 ? "#{title[0, 40]}..." : title
      snippet = slack_escape(snippet).tr('|', '-') # Slack: escape &<> and use - for |
      url = Rails.application.routes.url_helpers.organization_goal_url(@organization, goal)
      "Last confidence check-in was #{time_ago} for: <#{url}|#{snippet}>"
    end

    def observation_draft_label(observation)
      story = observation.story.to_s
      snippet = story.length > 40 ? "#{story[0, 40]}..." : story
      snippet = slack_escape(snippet)
      url = Rails.application.routes.url_helpers.organization_observation_url(@organization, observation)
      "#{snippet} <#{url}|View>"
    end

    def check_in_label(check_in)
      subject = case check_in
                when AssignmentCheckIn then check_in.assignment&.title
                when AspirationCheckIn then check_in.aspiration&.name
                when PositionCheckIn then check_in.employment_tenure&.position&.display_name
                else nil
                end
      subject = slack_escape(subject.presence || 'Check-in')

      other_person = check_in.employee_completed? ? check_in.teammate&.person : check_in.manager_completed_by_teammate&.person
      completed_at = check_in.employee_completed? ? check_in.employee_completed_at : check_in.manager_completed_at
      other_name = slack_escape(other_person&.casual_name.presence || 'Someone')
      time_ago = completed_at ? "#{time_ago_in_words(completed_at)} ago" : '?'

      "#{subject} (#{other_name} checked-in #{time_ago})"
    end
  end
end
