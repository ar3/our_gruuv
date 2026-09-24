# frozen_string_literal: true

class Organizations::MaapCleanupInboxController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def show
    authorize @organization, :maap_cleanup_inbox?

    @sections = MaapCleanupInbox::Builder.call(
      organization: @organization,
      expanded_subtype_keys: Array(params[:expand])
    )
    @total_outstanding = @sections.sum { |section| section.subtypes.sum(&:count) }
  end

  private

  def require_authentication
    return if current_person

    redirect_unauthenticated_to_login!(message: "Please log in to access this page.", flash_key: :alert)
  end
end
