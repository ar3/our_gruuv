# frozen_string_literal: true

module Goals
  # Turns Goals index query/filter params into human-readable spotlight footer pills.
  # Accepts the same inputs the index filter engine uses; never returns raw ids / Type_123.
  class IndexFilterDisplay
    NON_FILTER_KEYS = %w[
      view sort direction spotlight page controller action organization_id id
      return_url return_text utf8 authenticity_token commit _method
      show_deleted show_completed
    ].freeze

    SPECIAL_OWNER_LABELS = {
      "everyone_in_company" => "Everyone in company",
      "created_by_me" => "Created by me",
      "my_relevant_goals" => "My relevant goals",
      "all_my_teams" => "All my teams",
      "my_department" => "My department goals",
      "my_employees" => "My employees' goals",
      "my_employees_hierarchy" => "My employees' goals (full hierarchy)"
    }.freeze

    GOAL_TYPE_LABELS = {
      "inspirational_objective" => "Inspirational Objective",
      "qualitative_key_result" => "Qualitative Key Result",
      "quantitative_key_result" => "Quantitative Key Result",
      "stepping_stone_activity" => "Stepping Stone Activity",
      "progressive_outcome" => "OG3 Progressive Outcome"
    }.freeze

    STATUS_LABELS = {
      "draft" => "Draft",
      "active" => "Active",
      "completed" => "Completed",
      "archived" => "Archived"
    }.freeze

    TIMEFRAME_LABELS = {
      "all" => "All timeframes",
      "now" => "Now",
      "next" => "Next",
      "later" => "Later"
    }.freeze

    Pill = Struct.new(:key, :label, keyword_init: true)

    def self.pills(params:, organization:)
      new(params: params, organization: organization).pills
    end

    def initialize(params:, organization:)
      @params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      @params = @params.with_indifferent_access
      @organization = organization
    end

    def pills
      result = []
      result.concat(owner_pills)
      result.concat(array_param_pills(:goal_type, GOAL_TYPE_LABELS, prefix: "Type"))
      result.concat(array_param_pills(:status, STATUS_LABELS, prefix: "Status"))
      result.concat(timeframe_pills)
      result.concat(prompt_pills)
      result.concat(leftover_pills)
      result
    end

    private

    def owner_pills
      keys = StructuralOwnerKeysFilter.normalize_keys(@params[:owner_keys])
      if keys.size > 1
        return keys.filter_map { |key| Pill.new(key: "owner_keys:#{key}", label: structural_owner_label(key)) }
      end

      owner_token = raw_owner_token
      return [] if owner_token.blank? || owner_token == "customized_view"

      if SPECIAL_OWNER_LABELS.key?(owner_token)
        return [Pill.new(key: "owner_id:#{owner_token}", label: SPECIAL_OWNER_LABELS[owner_token])]
      end

      label = structural_owner_label(owner_token) || teammate_owner_label(owner_token)
      return [] if label.blank?

      [Pill.new(key: "owner:#{owner_token}", label: label)]
    end

    def raw_owner_token
      if @params[:owner_id].present? && @params[:owner_id].to_s.include?("_") && @params[:owner_type].blank?
        return @params[:owner_id].to_s
      end

      type = @params[:owner_type].presence
      id = @params[:owner_id].presence
      return id.to_s if type.blank? && id.present?
      return nil if type.blank? || id.blank?

      prefix = type.to_s == "Organization" ? "Company" : type.to_s
      "#{prefix}_#{id}"
    end

    def structural_owner_label(token)
      prefix, id = token.to_s.split("_", 2)
      return nil if id.blank?

      case prefix
      when "Company"
        org = Organization.find_by(id: id)
        org ? "Company: #{org.display_name.presence || org.name}" : nil
      when "Department"
        dept = Department.find_by(id: id)
        dept ? "Department: #{dept.display_name.presence || dept.name}" : nil
      when "Team"
        team = Team.find_by(id: id)
        team ? "Team: #{team.display_name.presence || team.name}" : nil
      end
    end

    def teammate_owner_label(token)
      prefix, id = token.to_s.split("_", 2)
      return nil unless prefix == "CompanyTeammate" && id.present?

      teammate = CompanyTeammate.includes(:person).find_by(id: id)
      return nil unless teammate&.person

      name = teammate.person.casual_name.presence || teammate.person.display_name
      "Teammate: #{name}"
    end

    def array_param_pills(param_key, labels, prefix:)
      values = Array(@params[param_key]).flatten.map(&:to_s).reject(&:blank?).uniq
      values.filter_map do |value|
        text = labels[value] || value.humanize
        Pill.new(key: "#{param_key}:#{value}", label: "#{prefix}: #{text}")
      end
    end

    def timeframe_pills
      value = @params[:timeframe].presence
      return [] if value.blank? || value.to_s == "all"

      label = TIMEFRAME_LABELS[value.to_s] || value.to_s.humanize
      [Pill.new(key: "timeframe:#{value}", label: "Timeframe: #{label}")]
    end

    def prompt_pills
      prompt_id = @params[:prompt_id].presence
      return [] if prompt_id.blank?

      prompt = Prompt.find_by(id: prompt_id)
      title = prompt&.prompt_template&.title
      label = title.present? ? "Prompt: #{title}" : "Prompt filter"
      [Pill.new(key: "prompt_id:#{prompt_id}", label: label)]
    end

    def leftover_pills
      known = %w[owner_id owner_type owner_keys goal_type status timeframe prompt_id] + NON_FILTER_KEYS
      @params.each_with_object([]) do |(key, value), pills|
        key_s = key.to_s
        next if known.include?(key_s) || key_s.start_with?("owner_keys")
        next if value.blank?

        Array(value).flatten.map(&:to_s).reject(&:blank?).each do |item|
          next if item.match?(/\A\d+\z/) && key_s.end_with?("_id")

          pills << Pill.new(key: "#{key_s}:#{item}", label: "#{key_s.humanize}: #{item.humanize}")
        end
      end
    end
  end
end
