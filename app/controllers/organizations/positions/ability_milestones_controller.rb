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
        load_assignment_milestone_locks

        abilities = Ability.unarchived
          .where(company: @position.company)
          .includes(:department)
          .to_a
          .sort_by { |a| [(a.department&.display_name || "Company-wide").downcase, a.name.to_s.downcase] }

        change_ids = (@existing_associations.keys + @assignment_milestone_locks.keys).uniq
        @associated_abilities = abilities.select { |a| change_ids.include?(a.id) }
        @available_abilities = abilities.reject { |a| change_ids.include?(a.id) }
      end

      # ability_id => { max_level:, level_assignment_titles: { level => [assignment titles] } }
      def load_assignment_milestone_locks
        @assignment_milestone_locks = {}

        @position.required_assignments.includes(assignment: :assignment_abilities).each do |position_assignment|
          assignment = position_assignment.assignment
          next unless assignment

          assignment.assignment_abilities.each do |assignment_ability|
            level = assignment_ability.milestone_level.to_i
            next unless (1..5).include?(level)

            lock = @assignment_milestone_locks[assignment_ability.ability_id] ||= {
              max_level: 0,
              level_assignment_titles: Hash.new { |h, k| h[k] = [] }
            }
            lock[:max_level] = [lock[:max_level], level].max
            (1..level).each do |locked_level|
              titles = lock[:level_assignment_titles][locked_level]
              titles << assignment.title unless titles.include?(assignment.title)
            end
          end
        end
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
