# frozen_string_literal: true

module Organizations
  module Teams
    class AssignmentNeedsController < Organizations::OrganizationNamespaceBaseController
      before_action :require_authentication
      before_action :set_team
      before_action :set_need, only: [:manage_coverers, :update_coverers]

      def manage_coverers
        authorize @team, :update?
        load_coverer_selection_data
      end

      def update_coverers
        authorize @team, :update?

        coverer_ids = Array(params[:coverer_ids]).reject(&:blank?).map(&:to_i)
        ::Teams::AssignmentCoverersSync.new(need: @need, coverer_ids: coverer_ids).call

        redirect_to organization_team_path(@organization, @team), notice: "Updated who is taking on #{@need.assignment.title} for the team."
      end

      private

      def set_team
        id_from_params = params[:team_id].to_s.split("-").first.to_i
        @team = Team.for_company(@organization).active.find(id_from_params)
      end

      def set_need
        @need = @team.team_assignment_needs.includes(:assignment).find(params[:id])
      end

      def load_coverer_selection_data
        @assignment = @need.assignment
        team_member_ids = @team.team_members.pluck(:company_teammate_id).to_set
        @selected_coverer_ids = @need.team_assignment_coverers.pluck(:company_teammate_id).to_set

        teammates = @organization.teammates
          .joins(:person)
          .includes(:person, employment_tenures: { position: { title: :department } })
          .merge(CompanyTeammate.employed)
          .order(Arel.sql("people.last_name, COALESCE(people.preferred_name, people.first_name)"))

        team_member_teammates = teammates.select { |teammate| team_member_ids.include?(teammate.id) }
        @other_teammates = teammates.reject { |teammate| team_member_ids.include?(teammate.id) }

        assignment_tenure_holder_ids = AssignmentTenure.active
          .where(assignment: @assignment)
          .pluck(:teammate_id)
          .to_set

        @team_member_teammates_with_assignment = team_member_teammates.select do |teammate|
          assignment_tenure_holder_ids.include?(teammate.id)
        end
        @team_member_teammates_without_assignment = team_member_teammates.reject do |teammate|
          assignment_tenure_holder_ids.include?(teammate.id)
        end
      end

      def require_authentication
        unless current_person
          redirect_to root_path, alert: "Please log in to access teams."
        end
      end
    end
  end
end
