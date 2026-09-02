# frozen_string_literal: true

class Organizations::CoachInboxController < Organizations::OrganizationNamespaceBaseController
  include Organizations::CheckInsHealthTeammateFiltering

  before_action :require_authentication
  after_action :verify_authorized

  def show
    authorize @organization, :coach_inbox?
    apply_filter_default_if_needed

    teammates = filtered_teammates_for_check_ins_health.includes(:person).to_a
    @sections = CoachInbox::Builder.call(
      organization: @organization,
      teammates: teammates,
      expanded_subtype_keys: Array(params[:expand])
    )
    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = available_check_ins_health_manager_filter_options
    @total_outstanding = @sections.sum { |section| section.subtypes.sum(&:count) }
  end

  private

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access this page."
  end
end
