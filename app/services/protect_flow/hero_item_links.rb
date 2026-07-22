# frozen_string_literal: true

module ProtectFlow
  # Top unhealthy Engagement Health *items* for the hero vector — deep links to
  # the specific check-in / goal / ability / OGO surfaces (not the full One Thing carousel).
  class HeroItemLinks
    include Rails.application.routes.url_helpers

    LIMIT = 3

    def self.for_people(organization:, people:)
      new(organization: organization).for_people(people)
    end

    def initialize(organization:)
      @organization = organization
    end

    # Returns { teammate_id => [{ label:, path:, tooltip: }, ...] }
    def for_people(people)
      specs = people.filter_map do |person|
        category = person.dig(:hero, :category)
        next if category.blank? || category.to_s.in?(%w[maintain pending_health])

        { teammate_id: person[:teammate_id], category: category }
      end
      return {} if specs.empty?

      teammate_ids = specs.map { |s| s[:teammate_id] }.uniq
      categories = specs.map { |s| s[:category] }.uniq

      items_by_teammate_category = EngagementHealthStatus
        .items
        .where(organization: @organization, teammate_id: teammate_ids, category: categories)
        .group_by { |row| [row.teammate_id, row.category] }

      specs.each_with_object({}) do |spec, hash|
        key = [spec[:teammate_id], spec[:category]]
        rows = Array(items_by_teammate_category[key])
        hash[spec[:teammate_id]] = links_for_items(rows, category: spec[:category], teammate_id: spec[:teammate_id])
      end
    end

    private

    def links_for_items(rows, category:, teammate_id:)
      unhealthy = rows
        .reject { |row| row.status == EngagementHealth::HEALTHY }
        .sort_by do |row|
          [
            EngagementHealth.status_severity_rank(row.status),
            row.inputs.to_h["name"].to_s.downcase
          ]
        end
        .first(LIMIT)

      unhealthy.filter_map do |item|
        path = item_path(item, teammate_id: teammate_id)
        next if path.blank?

        label = item.inputs.to_h["name"].presence || EngagementHealth::CATEGORY_LABELS.fetch(category, "Item")
        {
          label: label.to_s,
          path: path,
          tooltip: "#{label} · #{EngagementHealth::STATUS_LABELS.fetch(item.status, item.status)}"
        }
      end
    end

    def item_path(item, teammate_id:)
      teammate = teammate_id # route helpers need the record or id; paths accept id
      case item.category
      when EngagementHealth::CATEGORY_OGO_GIVEN
        ogos_from_organization_company_teammate_path(@organization, teammate_id)
      when EngagementHealth::CATEGORY_OGO_RECEIVED
        ogos_organization_company_teammate_path(@organization, teammate_id)
      when EngagementHealth::CATEGORY_GOAL_CONFIDENCE
        return nil if item.entity_id.blank?

        organization_goal_path(@organization, item.entity_id)
      when EngagementHealth::CATEGORY_REQUIRED_CLARITY
        case item.entity_type.to_s
        when "Position"
          position_check_in_organization_teammate_path(@organization, teammate_id)
        when "Assignment"
          return nil if item.entity_id.blank?

          organization_teammate_assignment_path(@organization, teammate_id, item.entity_id)
        when "Aspiration"
          return nil if item.entity_id.blank?

          organization_teammate_aspiration_path(@organization, teammate_id, item.entity_id)
        end
      when EngagementHealth::CATEGORY_MILESTONES
        return nil if item.entity_id.blank?

        organization_teammate_ability_path(@organization, teammate_id, item.entity_id)
      end
    end
  end
end
