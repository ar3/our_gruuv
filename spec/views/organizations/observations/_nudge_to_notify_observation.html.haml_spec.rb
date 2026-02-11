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
  let(:observer_ledger) { create(:kudos_points_ledger, company_teammate: observer_teammate, organization: company, points_to_give: 25, points_to_spend: 0) }
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
    allow(view).to receive(:kudos_points_display).with(25).and_return('25 Kudos Points')
    allow(view).to receive(:company_label_plural).with('kudos_point', 'Kudos Point').and_return('Kudos Points')
    allow(view).to receive(:company_label_for).with('kudos_point', 'Kudos Point').and_return('Kudos Point')
  end

  context 'when points row is shown (observees_for_kudos, kudos_not_yet_awarded, observer_ledger, positive_rating_reward_options)' do
    let(:ability) { create(:ability, company: company) }
    let(:positive_rating) { create(:observation_rating, :agree, observation: observation, rateable: ability) }
    let(:positive_rating_reward_options) do
      [{ rating: positive_rating, label: 'A Solid demonstration of ' + ability.name, rating_kind: :solid, min: 5, max: 25, point_options: (5..25).to_a }]
    end

    before do
      assign(:observees_for_kudos, observees_for_kudos)
      assign(:kudos_not_yet_awarded, true)
      assign(:observer_ledger, observer_ledger)
      assign(:observation_kudos_awards, [])
      assign(:positive_rating_reward_options, positive_rating_reward_options)
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

    it 'shows observer balance and per-rating reward toggle and points dropdown' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to include('Your banked Kudos Points to give')
      expect(rendered).to include('25 Kudos Points')
      expect(rendered).to include('Reward this rating')
      expect(rendered).to have_css('input[type="checkbox"][name^="award_by_rating"]')
      expect(rendered).to have_css('select[name^="award_by_rating"]')
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

  context 'when organization has kudos points disabled' do
    let(:ability) { create(:ability, company: company) }
    let(:positive_rating) { create(:observation_rating, :agree, observation: observation, rateable: ability) }
    let(:positive_rating_reward_options) do
      [{ rating: positive_rating, label: 'A Solid demonstration of ' + ability.name, rating_kind: :solid, min: 5, max: 25, point_options: (5..25).to_a }]
    end

    before do
      company.update!(kudos_points_economy_config: (company.kudos_points_economy_config || {}).merge('disable_kudos_points' => 'true'))
      assign(:organization, company)
      assign(:observees_for_kudos, observees_for_kudos)
      assign(:kudos_not_yet_awarded, true)
      assign(:observer_ledger, observer_ledger)
      assign(:observation_kudos_awards, [])
      assign(:positive_rating_reward_options, positive_rating_reward_options)
    end

    it 'disables peer-to-peer points checkboxes, selects, and Send button and shows warning tooltip' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to have_css('input[type="checkbox"][name^="award_by_rating"][disabled]')
      expect(rendered).to have_css('select[name^="award_by_rating"][disabled]')
      expect(rendered).to have_css('input[type="submit"][value*="Send"][disabled]')
      expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning[data-bs-toggle="tooltip"]')
      expect(rendered).to include(company.name)
      expect(rendered).to include('has not yet configured the Kudos Points system')
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
    let(:ability_two) { create(:ability, company: company) }
    let!(:positive_rating_two) { create(:observation_rating, :agree, observation: observation_two, rateable: ability_two) }
    let(:positive_rating_reward_options_two) do
      [{ rating: positive_rating_two, label: 'A Solid demonstration of ' + ability_two.name, rating_kind: :solid, min: 5, max: 25, point_options: (5..25).to_a }]
    end

    before do
      assign(:observation, observation_two)
      assign(:observees_for_kudos, observees_for_kudos_two)
      assign(:kudos_not_yet_awarded, true)
      assign(:observer_ledger, observer_ledger)
      assign(:observation_kudos_awards, [])
      assign(:positive_rating_reward_options, positive_rating_reward_options_two)
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

  context 'when observation has observable moment with celebratory bank config (not already awarded)' do
    let(:observable_moment) { create(:observable_moment, :birthday, company: company, primary_potential_observer: observer_teammate) }
    let(:observation_with_moment) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :observed_only, observable_moment: observable_moment)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
      obs
    end
    let(:bank_point_options) do
      give_opts = (0..100).step(0.5).to_a.map { |n| n == n.to_i ? n.to_i.to_f : n }
      spend_opts = (0..100).step(0.5).to_a.map { |n| n == n.to_i ? n.to_i.to_f : n }
      { points_to_give_options: give_opts, points_to_spend_options: spend_opts, max_points_to_give: 100.0, max_points_to_spend: 100.0 }
    end

    before do
      assign(:observation, observation_with_moment)
      assign(:organization, company)
      assign(:celebratory_bank_config, { points_to_give: 100.0, points_to_spend: 100.0 })
      assign(:celebratory_bank_already_awarded, false)
      assign(:celebratory_bank_point_options, bank_point_options)
      allow(view).to receive(:award_celebratory_kudos_organization_observation_path).with(company, observation_with_moment).and_return("/organizations/#{company.id}/observations/#{observation_with_moment.id}/award_celebratory_kudos")
    end

    it 'shows the org bank section heading' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to include('Bank awards up to the following points for this observable moment')
      expect(rendered).to include(company.name)
    end

    it 'shows dropdowns and Award from Bank button' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).to include('Points to give')
      expect(rendered).to include('Points to redeem')
      expect(rendered).to include("Award from #{company.name} Bank")
      expect(rendered).to have_css('form[action*="award_celebratory_kudos"]', count: 1)
    end

    context 'when organization has kudos points disabled' do
      before do
        company.update!(kudos_points_economy_config: (company.kudos_points_economy_config || {}).merge('disable_kudos_points' => 'true'))
        assign(:organization, company)
      end

      it 'disables celebratory bank dropdowns and button and shows warning tooltip' do
        render partial: 'organizations/observations/nudge_to_notify_observation'
        expect(rendered).to have_css('select[name="points_to_give"][disabled]')
        expect(rendered).to have_css('select[name="points_to_spend"][disabled]')
        expect(rendered).to have_css('input[type="submit"][value*="Award from"][disabled]')
        expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning[data-bs-toggle="tooltip"]')
        expect(rendered).to include(company.name)
        expect(rendered).to include('has not yet configured the Kudos Points system')
      end
    end
  end

  context 'when celebratory_bank_already_awarded is true' do
    let(:observable_moment) { create(:observable_moment, :birthday, company: company, primary_potential_observer: observer_teammate) }
    let(:observation_with_moment) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :observed_only, observable_moment: observable_moment)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
      obs
    end

    before do
      assign(:observation, observation_with_moment)
      assign(:celebratory_bank_config, { points_to_give: 100.0, points_to_spend: 100.0 })
      assign(:celebratory_bank_already_awarded, true)
    end

    it 'does not show the org bank award section' do
      render partial: 'organizations/observations/nudge_to_notify_observation'
      expect(rendered).not_to include('Award from')
      expect(rendered).not_to include('award_celebratory_kudos')
    end
  end
end
