# frozen_string_literal: true

# Person-scoped home. Allowed with or without a CompanyTeammate.
# Org-namespaced controllers must continue to use authenticate_person! (teammate required).
class MeController < ApplicationController
  before_action :authenticate_person_only!

  def show
    @person = current_person
    @teammates = @person.company_teammates.includes(:organization).order(:id)
    teammate_org_ids = @teammates.map(&:organization_id)
    @ogos_given_outside_teammate_orgs = Observation
      .published
      .where(observer: @person)
      .where("deleted_at IS NULL")
      .then { |scope| teammate_org_ids.any? ? scope.where.not(company_id: teammate_org_ids) : scope }
      .includes(:company, :observed_teammates)
      .order(published_at: :desc)
      .limit(50)
    @continue_public_feedback_request = continue_public_feedback_request
  end

  private

  def continue_public_feedback_request
    token = flash[:continue_public_feedback_token].presence
    return if token.blank?

    fr = FeedbackRequest.find_by(public_answer_token: token)
    return unless fr&.open_to_public? && fr.answerable?

    fr
  end

  def determine_layout
    current_company_teammate ? 'authenticated-vertical-navigation' : 'application'
  end
end
