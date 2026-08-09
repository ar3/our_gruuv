# frozen_string_literal: true

module ObjectMaintainersManagement
  extend ActiveSupport::Concern

  def show
    authorize @maintainable, :manage_maintainers?
    load_maintainers_page
    render template: "organizations/object_maintainers/show", layout: "overlay"
  end

  def update
    authorize @maintainable, :manage_maintainers?

    ObjectMaintainers::Updater.new(
      maintainable: @maintainable,
      actor: current_company_teammate,
      selected_teammate_ids: params[:maintainer_teammate_ids],
      unrestricted: unrestricted_maintainer_admin?
    ).call

    redirect_to maintainable_show_path, notice: "Maintainers were successfully updated."
  end

  private

  def load_maintainers_page
    organization = ObjectMaintainers::MaintainableOrganization.resolve(@maintainable)
    @candidate_teammates = CompanyTeammate.employed
      .where(organization: organization)
      .includes(:person)
      .joins(:person)
      .order("people.last_name ASC", "people.first_name ASC")
    @existing_maintainer_ids = @maintainable.object_maintainers.pluck(:company_teammate_id).to_set
    @can_manage_maintainers = true
    @unrestricted_maintainer_admin = unrestricted_maintainer_admin?
    @maintainable_label = maintainable_label
    @return_url = maintainable_show_path
    @return_text = "Back to #{@maintainable_label}"
    @update_path = maintainers_update_path
  end

  def unrestricted_maintainer_admin?
    return true if current_person&.admin? || current_person&.og_admin?

    current_company_teammate&.can_manage_maap?
  end
end
