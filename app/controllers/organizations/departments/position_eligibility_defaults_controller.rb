# frozen_string_literal: true

module Organizations
  module Departments
    class PositionEligibilityDefaultsController < Organizations::OrganizationNamespaceBaseController
      before_action :authenticate_person!
      before_action :set_department
      before_action :authorize_show!, only: [:show]
      before_action :authorize_maap!, only: [:edit_minor, :update_minor]

      def show
        load_minor_rows(@department)
      end

      def edit_minor
        @minor = minor_param
        record = @department.public_send("minor_#{@minor}_position_eligibility_requirement")
        @eligibility_data = record&.to_eligibility_service_hash || {}
        @minimum_mileage_from_assignments = 0
        @mileage_id_suffix = "_dept_#{@department.id}_#{@minor}"
      end

      def update_minor
        @minor = minor_param
        eligibility_params = params[:eligibility_requirements]&.permit! || {}
        result = EligibilityRequirements::PersistMinorOnOwner.call!(
          owner: @department,
          minor: @minor,
          eligibility_params: eligibility_params,
          minimum_mileage_floor: nil
        )

        if result.errors.any?
          @eligibility_data = eligibility_params.to_h.deep_stringify_keys
          @minimum_mileage_from_assignments = 0
          @mileage_id_suffix = "_dept_#{@department.id}_#{@minor}"
          flash[:alert] = "Validation errors: #{result.errors.join('; ')}"
          render :edit_minor, status: :unprocessable_entity
        else
          redirect_to organization_department_position_eligibility_defaults_path(@organization, @department),
                      notice: "Eligibility defaults for minor #{@minor} were updated."
        end
      end

      private

      def set_department
        @department = Department.find_by_param(params[:department_id])
        raise ActiveRecord::RecordNotFound unless @department
        raise ActiveRecord::RecordNotFound unless @department.company_id == @organization.id
      end

      def authorize_show!
        authorize @department, :show?
      end

      def authorize_maap!
        authorize @organization, :manage_maap?
      end

      def minor_param
        m = params[:minor].to_i
        raise ActiveRecord::RecordNotFound unless (1..3).cover?(m)

        m
      end

      def load_minor_rows(dept)
        @minor_rows = (1..3).map do |minor|
          {
            minor: minor,
            requirement: dept.public_send("minor_#{minor}_position_eligibility_requirement")
          }
        end
      end
    end
  end
end
