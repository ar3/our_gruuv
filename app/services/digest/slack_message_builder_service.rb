# frozen_string_literal: true

module Digest
  # Builds Slack Block Kit payloads for the GSD digest: main message and two thread replies.
  # Uses company label for "Get shit done"; main message includes a link to configure the digest.
  class SlackMessageBuilderService
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
      casual_name = @teammate.person.casual_name
      total = @items[:total_pending].to_i
      gsd_page_url = Rails.application.routes.url_helpers.organization_get_shit_done_url(@organization)
      gsd_list_link = "<#{gsd_page_url}|#{@gsd_label} list>"

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
        { type: 'section', text: { type: 'mrkdwn', text: block_lines } },
        { type: 'context', elements: [{ type: 'mrkdwn', text: caption_text }] }
      ]
      { blocks: blocks, text: fallback_text }
    end

    def thread1_gsd_list
      all_clear = GSD_CATEGORY_LABELS.select { |key, _| category_count(key).zero? }.map(&:last)
      lines = []
      lines << "All clear: #{all_clear.join(', ')}." if all_clear.any?

      GSD_CATEGORY_LABELS.each do |key, label|
        next if category_count(key).zero?

        lines << "*#{label}*"
        item_lines = item_labels_for(key)
        item_lines.each { |line| lines << "  • #{line}" }
      end

      text = lines.join("\n").presence || "All categories are clear."
      blocks = [{ type: 'section', text: { type: 'mrkdwn', text: text } }]
      { blocks: blocks, text: text }
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

    def thread2_about_me
      lines = ["*Let's look at your About Me page.*", '']
      green_sections = @about_me_sections.select { |s| s[:status] == :green }.map { |s| s[:section_name] }
      lines << "Healthy: #{green_sections.join(', ')}." if green_sections.any?

      yellow_red = @about_me_sections.select { |s| s[:status] == :yellow || s[:status] == :red }
      if yellow_red.any?
        lines << '' if green_sections.any?
        yellow_red.each do |s|
          lines << "*#{s[:section_name]}*: #{s[:explanation_sentence]}"
        end
      end

      text = lines.join("\n")
      blocks = [{ type: 'section', text: { type: 'mrkdwn', text: text } }]
      { blocks: blocks, text: text }
    end

    private

    def digest_config_url_for_organization
      url = Rails.application.routes.url_helpers.edit_organization_digest_url(@organization)
      "<#{url}|Digest settings>"
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
        collection.map(&:display_name)
      when :maap_snapshots
        collection.map { |s| "#{s.change_type.humanize}: #{s.reason.to_s.truncate(60)}" }
      when :observation_drafts
        collection.map { |o| o.story.to_s.truncate(60) }
      when :goals_needing_check_in
        collection.map(&:title)
      when :check_ins_awaiting_input
        collection.map { |c| check_in_label(c) }
      else
        []
      end
    end

    def check_in_label(check_in)
      type = case check_in
             when AssignmentCheckIn then 'Assignment'
             when AspirationCheckIn then 'Aspirational Value'
             when PositionCheckIn then 'Position'
             else 'Check-in'
             end
      subject = case check_in
                when AssignmentCheckIn then check_in.assignment&.title
                when AspirationCheckIn then check_in.aspiration&.name
                when PositionCheckIn then check_in.employment_tenure&.position&.display_name
                else nil
                end
      subject.present? ? "#{type}: #{subject}" : type
    end
  end
end
