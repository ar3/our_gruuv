# frozen_string_literal: true

module Goals
  # Create mode "expand now": parent container + Commit / Stretch / Transform children.
  class ExpandProgressiveOutcome
    Result = Struct.new(:ok?, :parent, :children, :error, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(organization:, current_person:, current_teammate:, attrs:)
      @organization = organization
      @current_person = current_person
      @current_teammate = current_teammate
      raw = if attrs.respond_to?(:to_unsafe_h)
        attrs.to_unsafe_h
      elsif attrs.respond_to?(:to_h)
        attrs.to_h
      else
        attrs
      end
      @attrs = raw.with_indifferent_access
    end

    def call
      title = @attrs[:title].to_s.strip
      return failure("Title is required") if title.blank?

      parsed = ProgressiveOutcomeProse.parse(title)
      company = @organization.root_company || @organization
      parent = nil
      children = []
      default_date = @attrs[:most_likely_target_date].presence || (Date.today + 90.days)

      PaperTrail.request.whodunnit = @current_teammate.id.to_s

      ActiveRecord::Base.transaction do
        parent = create_goal(
          company: company,
          title: parent_title(title, parsed),
          goal_type: "inspirational_objective",
          description: @attrs[:description],
          owner_id: owner_value,
          privacy_level: privacy,
          most_likely_target_date: @attrs[:most_likely_target_date],
          earliest_target_date: @attrs[:earliest_target_date],
          latest_target_date: @attrs[:latest_target_date]
        )
        raise ActiveRecord::Rollback unless parent&.persisted?

        {
          "commit" => parsed.commit,
          "stretch" => parsed.stretch,
          "transform" => parsed.transform
        }.each do |aim, value|
          next if value.nil?

          child_title = child_title_for(aim, value, parsed)
          child = create_goal(
            company: company,
            title: child_title,
            goal_type: "quantitative_key_result",
            description: @attrs[:description],
            owner_id: owner_value,
            privacy_level: privacy,
            most_likely_target_date: default_date,
            earliest_target_date: @attrs[:earliest_target_date],
            latest_target_date: @attrs[:latest_target_date],
            outcome_baseline: parsed.baseline,
            outcome_commit: (aim == "commit" ? value : nil),
            outcome_stretch: (aim == "stretch" ? value : nil),
            outcome_transform: (aim == "transform" ? value : nil),
            outcome_unit: parsed.unit,
            progressive_current_aim: aim
          )
          raise ActiveRecord::Rollback unless child&.persisted?

          link = GoalLink.new(parent_id: parent.id, child_id: child.id, metadata: {
            "progressive_expand" => true,
            "aim" => aim
          })
          unless link.save
            raise ActiveRecord::Rollback
          end

          children << child
        end

        raise ActiveRecord::Rollback if children.empty?
      end

      return failure("Could not expand Progressive Outcome") if parent.nil? || !parent.persisted? || children.empty?

      EngagementHealth.schedule_refresh_for_goal(parent)
      children.each { |c| EngagementHealth.schedule_refresh_for_goal(c) }

      Result.new(ok?: true, parent: parent, children: children, error: nil)
    end

    private

    def create_goal(company:, title:, goal_type:, **extra)
      goal = Goal.new(company: company)
      form = GoalForm.new(goal)
      form.current_person = @current_person
      form.current_teammate = @current_teammate

      payload = {
        title: title,
        goal_type: goal_type,
        description: extra[:description].to_s,
        owner_id: extra[:owner_id],
        privacy_level: extra[:privacy_level],
        edit_check_in_permission: "anyone_who_can_view",
        most_likely_target_date: extra[:most_likely_target_date],
        earliest_target_date: extra[:earliest_target_date],
        latest_target_date: extra[:latest_target_date]
      }

      return nil unless form.validate(payload) && form.save

      goal.update!(
        outcome_baseline: extra[:outcome_baseline],
        outcome_commit: extra[:outcome_commit],
        outcome_stretch: extra[:outcome_stretch],
        outcome_transform: extra[:outcome_transform],
        outcome_unit: extra[:outcome_unit],
        progressive_current_aim: extra[:progressive_current_aim]
      )
      goal
    end

    def owner_value
      @attrs[:owner_id].presence || "CompanyTeammate_#{@current_teammate.id}"
    end

    def privacy
      @attrs[:privacy_level].presence || begin
        type = owner_value.to_s.split("_", 2).first
        case type
        when "Team", "Department", "Company", "Organization"
          "everyone_in_company"
        else
          "only_creator_owner_and_managers"
        end
      end
    end

    def parent_title(title, parsed)
      unit = parsed.unit.presence || "%"
      baseline = parsed.baseline
      return title if baseline.nil?

      # Prefer a clean objective-style parent title without C/S/T ladder detail.
      if title.match?(/from\s+/i)
        cleaned = title.sub(/\s+to\s+.+\z/i, "").strip
        return cleaned if cleaned.present?
      end

      title
    end

    def child_title_for(aim, value, parsed)
      unit = parsed.unit.presence || "%"
      baseline = parsed.baseline
      target = format_num(value)
      if baseline
        "#{aim.capitalize}: from #{format_num(baseline)}#{unit} to #{target}#{unit}"
      else
        "#{aim.capitalize}: #{target}#{unit}"
      end
    end

    def format_num(value)
      f = value.to_f
      f == f.to_i ? f.to_i.to_s : value.to_s
    end

    def failure(message)
      Result.new(ok?: false, parent: nil, children: [], error: message)
    end
  end
end
