# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'organizations/company_teammates/my_growth/_my_growth_catalog_card_action_footer', type: :view do
  include MyGrowthExperiencesHelper
  include AssociableGoalsHelper

  let(:organization) { create(:organization) }
  let(:person) { create(:person, first_name: 'Sam', last_name: 'Kim') }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Ship Widgets') }
  let(:casual_name) { 'Sam K.' }
  let(:return_url) { '/growth' }
  let(:return_text) { 'Grow by experiences' }
  let(:audit_allowed) { false }

  before do
    allow(view).to receive(:policy).with(teammate).and_return(instance_double(CompanyTeammatePolicy, audit?: audit_allowed))
    allow(view).to receive(:request).and_return(
      instance_double(ActionDispatch::Request, query_parameters: {})
    )
  end

  context 'when goal flow is not allowed' do
    it 'renders read-only goal half with tooltip and warning icon' do
      render partial: 'organizations/company_teammates/my_growth/my_growth_catalog_card_action_footer',
             locals: {
               organization: organization,
               teammate: teammate,
               associable: assignment,
               casual_name: casual_name,
               counts: { open_associated_goals_count: 0, open_associated_goals: [] },
               return_url: return_url,
               return_text: return_text
             }

      expect(rendered).to include('assignment-card-action-footer__read-only-hit')
      expect(rendered).to match(/data-bs-toggle="tooltip"/)
      expect(rendered).to include('bi-exclamation-triangle')
      expect(rendered).to include('You need access as this teammate, their manager, or an employment administrator to set or link goals here.')
      expect(rendered).to include("Set goal for #{casual_name} &amp; #{assignment.title}")
    end

    it 'still renders an active OGO link' do
      render partial: 'organizations/company_teammates/my_growth/my_growth_catalog_card_action_footer',
             locals: {
               organization: organization,
               teammate: teammate,
               associable: assignment,
               casual_name: casual_name,
               counts: { open_associated_goals_count: 0, open_associated_goals: [] },
               return_url: return_url,
               return_text: return_text
             }

      expect(rendered).to include('/observations/new')
      expect(rendered).to include('Add a win/challenge/note (OGO)')
    end

    it 'shows goals popover when open goals exist' do
      open_goals = [
        { title: 'First linked goal', confidence_percentage: 75, confidence_saved_at: Time.zone.parse('2026-03-12') },
        { title: 'Second linked goal', confidence_percentage: nil, confidence_saved_at: nil }
      ]

      render partial: 'organizations/company_teammates/my_growth/my_growth_catalog_card_action_footer',
             locals: {
               organization: organization,
               teammate: teammate,
               associable: assignment,
               casual_name: casual_name,
               counts: { open_associated_goals_count: 2, open_associated_goals: open_goals },
               return_url: return_url,
               return_text: return_text
             }

      expect(rendered).to match(/data-bs-toggle="popover"/)
      expect(rendered).to include('First linked goal')
      expect(rendered).to include('75% as of')
      expect(rendered).to include('Second linked goal')
      expect(rendered).to include('no confidence yet')
      expect(rendered).to include("to see all of the goals, click on the #{assignment.title} name link above")
      expect(rendered).to include('You need access as this teammate, their manager, or an employment administrator to set or link goals here.')
    end
  end

  context 'when goal flow is allowed' do
    let(:audit_allowed) { true }

    it 'renders goal as a link, not disabled' do
      render partial: 'organizations/company_teammates/my_growth/my_growth_catalog_card_action_footer',
             locals: {
               organization: organization,
               teammate: teammate,
               associable: assignment,
               casual_name: casual_name,
               counts: { open_associated_goals_count: 2, open_associated_goals: [] },
               return_url: return_url,
               return_text: return_text
             }

      expect(rendered).to include('choose_manage_goals')
      expect(rendered).to include("Add to the 2 active goals for #{casual_name} &amp; #{assignment.title}")
      expect(rendered).not_to include('bi-exclamation-triangle')
    end

    it 'attaches goals popover on the goal link when open goals are present' do
      open_goals = [
        { title: 'Ship onboarding', confidence_percentage: 80, confidence_saved_at: Time.zone.parse('2026-03-12') }
      ]

      render partial: 'organizations/company_teammates/my_growth/my_growth_catalog_card_action_footer',
             locals: {
               organization: organization,
               teammate: teammate,
               associable: assignment,
               casual_name: casual_name,
               counts: { open_associated_goals_count: 1, open_associated_goals: open_goals },
               return_url: return_url,
               return_text: return_text
             }

      expect(rendered).to include('choose_manage_goals')
      expect(rendered).to match(/data-bs-toggle="popover"/)
      expect(rendered).to include('Ship onboarding')
      expect(rendered).to include('80% as of')
      expect(rendered).to include("to see all of the goals, click on the #{assignment.title} name link above")
    end
  end
end
