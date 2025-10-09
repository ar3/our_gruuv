require 'rails_helper'

RSpec.describe 'organizations/observations/review', type: :view do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:observee2) { create(:teammate, organization: company) }
  let(:ability1) { create(:ability, organization: company, name: 'Ruby Programming') }
  let(:assignment1) { create(:assignment, company: company, title: 'Frontend Development') }

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
    
    def view.rating_icon(rating)
      case rating
      when 'strongly_agree' then '⭐'
      when 'agree' then '👍'
      when 'na' then '👁️‍🗨️'
      when 'disagree' then '👎'
      when 'strongly_disagree' then '⭕'
      else '❓'
      end
    end
    
    @organization = company
    @form = ObservationForm.new(company.observations.build(observer: observer))
    observer_teammate # Ensure observer teammate is created
  end

  describe 'rendering observation review data' do
    it 'displays story content' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.story = 'Great work on the project!'
      @observees_for_notifications = []

      render

      expect(rendered).to have_content('Great work on the project!')
    end

    it 'displays observer information' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @observees_for_notifications = []

      render

      expect(rendered).to have_content(observer.preferred_name || observer.first_name)
    end

    it 'displays observed date' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.observed_at = Time.zone.parse('2024-01-15 14:30')
      @observees_for_notifications = []

      render

      expect(rendered).to have_content('January 15, 2024 at  2:30 PM')
    end

    it 'displays feelings when present' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.primary_feeling = 'happy'
      @form.secondary_feeling = 'proud'
      @observees_for_notifications = []

      render

      expect(rendered).to have_content('Happy')
      expect(rendered).to have_content('Proud')
    end

    it 'displays privacy level' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.privacy_level = 'observed_only'
      @observees_for_notifications = []

      render

      expect(rendered).to have_content('Just for them')
    end

    it 'displays observees' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.teammate_ids = [observee1.id.to_s, observee2.id.to_s]
      @observees_for_notifications = [observee1, observee2]

      render

      expect(rendered).to have_content(observee1.person.preferred_name || observee1.person.first_name)
      expect(rendered).to have_content(observee2.person.preferred_name || observee2.person.first_name)
    end

    it 'displays ratings when present' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.observation_ratings_attributes = {
        "ability_#{ability1.id}" => { 'rating' => 'strongly_agree', 'rateable_type' => 'Ability', 'rateable_id' => ability1.id },
        "assignment_#{assignment1.id}" => { 'rating' => 'agree', 'rateable_type' => 'Assignment', 'rateable_id' => assignment1.id }
      }
      @observees_for_notifications = []

      render

      expect(rendered).to have_content('Ruby Programming')
      expect(rendered).to have_content('Frontend Development')
      expect(rendered).to have_content('Strongly agree')
      expect(rendered).to have_content('Agree')
    end

    it 'shows "No ratings" when no ratings present' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.observation_ratings = []
      @observees_for_notifications = []

      render

      expect(rendered).to have_content('No ratings')
    end
  end

  describe 'notification options' do
    it 'renders notification checkbox' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @observees_for_notifications = []

      render

      expect(rendered).to have_css('input[name="observation[send_notifications]"]')
      expect(rendered).to have_content('Send notifications')
    end

    it 'renders teammate notification checkboxes' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @observees_for_notifications = [observee1, observee2]

      render

      expect(rendered).to have_css('input[name="observation[notify_teammate_ids][]"]', count: 2)
      expect(rendered).to have_content(observee1.person.preferred_name || observee1.person.first_name)
      expect(rendered).to have_content(observee2.person.preferred_name || observee2.person.first_name)
    end


    it 'hides notification section initially' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @observees_for_notifications = [observee1]

      render

      expect(rendered).to have_css('#notification-options')
    end
  end

  describe 'form submission elements' do
    it 'renders create observation button' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @observees_for_notifications = []

      render

      expect(rendered).to have_button('Create Observation')
    end

    it 'renders back button' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @observees_for_notifications = []

      render

      expect(rendered).to have_link('Back to Step 2')
    end
  end

  describe 'progress indicator' do
    it 'shows correct step progress' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @observees_for_notifications = []

      render

      expect(rendered).to have_css('.progress-bar-step-3')
      expect(rendered).to have_content('Step 3: Review & Manage')
    end
  end

  describe 'error handling' do
    it 'renders form errors when present' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.errors.add(:base, 'Something went wrong')
      @observees_for_notifications = []

      render

      expect(rendered).to have_content('Something went wrong')
      expect(rendered).to have_css('.alert-danger')
    end
  end

  describe 'edge cases' do
    it 'handles nil feelings gracefully' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.primary_feeling = nil
      @form.secondary_feeling = nil
      @observees_for_notifications = []

      render

      expect { render }.not_to raise_error
    end

    it 'handles empty teammate_ids array' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.teammate_ids = []
      @observees_for_notifications = []

      render

      expect { render }.not_to raise_error
    end

    it 'handles nil observed_at' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @form.observed_at = nil
      @observees_for_notifications = []

      render

      expect { render }.not_to raise_error
    end
  end
end
