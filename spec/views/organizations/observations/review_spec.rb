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
    @organization = company
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

      expect(rendered).to have_content('January 15, 2024 at 2:30 PM')
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
      @form.observation_ratings = [
        ObservationRating.new(rateable_type: 'Ability', rateable_id: ability1.id, rating: 'strongly_agree'),
        ObservationRating.new(rateable_type: 'Assignment', rateable_id: assignment1.id, rating: 'agree')
      ]
      @observees_for_notifications = []

      render

      expect(rendered).to have_content('Ability')
      expect(rendered).to have_content('Assignment')
      expect(rendered).to have_content('Strongly Agree')
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
      expect(rendered).to have_content('Send Slack notifications to selected observees')
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

    it 'shows Slack connection status', :skip => "Slack integration not yet implemented" do
      # observee1.person.update!(slack_user_id: 'U1234567890')
      # observee2.person.update!(slack_user_id: nil)

      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @observees_for_notifications = [observee1, observee2]

      render

      expect(rendered).to have_css('i.bi-check-circle.text-success', count: 1)
      expect(rendered).to have_css('i.bi-exclamation-triangle.text-warning', count: 1)
    end

    it 'hides notification section initially' do
      @observation = company.observations.build(observer: observer)
      @form = ObservationForm.new(@observation)
      @observees_for_notifications = [observee1]

      render

      expect(rendered).to have_css('#notify_teammates_section[style*="display: none"]')
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

      expect(rendered).to have_content('Step 3 of 3')
      expect(rendered).to have_css('.progress-bar-step-3')
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
