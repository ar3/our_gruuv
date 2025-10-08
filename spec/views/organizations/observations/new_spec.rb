require 'rails_helper'

RSpec.describe 'organizations/observations/new', type: :view do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:observee2) { create(:teammate, organization: company) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(observer)
    allow_any_instance_of(Organizations::OrganizationNamespaceBaseController).to receive(:organization).and_return(company)
    @organization = company
    observer_teammate # Ensure observer teammate is created
  end

  describe 'rendering Step 1 form elements' do
    it 'renders story textarea' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_css('textarea[name="observation[story]"]')
    end

    it 'renders primary feeling select' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_css('select[name="observation[primary_feeling]"]')
    end

    it 'renders secondary feeling select' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_css('select[name="observation[secondary_feeling]"]')
    end

    it 'renders observed_at datetime input' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_css('input[name="observation[observed_at]"][type="datetime-local"]')
    end

    it 'renders teammate checkboxes' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_css('input[name="observation[teammate_ids][]"]', count: 2)
      expect(rendered).to have_content(observee1.person.preferred_name || observee1.person.first_name)
      expect(rendered).to have_content(observee2.person.preferred_name || observee2.person.first_name)
    end

    it 'renders submit button with correct value' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_css('input[type="submit"][value="2"]')
    end
  end

  describe 'form value preservation' do
    it 'preserves story value' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.story = 'Test story'

      render

      expect(rendered).to have_css('textarea[name="observation[story]"]', text: 'Test story')
    end

    it 'preserves primary feeling selection' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.primary_feeling = 'happy'

      render

      expect(rendered).to have_css('select[name="observation[primary_feeling]"] option[selected]', text: /Happy/)
    end

    it 'preserves secondary feeling selection' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.secondary_feeling = 'proud'

      render

      expect(rendered).to have_css('select[name="observation[secondary_feeling]"] option[selected]', text: /Proud/)
    end

    it 'preserves observed_at value' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.observed_at = Time.zone.parse('2024-01-15 14:30')

      render

      expect(rendered).to have_css('input[name="observation[observed_at]"][value="2024-01-15T14:30"]')
    end

    it 'preserves teammate selections' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.teammate_ids = [observee1.id.to_s]

      render

      expect(rendered).to have_css("input[name='observation[teammate_ids][]'][value='#{observee1.id}'][checked]")
    end
  end

  describe 'progress indicator' do
    it 'shows correct step progress' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_content('Step 1 of 3')
      expect(rendered).to have_css('.progress-bar-step-1')
    end
  end

  describe 'error handling' do
    it 'renders form errors when present' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.errors.add(:story, "can't be blank")
      @form.errors.add(:observees, "must have at least one observee")

      render

      expect(rendered).to have_content("can't be blank")
      expect(rendered).to have_content("must have at least one observee")
      expect(rendered).to have_css('.alert-danger')
    end

    it 'renders field-specific errors' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.errors.add(:story, "can't be blank")

      render

      expect(rendered).to have_css('.form-control.is-invalid')
    end
  end

  describe 'feelings options' do
    it 'renders all feeling options' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      # Check for some key feelings
      expect(rendered).to have_css('option[value="happy"]', text: /Happy/)
      expect(rendered).to have_css('option[value="proud"]', text: /Proud/)
      expect(rendered).to have_css('option[value="excited"]', text: /Excited/)
      expect(rendered).to have_css('option[value="grateful"]', text: /Grateful/)
    end

    it 'includes blank option for feelings' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_css('select[name="observation[primary_feeling]"] option[value=""]')
      expect(rendered).to have_css('select[name="observation[secondary_feeling]"] option[value=""]')
    end
  end

  describe 'teammate display' do
    it 'shows teammate names and emails' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_content(observee1.person.email)
      expect(rendered).to have_content(observee2.person.email)
    end

    it 'handles teammates without preferred names' do
      observee1.person.update!(preferred_name: nil)
      observee2.person.update!(preferred_name: nil)

      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_content(observee1.person.first_name)
      expect(rendered).to have_content(observee2.person.first_name)
    end
  end

  describe 'form validation' do
    it 'includes required attributes' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_css('textarea[name="observation[story]"][required]')
      expect(rendered).to have_css('input[name="observation[observed_at]"][required]')
    end

    it 'includes form validation classes' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)

      render

      expect(rendered).to have_css('form.needs-validation')
    end
  end

  describe 'edge cases' do
    it 'handles nil form values gracefully' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.story = nil
      @form.primary_feeling = nil
      @form.secondary_feeling = nil
      @form.observed_at = nil
      @form.teammate_ids = nil

      render

      expect { render }.not_to raise_error
    end

    it 'handles empty teammate_ids array' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.teammate_ids = []

      render

      expect { render }.not_to raise_error
    end

    it 'handles large story text' do
      large_story = 'A' * 10000
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.story = large_story

      render

      expect(rendered).to have_css('textarea[name="observation[story]"]', text: large_story)
    end
  end
end
