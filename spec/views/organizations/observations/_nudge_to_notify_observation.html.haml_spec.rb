require 'rails_helper'

RSpec.describe 'organizations/observations/_nudge_to_notify_observation', type: :view do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person, first_name: 'Observer', last_name: 'Person') }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person, first_name: 'Observed', last_name: 'Person') }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company, privacy_level: :observed_only)
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs.publish!
    obs
  end
  let(:observer_ledger) { create(:kudos_points_ledger, company_teammate: observer_teammate, organization: company, points_to_give: 25.0, points_to_spend: 0) }
  let(:observees_for_kudos) { [{ person: observee_person, role: 'Observed' }] }

  before do
    assign(:observation, observation)
    assign(:organization, company)
    assign(:observee_names, [observee_person.casual_name])
    assign(:direct_manager_names, [])
    assign(:other_manager_names, [])
    assign(:kudos_channel_organizations, [])
    assign(:available_teammates_for_notification, [])
    allow(view).to receive(:policy).and_return(double(post_to_slack?: true))
    allow(view).to receive(:render).and_call_original
    allow(view).to receive(:render).with('organizations/observations/form_sections/privacy_selector', anything).and_return('')
    allow(view).to receive(:render).with('page_visit_stats').and_return('')
    allow(view).to receive(:share_publicly_organization_observation_path).and_return("#")
    allow(view).to receive(:share_privately_organization_observation_path).and_return("#")
    allow(view).to receive(:award_kudos_organization_observation_path).and_return("/organizations/#{company.id}/observations/#{observation.id}/award_kudos")
    allow(view).to receive(:kudos_points_display).with(25.0).and_return('25.0 points ($2.50)')
    allow(view).to receive(:company_label_plural).with('kudos_point', 'Kudos Point').and_return('Kudos Points')
    allow(view).to receive(:company_label_for).with('kudos_point', 'Kudos Point').and_return('Kudos Point')
  end

  context 'when points row is shown (observees_for_kudos present, kudos_not_yet_awarded, observer_ledger set)' do
    before do
      assign(:observees_for_kudos, observees_for_kudos)
      assign(:kudos_not_yet_awarded, true)
      assign(:observer_ledger, observer_ledger)
      assign(:observation_kudos_awards, [])
    end

    it 'shows the two optional steps intro' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to include('Two optional steps')
      expect(rendered).to include('decide if any points will be awarded')
      expect(rendered).to include('announce via Slack')
    end

    it 'shows Award points (optional) heading' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to include('Award points (optional)')
    end

    it 'shows the recognition sentence with observee names, observer, and reward copy' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to include(observee_person.casual_name)
      expect(rendered).to include(observer.casual_name)
      expect(rendered).to include('were recognized in a story retold by')
      expect(rendered).to include('could reward up to')
      expect(rendered).to include('25')
    end

    it 'links observee and observer names to their profile, opening in a new window' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to have_css('a[target="_blank"][rel="noopener noreferrer"]', minimum: 2) # observee + observer (twice)
      expect(rendered).to include('href="/people/')
    end

    it 'shows observer balance and Points to give input' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to include('Your banked Kudos Points to give')
      expect(rendered).to include('25.0 points ($2.50)')
      expect(rendered).to include('Kudos Points to give')
      expect(rendered).to have_css('input[name="points_to_give"]')
    end

    it 'shows Send Kudos Points button with confirm message' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to include('Send Kudos Points')
      expect(rendered).to include("Are you sure")
    end

    it 'has form that posts to award_kudos path' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to have_css("form[action*='award_kudos']")
    end
  end

  context 'when multiple observees' do
    let(:observee2_person) { create(:person, first_name: 'Second', last_name: 'Person') }
    let(:observee2_teammate) { create(:teammate, person: observee2_person, organization: company) }
    let(:observation_two) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :observed_only)
      obs.observees.build(teammate: observee_teammate)
      obs.observees.build(teammate: observee2_teammate)
      obs.save!
      obs.publish!
      obs
    end
    let(:observees_for_kudos_two) { [{ person: observee_person, role: 'Observed' }, { person: observee2_person, role: 'Observed' }] }

    before do
      assign(:observation, observation_two)
      assign(:observees_for_kudos, observees_for_kudos_two)
      assign(:kudos_not_yet_awarded, true)
      assign(:observer_ledger, observer_ledger)
      assign(:observation_kudos_awards, [])
    end

    it 'shows split equally message' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to include('split equally between the observees')
    end
  end

  context 'when kudos_not_yet_awarded is false (points already awarded)' do
    let(:observation_kudos_awards) { [{ person: observee_person, points: 12.5 }] }

    before do
      assign(:observees_for_kudos, observees_for_kudos)
      assign(:kudos_not_yet_awarded, false)
      assign(:observer_ledger, observer_ledger)
      assign(:observation_kudos_awards, observation_kudos_awards)
    end

    it 'does not show the award form' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).not_to include('Award points (optional)')
      expect(rendered).not_to include('Send points')
    end

    it 'still shows Observation summary (awards are shown in Spotlight section below)' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to include('Observation summary')
    end
  end
end
