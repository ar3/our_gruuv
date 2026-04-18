# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'organizations/company_teammates/my_growth/_assignment_card_action_footer', type: :view do
  include MyGrowthExperiencesHelper
  include AssociableGoalsHelper

  let(:organization) { create(:organization) }
  let(:person) { create(:person, first_name: 'Sam', last_name: 'Kim') }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Ship Widgets') }
  let(:casual_name) { 'Sam K.' }
  let(:audit_allowed) { false }

  before do
    allow(view).to receive(:policy).with(teammate).and_return(instance_double(CompanyTeammatePolicy, audit?: audit_allowed))
    allow(view).to receive(:request).and_return(
      instance_double(ActionDispatch::Request, query_parameters: {})
    )
  end

  context 'when goal flow is not allowed' do
    it 'renders read-only goal half with tooltip and warning icon' do
      render partial: 'organizations/company_teammates/my_growth/assignment_card_action_footer',
             locals: {
               organization: organization,
               teammate: teammate,
               assignment: assignment,
               casual_name: casual_name,
               counts: { open_associated_goals_count: 0 }
             }

      expect(rendered).to include('assignment-card-action-footer__read-only-hit')
      expect(rendered).to match(/data-bs-toggle="tooltip"/)
      expect(rendered).to include('bi-exclamation-triangle')
      expect(rendered).to include('You need access as this teammate, their manager, or an employment administrator to set or link goals here.')
      expect(rendered).to include("Set goal for #{casual_name} &amp; #{assignment.title}")
    end

    it 'still renders an active OGO link' do
      render partial: 'organizations/company_teammates/my_growth/assignment_card_action_footer',
             locals: {
               organization: organization,
               teammate: teammate,
               assignment: assignment,
               casual_name: casual_name,
               counts: { open_associated_goals_count: 0 }
             }

      expect(rendered).to include('/observations/new')
      expect(rendered).to include('Add a win/challenge/note (OGO)')
    end
  end

  context 'when goal flow is allowed' do
    let(:audit_allowed) { true }

    it 'renders goal as a link, not disabled' do
      render partial: 'organizations/company_teammates/my_growth/assignment_card_action_footer',
             locals: {
               organization: organization,
               teammate: teammate,
               assignment: assignment,
               casual_name: casual_name,
               counts: { open_associated_goals_count: 2 }
             }

      expect(rendered).to include('choose_manage_goals')
      expect(rendered).to include("Add to the 2 active goals for #{casual_name} &amp; #{assignment.title}")
      expect(rendered).not_to include('bi-exclamation-triangle')
    end
  end
end
