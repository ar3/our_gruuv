require 'rails_helper'

RSpec.describe 'organizations/kudos/index', type: :view do
  let(:company) { create(:organization, :company, name: 'Test Company') }
  let(:observer) { create(:person, first_name: 'Andrew', last_name: 'R.') }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person, first_name: 'Aims', last_name: 'C.') }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation,
      observer: observer,
      company: company,
      observed_at: Time.parse('2025-10-05 14:30:00'),
      story: 'This is a test story about great work. ' * 20, # Long story to test truncation
      privacy_level: :public_observation,
      published_at: Time.current
    )
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs
  end

  before do
    observer_teammate # Ensure observer teammate is created
    assign(:organization, company)
    assign(:observations, [observation])
    # Make current_person available - ViewHelpers provides it via @current_person
    view.instance_variable_set(:@current_person, nil)
    # Define method directly on view for content_for blocks
    view.define_singleton_method(:current_person) { nil }
    allow(view).to receive(:organization_kudos_path).and_return('/organizations/1/kudos')
    allow(view).to receive(:organization_kudo_path).and_return('/organizations/1/kudos/2025-10-05/1')
    allow(view).to receive(:organization_observations_path).and_return('/organizations/1/observations')
    render
  end

  describe 'story section' do
    it 'displays the story with bordered container' do
      expect(rendered).to have_css('.markdown-content--bordered')
    end

    it 'displays truncated story content' do
      expect(rendered).to include('This is a test story about great work.')
    end

    it 'truncates long stories' do
      # Story should be truncated (300 chars default)
      expect(rendered).to include('...')
    end

    it 'does not include GIFs' do
      # Should not have GIF container classes
      expect(rendered).not_to have_css('.gif-container')
      # Note: .row is now used for the two-column layout, so we check for gif-container specifically
    end
  end

  describe 'attribution section' do
    it 'displays observer information' do
      expect(rendered).to include('Observed by')
      expect(rendered).to include('Andrew')
    end

    it 'displays recognized people when present' do
      expect(rendered).to include('Recognizing:')
      expect(rendered).to include('Aims')
    end

    it 'displays the date' do
      expect(rendered).to include('October 05, 2025')
    end

    it 'is in a two-column layout' do
      expect(rendered).to have_css('.row')
      expect(rendered).to have_css('.col-md-6', count: 2)
    end

    it 'has observer and recognized people as links' do
      expect(rendered).to have_link('Andrew', href: /people/)
      expect(rendered).to have_link('Aims', href: /people/)
    end
  end

  describe 'view link' do
    it 'displays a link to view full kudos' do
      expect(rendered).to have_link('View Full Kudos')
    end

    it 'links to the show page' do
      expect(rendered).to have_css('a[href*="kudos"]')
    end
  end

  describe 'when there are no observations' do
    before do
      assign(:observations, [])
      render
    end

    it 'displays a message' do
      expect(rendered).to include('No public kudos yet.')
    end
  end

  describe 'when story is short' do
    let(:short_observation) do
      obs = build(:observation,
        observer: observer,
        company: company,
        observed_at: Time.parse('2025-10-06 14:30:00'), # Different date to avoid conflicts
        story: 'Short story.',
        privacy_level: :public_observation,
        published_at: Time.current
      )
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    before do
      assign(:observations, [short_observation])
      render
    end

    it 'does not add ellipsis to short stories' do
      # Check that the story content itself doesn't end with ellipsis
      # Look for the specific short story text
      expect(rendered).to include('Short story.')
      expect(rendered).not_to match(/Short story\.\.\./)
    end
  end
end

