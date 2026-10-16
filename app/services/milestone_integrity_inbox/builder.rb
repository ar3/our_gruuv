# frozen_string_literal: true

module MilestoneIntegrityInbox
  class Builder
    Item = Data.define(:id, :title, :subtitle, :url, :status_label)

    def self.call(...) = new(...).call

    def initialize(organization:, viewing_teammate:, routes: Rails.application.routes.url_helpers)
      @organization = organization
      @viewing_teammate = viewing_teammate
      @routes = routes
    end

    def call
      {
        skipped_awaiting_moderation: skipped_items,
        awaiting_cosign: awaiting_cosign_items,
        requires_cosign: requires_cosign_items
      }
    end

    private

    def base_scope
      MilestoneAward
        .joins(:teammate, :ability)
        .where(teammates: { organization_id: @organization.id })
        .includes(:teammate, :ability, :certifying_teammate)
    end

    def visible_awards(scope)
      scope.select { |award| can_see?(award) }
    end

    def can_see?(award)
      MilestoneAwards::ModeratorAuthorization.can_moderate?(
        teammate: @viewing_teammate,
        milestone_award: award
      )
    end

    def skipped_items
      visible_awards(base_scope.skipped_awaiting_moderation.order(awarder_skipped_cosign_at: :desc)).map do |award|
        item_for(award, status_label: "Skipped co-sign")
      end
    end

    def awaiting_cosign_items
      visible_awards(base_scope.pending_cosign.order(cosign_requested_at: :desc)).map do |award|
        item_for(award, status_label: "Awaiting co-sign")
      end
    end

    def requires_cosign_items
      visible_awards(base_scope.requires_cosign_after_moderation.order(moderator_requires_cosign_at: :desc)).map do |award|
        item_for(award, status_label: "Requires co-sign")
      end
    end

    def item_for(award, status_label:)
      recipient = award.teammate.person.display_name
      Item.new(
        id: award.id,
        title: "#{recipient} — #{award.ability.display_name} Milestone #{award.official_milestone_level}",
        subtitle: "Awarded by #{award.certifying_teammate.person.display_name}",
        url: @routes.organization_teammate_ability_milestone_award_path(
          @organization, award.teammate, award.ability, award
        ),
        status_label: status_label
      )
    end
  end
end
