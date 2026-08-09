# frozen_string_literal: true

module ObjectMaintainers
  class Updater
    def initialize(maintainable:, actor:, selected_teammate_ids:, unrestricted:)
      @maintainable = maintainable
      @actor = actor
      @selected_teammate_ids = Array(selected_teammate_ids).map(&:to_i).reject(&:zero?).uniq
      @unrestricted = unrestricted
    end

    def call
      organization = MaintainableOrganization.resolve(@maintainable)
      raise ArgumentError, "maintainable has no organization" if organization.blank?

      allowable_ids = CompanyTeammate.employed.where(organization: organization).pluck(:id).to_set
      selected_ids = @selected_teammate_ids.select { |id| allowable_ids.include?(id) }.to_set
      current_ids = @maintainable.object_maintainers.pluck(:company_teammate_id).to_set

      unless @unrestricted
        # Peers can change other maintainers but cannot remove themselves.
        selected_ids << @actor.id if current_ids.include?(@actor.id)
      end

      to_add = selected_ids - current_ids
      to_remove = current_ids - selected_ids
      to_remove.delete(@actor.id) unless @unrestricted

      ObjectMaintainer.transaction do
        if to_remove.any?
          @maintainable.object_maintainers.where(company_teammate_id: to_remove.to_a).destroy_all
        end

        to_add.each do |teammate_id|
          @maintainable.object_maintainers.create!(
            company_teammate_id: teammate_id,
            added_by: @actor
          )
        end
      end

      true
    end
  end
end
