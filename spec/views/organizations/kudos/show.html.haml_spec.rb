require 'rails_helper'

RSpec.describe 'organizations/kudos/show', type: :view do
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
      story: 'This is a test story about great work.',
      privacy_level: :public_to_world,
      published_at: Time.current
    )
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs
  end

  before do
    observer_teammate # Ensure observer teammate is created
    assign(:organization, company)
    assign(:observation, observation)
    # Make current_person available - ViewHelpers provides it via @current_person
    view.instance_variable_set(:@current_person, nil)
    # Define method directly on view for content_for blocks
    view.define_singleton_method(:current_person) { nil }
    allow(view).to receive(:organization_kudos_path).and_return('/organizations/1/kudos')
    allow(view).to receive(:organization_observation_path).and_return('/organizations/1/observations/1')
    allow(view).to receive(:public_person_path).and_return('/people/1')
    render
  end

  describe 'story section' do
    it 'displays the story with bordered container' do
      expect(rendered).to have_css('.markdown-content--bordered')
    end

    it 'displays the story content' do
      expect(rendered).to include('This is a test story about great work.')
    end
  end

  describe 'attribution section' do
    it 'displays observer information' do
      expect(rendered).to include('Observed by')
      expect(rendered).to include('Andrew R.')
    end

    it 'displays recognized people when present' do
      expect(rendered).to include('Recognizing:')
      expect(rendered).to include('Aims C.')
    end

    it 'displays the date' do
      expect(rendered).to include('October 05, 2025')
    end

    it 'has tooltip data attribute for full date/time' do
      expect(rendered).to have_css('[data-bs-toggle="tooltip"]', text: /October 05, 2025/)
      expect(rendered).to have_css('[title]', text: /October 05, 2025/)
    end

    it 'is in a two-column layout' do
      expect(rendered).to have_css('.row')
      expect(rendered).to have_css('.col-md-6', count: 2)
    end

    it 'has observer and recognized people as links' do
      expect(rendered).to have_link('Andrew R.', href: /people/)
      expect(rendered).to have_link('Aims C.', href: /people/)
    end
  end

  describe 'feelings and ratings card' do
    context 'when feelings are present' do
      let(:observation) do
        obs = build(:observation,
          observer: observer,
          company: company,
          observed_at: Time.parse('2025-10-05 14:30:00'),
          story: 'This is a test story.',
          privacy_level: :public_to_world,
          published_at: Time.current,
          primary_feeling: 'happy'
        )
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'wraps feelings in a card' do
        expect(rendered).to have_css('.card')
        expect(rendered).to have_css('.card-body')
      end

      it 'displays feelings content within the card' do
        expect(rendered).to have_css('.card .card-body', text: /feel/)
      end
    end

    context 'when ratings are present' do
      let(:ability) { create(:ability, name: 'Communication') }
      let(:observation) do
        obs = build(:observation,
          observer: observer,
          company: company,
          observed_at: Time.parse('2025-10-05 14:30:00'),
          story: 'This is a test story.',
          privacy_level: :public_to_world,
          published_at: Time.current
        )
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        create(:observation_rating, observation: obs, rateable: ability, rating: :strongly_agree)
        obs.reload
        obs
      end

      it 'wraps ratings in a card' do
        expect(rendered).to have_css('.card')
        expect(rendered).to have_css('.card-body')
      end
    end

    context 'when both feelings and ratings are present' do
      let(:ability) { create(:ability, name: 'Communication') }
      let(:observation) do
        obs = build(:observation,
          observer: observer,
          company: company,
          observed_at: Time.parse('2025-10-05 14:30:00'),
          story: 'This is a test story.',
          privacy_level: :public_to_world,
          published_at: Time.current,
          primary_feeling: 'happy'
        )
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        create(:observation_rating, observation: obs, rateable: ability, rating: :strongly_agree)
        obs.reload
        obs
      end

      it 'wraps both in the same card' do
        expect(rendered).to have_css('.card .card-body', count: 1)
      end
    end

    context 'when neither feelings nor ratings are present' do
      let(:observation) do
        obs = build(:observation,
          observer: observer,
          company: company,
          observed_at: Time.parse('2025-10-05 14:30:00'),
          story: 'This is a test story.',
          privacy_level: :public_to_world,
          published_at: Time.current,
          primary_feeling: nil
        )
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'does not display an empty card' do
        # Card should only appear if there's content
        expect(rendered).not_to have_css('.card .card-body:empty')
      end
    end
  end
end

