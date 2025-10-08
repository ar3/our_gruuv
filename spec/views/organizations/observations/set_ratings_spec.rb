require 'rails_helper'

RSpec.describe 'organizations/observations/set_ratings', type: :view do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:observee2) { create(:teammate, organization: company) }
  let(:ability1) { create(:ability, organization: company, name: 'Ruby Programming') }
  let(:ability2) { create(:ability, organization: company, name: 'JavaScript') }
  let(:assignment1) { create(:assignment, company: company, title: 'Frontend Development') }
  let(:assignment2) { create(:assignment, company: company, title: 'Backend Development') }

  before do
    allow(view).to receive(:current_person).and_return(observer)
    allow(view).to receive(:organization).and_return(company)
    observer_teammate # Ensure observer teammate is created
  end

  describe 'rendering with various observation_ratings_attributes data types' do
    context 'when observation_ratings_attributes is nil' do
      it 'renders without errors' do
        @observation = company.observations.build(observer: observer)
        @form = ObservationForm.new(@observation)
        @form.observation_ratings_attributes = nil
        @available_abilities = company.abilities
        @available_assignments = company.assignments

        expect { render }.not_to raise_error
        expect(rendered).to have_content('Ratings & Privacy')
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]', count: 2)
      end
    end

    context 'when observation_ratings_attributes is empty hash' do
      it 'renders without errors' do
        @observation = company.observations.build(observer: observer)
        @form = ObservationForm.new(@observation)
        @form.observation_ratings_attributes = {}
        @available_abilities = company.abilities
        @available_assignments = company.assignments

        expect { render }.not_to raise_error
        expect(rendered).to have_content('Ratings & Privacy')
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]', count: 2)
      end
    end

    context 'when observation_ratings_attributes contains arrays' do
      it 'renders without errors' do
        # This is the bug scenario - would have caught the TypeError
        @observation = company.observations.build(observer: observer)
        @form = ObservationForm.new(@observation)
        @form.observation_ratings_attributes = {
          "ability_#{ability1.id}" => ['strongly_agree'], # Array instead of string
          "ability_#{ability2.id}" => ['agree'], # Array instead of string
          "assignment_#{assignment1.id}" => ['strongly_agree'] # Array instead of string
        }
        @available_abilities = company.abilities
        @available_assignments = company.assignments

        expect { render }.not_to raise_error
        expect(rendered).to have_content('Ratings & Privacy')
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]', count: 2)
      end
    end

    context 'when observation_ratings_attributes contains strings' do
      it 'renders without errors' do
        # Expected scenario
        @observation = company.observations.build(observer: observer)
        @form = ObservationForm.new(@observation)
        @form.observation_ratings_attributes = {
          "ability_#{ability1.id}" => { 'rating' => 'strongly_agree' },
          "ability_#{ability2.id}" => { 'rating' => 'agree' },
          "assignment_#{assignment1.id}" => { 'rating' => 'strongly_agree' }
        }
        @available_abilities = company.abilities
        @available_assignments = company.assignments

        expect { render }.not_to raise_error
        expect(rendered).to have_content('Ratings & Privacy')
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]', count: 2)
      end
    end

    context 'when observation_ratings_attributes contains mixed data types' do
      it 'renders without errors' do
        # Mixed scenario - some strings, some arrays, some nil
        @observation = company.observations.build(observer: observer)
        @form = ObservationForm.new(@observation)
        @form.observation_ratings_attributes = {
          "ability_#{ability1.id}" => { 'rating' => 'strongly_agree' }, # String
          "ability_#{ability2.id}" => ['agree'], # Array
          "assignment_#{assignment1.id}" => nil, # Nil
          "assignment_#{assignment2.id}" => { 'rating' => '' } # Empty string
        }
        @available_abilities = company.abilities
        @available_assignments = company.assignments

        expect { render }.not_to raise_error
        expect(rendered).to have_content('Ratings & Privacy')
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]', count: 2)
      end
    end

    context 'when observation_ratings_attributes contains deeply nested arrays' do
      it 'renders without errors' do
        # Deeply nested array scenario
        @observation = company.observations.build(observer: observer)
        @form = ObservationForm.new(@observation)
        @form.observation_ratings_attributes = {
          "ability_#{ability1.id}" => [['strongly_agree']], # Nested array
          "ability_#{ability2.id}" => { 'rating' => [['agree']] } # Array in hash
        }
        @available_abilities = company.abilities
        @available_assignments = company.assignments

        expect { render }.not_to raise_error
        expect(rendered).to have_content('Ratings & Privacy')
        expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
      end
    end
  end

  describe 'rendering with no abilities/assignments available' do
    it 'shows appropriate message when no abilities or assignments exist' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @available_abilities = []
      @available_assignments = []

      render

      expect(rendered).to have_content('No abilities or assignments available for the selected observees.')
      expect(rendered).not_to have_css('select[name*="observation[observation_ratings_attributes]"]')
    end
  end

  describe 'rendering with abilities only' do
    it 'shows only ability rating selects' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @available_abilities = company.abilities
      @available_assignments = []

      render

      expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]', count: 2)
      expect(rendered).not_to have_css('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]')
    end
  end

  describe 'rendering with assignments only' do
    it 'shows only assignment rating selects' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @available_abilities = []
      @available_assignments = company.assignments

      render

      expect(rendered).to have_css('select[name*="observation[observation_ratings_attributes]"][name*="assignment"]', count: 2)
      expect(rendered).not_to have_css('select[name*="observation[observation_ratings_attributes]"][name*="ability"]')
    end
  end

  describe 'privacy level options' do
    it 'renders all privacy level options' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @available_abilities = []
      @available_assignments = []

      render

      expect(rendered).to have_css('input[name="observation[privacy_level]"]', count: 5)
      expect(rendered).to have_css('#privacy_observer_only')
      expect(rendered).to have_css('#privacy_observed_only')
      expect(rendered).to have_css('#privacy_managers_only')
      expect(rendered).to have_css('#privacy_observed_and_managers')
      expect(rendered).to have_css('#privacy_public')
    end

    it 'preserves selected privacy level' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.privacy_level = 'observed_only'
      @available_abilities = []
      @available_assignments = []

      render

      expect(rendered).to have_css('#privacy_observed_only:checked')
    end
  end

  describe 'form submission elements' do
    it 'renders submit button with correct value' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @available_abilities = []
      @available_assignments = []

      render

      expect(rendered).to have_css('input[type="submit"][value="3"]')
    end

    it 'renders back button' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @available_abilities = []
      @available_assignments = []

      render

      expect(rendered).to have_link('Back to Step 1')
    end
  end

  describe 'error handling' do
    it 'renders form errors when present' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.errors.add(:privacy_level, "can't be blank")
      @available_abilities = []
      @available_assignments = []

      render

      expect(rendered).to have_content("can't be blank")
      expect(rendered).to have_css('.alert-danger')
    end
  end

  describe 'progress indicator' do
    it 'shows correct step progress' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @available_abilities = []
      @available_assignments = []

      render

      expect(rendered).to have_content('Step 2 of 3')
      expect(rendered).to have_css('.progress-bar-step-2')
    end
  end
end
