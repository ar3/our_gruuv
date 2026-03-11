# frozen_string_literal: true

class Organizations::StartHereController < Organizations::OrganizationNamespaceBaseController
  # Minimal controller for a fast landing page: no heavy queries.
  def show
    authorize current_organization, :show?
  end
end
