# frozen_string_literal: true

module Teams
  class AssignmentCoverersSync
    def initialize(need:, coverer_ids:)
      @need = need
      @coverer_ids = coverer_ids
    end

    def call
      company = @need.team.company
      valid_coverer_ids = company.teammates.employed.where(id: @coverer_ids).pluck(:id)

      ActiveRecord::Base.transaction do
        @need.team_assignment_coverers.where.not(company_teammate_id: valid_coverer_ids).destroy_all

        valid_coverer_ids.each do |coverer_id|
          @need.team_assignment_coverers.find_or_create_by!(company_teammate_id: coverer_id)
        end
      end
    end
  end
end
