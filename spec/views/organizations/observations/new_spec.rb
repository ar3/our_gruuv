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
    
    # Define helper methods directly in the view context
    def view.privacy_level_text(level)
      case level
      when 'observer_only' then 'Just for me (Journal)'
      when 'observed_only' then 'Just for them'
      when 'managers_only' then 'For their managers'
      when 'observed_and_managers' then 'For them and their managers'
      when 'public_observation' then 'Public to organization'
      else 'Unknown'
      end
    end
    
    def view.privacy_level_class(level)
      case level
      when 'observer_only' then 'badge bg-secondary'
      when 'observed_only' then 'badge bg-info'
      when 'managers_only' then 'badge bg-warning'
      when 'observed_and_managers' then 'badge bg-primary'
      when 'public_observation' then 'badge bg-success'
      else 'badge bg-secondary'
      end
    end
    
    def view.feelings_display(primary, secondary = nil)
      result = primary.to_s.humanize
      result += " & #{secondary.to_s.humanize}" if secondary.present?
      result
    end
    
    @organization = company
    @form = ObservationForm.new(company.observations.build(observer: observer))
    observer_teammate # Ensure observer teammate is created
    observee1 # Ensure observee1 is created
    observee2 # Ensure observee2 is created
  end

  describe 'rendering Step 1 form elements' do
    it 'renders story textarea' do
      render

      expect(rendered).to have_css('textarea[name="observation[story]"]')
    end

    it 'renders primary feeling select' do
      render

      expect(rendered).to have_css('select[name="observation[primary_feeling]"]')
    end

    it 'renders secondary feeling select' do

      render

      expect(rendered).to have_css('select[name="observation[secondary_feeling]"]')
    end

    it 'renders observed_at datetime input' do

      render

      expect(rendered).to have_css('input[name="observation[observed_at]"][type="datetime-local"]')
    end

    it 'renders teammate checkboxes' do

      render

      expect(rendered).to have_css('input[name="observation[teammate_ids][]"]', count: 3)
      expect(rendered).to have_content(observee1.person.preferred_name || observee1.person.first_name)
      expect(rendered).to have_content(observee2.person.preferred_name || observee2.person.first_name)
    end

    it 'renders submit button with correct value' do

      render

      expect(rendered).to have_css('input[type="submit"][value="2"]')
    end
  end

  describe 'form value preservation' do
    it 'preserves story value' do
      @form.story = 'Test story'

      render

      expect(rendered).to have_css('textarea[name="observation[story]"]', text: 'Test story')
    end

    it 'preserves primary feeling selection' do
      @form.primary_feeling = 'happy'

      render

      expect(rendered).to have_css('select[name="observation[primary_feeling]"] option[selected]', text: /Happy/)
    end

    it 'preserves secondary feeling selection' do
      @form.secondary_feeling = 'proud'

      render

      expect(rendered).to have_css('select[name="observation[secondary_feeling]"] option[selected]', text: /Proud/)
    end

    it 'preserves observed_at value' do
      @form.observed_at = Time.zone.parse('2024-01-15 14:30')

      render

      expect(rendered).to have_css('input[name="observation[observed_at]"][value="2024-01-15T14:30"]')
    end

    it 'preserves teammate selections' do
      @form.teammate_ids = [observee1.id.to_s]

      render

      expect(rendered).to have_css("input[name='observation[teammate_ids][]'][value='#{observee1.id}'][checked]")
    end
  end

  describe 'progress indicator' do
    it 'shows correct step progress' do

      render

      expect(rendered).to have_content('Step 1: Who, When, What, How')
      expect(rendered).to have_css('.progress-bar-step-1')
    end
  end

  describe 'error handling' do
    it 'renders form errors when present' do
      @form.errors.add(:story, "can't be blank")
      @form.errors.add(:observees, "must have at least one observee")

      render

      expect(rendered).to have_content("can't be blank")
      expect(rendered).to have_content("must have at least one observee")
      expect(rendered).to have_css('.alert-danger')
    end

    it 'renders field-specific errors' do
      @form.errors.add(:story, "can't be blank")

      render

      expect(rendered).to have_css('.form-control.is-invalid')
    end
  end

  describe 'feelings options' do
    it 'renders all feeling options' do

      render

      # Check for some key feelings
      expect(rendered).to have_css('option[value="happy"]', text: /Happy/)
      expect(rendered).to have_css('option[value="proud"]', text: /Proud/)
      expect(rendered).to have_css('option[value="excited"]', text: /Excited/)
      expect(rendered).to have_css('option[value="peaceful"]', text: /Peaceful/)
    end

    it 'includes blank option for feelings' do

      render

      expect(rendered).to have_css('select[name="observation[primary_feeling]"] option[value=""]')
      expect(rendered).to have_css('select[name="observation[secondary_feeling]"] option[value=""]')
    end
  end

  describe 'teammate display' do
    it 'shows teammate names and emails' do

      render

      expect(rendered).to have_content(observee1.person.email)
      expect(rendered).to have_content(observee2.person.email)
    end

    it 'handles teammates without preferred names' do
      observee1.person.update!(preferred_name: nil)
      observee2.person.update!(preferred_name: nil)


      render

      expect(rendered).to have_content(observee1.person.first_name)
      expect(rendered).to have_content(observee2.person.first_name)
    end
  end

  describe 'form validation' do
    it 'includes required attributes' do

      render

      expect(rendered).to have_css('textarea[name="observation[story]"][required]')
      expect(rendered).to have_css('input[name="observation[observed_at]"][required]')
    end

    it 'includes form validation classes' do

      render

      expect(rendered).to have_css('form.needs-validation')
    end
  end

  describe 'edge cases' do
    it 'handles nil form values gracefully' do
      @form.story = nil
      @form.primary_feeling = nil
      @form.secondary_feeling = nil
      @form.observed_at = nil
      @form.teammate_ids = nil

      render

      expect { render }.not_to raise_error
    end

    it 'handles empty teammate_ids array' do
      @form.teammate_ids = []

      render

      expect { render }.not_to raise_error
    end

    it 'handles large story text' do
      large_story = 'A' * 10000
      @form.story = large_story

      render

      expect(rendered).to have_css('textarea[name="observation[story]"]', text: large_story)
    end
  end
end
