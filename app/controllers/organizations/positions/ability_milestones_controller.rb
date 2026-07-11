# frozen_string_literal: true

module Organizations
  module Positions
    class AbilityMilestonesController < Organizations::PositionsController
      skip_before_action :set_position, only: [:show, :update]
      before_action :set_position_for_ability_milestones, only: [:show, :update]
      after_action :verify_authorized

      def show
        authorize @position
        load_existing_associations
        load_abilities_for_milestones
        @form = PositionAbilityMilestonesForm.new(@position)
        render layout: determine_layout
      end

      def update
        authorize @position, :update?

        @form = PositionAbilityMilestonesForm.new(@position)

        if @form.validate(ability_milestones_params) && @form.save
          redirect_to organization_position_path(@organization, @position),
                      notice: 'Direct milestone requirements were successfully updated.'
        else
          load_existing_associations
          load_abilities_for_milestones
          render :show, status: :unprocessable_entity
        end
      end

      private

      def set_position_for_ability_milestones
        @position = @organization.positions.find(params[:position_id])
      end

      def load_abilities_for_milestones
        abilities = Ability.unarchived
          .where(company: @position.company)
          .includes(:department)
          .to_a
          .sort_by { |a| [(a.department&.display_name || "Company-wide").downcase, a.name.to_s.downcase] }

        associated_ids = @existing_associations.keys
        @associated_abilities = abilities.select { |a| associated_ids.include?(a.id) }
        @available_abilities = abilities.reject { |a| associated_ids.include?(a.id) }
      end

      def load_existing_associations
        @existing_associations = {}
        @position.position_abilities.includes(:ability).each do |pa|
          @existing_associations[pa.ability_id] = pa.milestone_level
        end
      end

      def ability_milestones_params
        form_params = params.require(:position_ability_milestones_form).permit(ability_milestones: {})
        # Ensure ability_milestones is a hash (Rails may send it as an ActionController::Parameters)
        if form_params[:ability_milestones].present?
          { ability_milestones: form_params[:ability_milestones].to_h }
        else
          { ability_milestones: {} }
        end
      end
    end
  end
end
