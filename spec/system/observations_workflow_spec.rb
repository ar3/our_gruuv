require 'rails_helper'

RSpec.describe 'Observations Workflow', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
  end

  describe 'Observation creation workflow' do
    it 'loads observation creation page' do
        visit new_organization_observation_path(organization)

        expect(page).to have_content('Create Observation')
        expect(page).to have_content('Step 1 of 3')
        expect(page).to have_content('Who, When, What, How')
      end

    it 'shows teammate selection' do
        visit new_organization_observation_path(organization)

        expect(page).to have_content('Who are you observing?')
        expect(page).to have_content('John')
        expect(page).to have_content('john@example.com')
      end

    it 'shows story field' do
        visit new_organization_observation_path(organization)

        expect(page).to have_content('What happened?')
        expect(page).to have_field('observation_story')
        expect(page).to have_field('observation_story', placeholder: 'Tell the story of what happened... Be specific about what you observed and why it matters.')
      end

    it 'shows feeling selection' do
        visit new_organization_observation_path(organization)

        expect(page).to have_content('How did this make you feel?')
        expect(page).to have_field('observation_primary_feeling')
        expect(page).to have_content('Secondary feeling')
      end
    end

  describe 'Observation display and management' do
    let!(:observation) do
        create(:observation,
          observer: person,
          company: organization,
          story: 'John showed great leadership in the team meeting',
          privacy_level: 'observed_and_managers',
          observed_at: Date.current
        )
      end
    let!(:observee) { create(:observee, observation: observation, teammate: employee_teammate) }

    it 'shows observation details' do
        visit organization_observation_path(organization, observation)

        expect(page).to have_content('Observation Details')
        expect(page).to have_content('John showed great leadership in the team meeting')
        expect(page).to have_content('John')
      end

    it 'shows observation metadata' do
        visit organization_observation_path(organization, observation)

        expect(page).to have_content('Observer:')
        expect(page).to have_content('Observed:')
        expect(page).to have_content('Privacy:')
      end
    end

  describe 'Observation list and filtering' do
    let!(:observation1) do
        create(:observation,
          observer: person,
          company: organization,
          story: 'Great collaboration',
          privacy_level: 'public_observation',
          observed_at: 1.day.ago
        )
      end
    let!(:observation2) do
        create(:observation,
          observer: person,
          company: organization,
          story: 'Private notes',
          privacy_level: 'observer_only',
          observed_at: Date.current
        )
      end

    it 'shows observations list' do
        visit organization_observations_path(organization)

        expect(page).to have_content('Observations')
        expect(page).to have_content('Great collaboration')
        expect(page).to have_content('Private notes')
      end

    it 'shows observation details in list' do
        visit organization_observations_path(organization)

        expect(page).to have_content('Great collaboration')
        expect(page).to have_content('Private notes')
      end
    end

  describe 'Observation permissions' do
    let!(:non_manager) { create(:person, full_name: 'Regular Employee') }
    let!(:non_manager_teammate) { create(:teammate, person: non_manager, organization: organization, can_manage_employment: false) }

    it 'allows observation creation for all users' do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(non_manager)
        allow(non_manager).to receive(:can_manage_employment?).and_return(false)

        visit new_organization_observation_path(organization)

        expect(page).to have_content('Create Observation')
        # Should be able to create observations regardless of management status
      end
    end
  end
