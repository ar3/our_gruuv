require 'rails_helper'

RSpec.describe ObservationForm, type: :form do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observation) { build(:observation, observer: observer, company: company) }
  let(:form) { ObservationForm.new(observation) }

  describe 'validations' do
    it 'validates custom_slug uniqueness' do
      teammate = create(:teammate, organization: company)
      
      form.custom_slug = 'test-slug'
      form.story = 'Test story'
      form.privacy_level = 'observer_only'
      form.primary_feeling = 'happy'
      form.teammate_ids = [teammate.id]
      
      expect(form).to be_valid
      
      # Create another observation with the same slug to test uniqueness
      existing_observation = build(:observation, observer: observer, company: company, custom_slug: 'test-slug')
      existing_observation.observees.build(teammate: teammate)
      existing_observation.save!
      
      # Now try to create a new form with the same slug
      new_form = ObservationForm.new(build(:observation, observer: observer, company: company))
      new_form.custom_slug = 'test-slug'
      new_form.story = 'Another story'
      new_form.privacy_level = 'observer_only'
      new_form.primary_feeling = 'happy'
      new_form.teammate_ids = [teammate.id]
      
      expect(new_form).not_to be_valid
      expect(new_form.errors[:custom_slug]).to include('has already been taken')
    end

    it 'validates story presence when publishing' do
      form.story = nil
      form.publishing = true
      expect(form).not_to be_valid
      expect(form.errors[:story]).to include("can't be blank")
    end

    it 'validates privacy_level presence' do
      form.privacy_level = nil
      expect(form).not_to be_valid
      expect(form.errors[:privacy_level]).to include("can't be blank")
    end

    it 'validates primary_feeling inclusion' do
      form.primary_feeling = 'invalid_feeling'
      expect(form).not_to be_valid
      expect(form.errors[:primary_feeling]).to include('is not included in the list')
    end

    it 'validates secondary_feeling inclusion' do
      form.secondary_feeling = 'invalid_feeling'
      expect(form).not_to be_valid
      expect(form.errors[:secondary_feeling]).to include('is not included in the list')
    end
  end

  describe 'save method' do
    it 'handles teammate_ids parameter' do
      teammate1 = create(:teammate, organization: company)
      teammate2 = create(:teammate, organization: company)
      
      form.teammate_ids = [teammate1.id, teammate2.id]
      form.story = 'Test story'
      form.privacy_level = 'observer_only'
      form.primary_feeling = 'happy'
      
      # The form should save successfully (observees handled by controller)
      expect(form.save).to be true
      
      # The form itself doesn't handle observees, that's done in the controller
      # So we just test that the form saves successfully
    end

    it 'handles story_extras with gif_urls' do
      form.story = 'Test story'
      form.privacy_level = 'observer_only'
      form.primary_feeling = 'happy'
      form.story_extras = { 'gif_urls' => ['https://media.giphy.com/media/test1/giphy.gif', 'https://media.giphy.com/media/test2/giphy.gif'] }
      
      expect(form.save).to be true
      
      observation.reload
      expect(observation.story_extras).to eq({ 'gif_urls' => ['https://media.giphy.com/media/test1/giphy.gif', 'https://media.giphy.com/media/test2/giphy.gif'] })
    end
    
    context 'with observable_moment_id' do
      let(:observable_moment) { create(:observable_moment, :new_hire, company: company) }
      let(:teammate) { create(:teammate, organization: company) }
      
      it 'pre-fills observation from moment context' do
        form.observable_moment_id = observable_moment.id
        form.story = 'Test story'  # Story is required for save
        form.privacy_level = 'public_to_company'  # Privacy level is required
        form.primary_feeling = 'happy'
        
        expect(form.save).to be true
        
        observation.reload
        expect(observation.observable_moment).to eq(observable_moment)
        expect(observation.story).to be_present
        expect(observation.privacy_level).to eq('public_to_company')
      end
      
      it 'pre-fills observees from moment context' do
        form.observable_moment_id = observable_moment.id
        form.story = 'Test story'
        form.privacy_level = 'public_to_company'
        form.primary_feeling = 'happy'
        
        expect(form.save).to be true
        
        observation.reload
        expect(observation.observable_moment).to eq(observable_moment)
        # Should have observees from moment context
        expect(observation.observees.count).to be > 0
      end
      
      it 'allows overriding pre-filled values' do
        form.observable_moment_id = observable_moment.id
        form.story = 'Custom story override'
        form.privacy_level = 'observed_only'  # Override suggested level
        form.primary_feeling = 'happy'
        
        expect(form.save).to be true
        
        observation.reload
        expect(observation.story).to eq('Custom story override')
        expect(observation.privacy_level).to eq('observed_only')
      end
    end

    it 'filters out blank gif_urls' do
      form.story = 'Test story'
      form.privacy_level = 'observer_only'
      form.primary_feeling = 'happy'
      form.story_extras = { 'gif_urls' => ['https://media.giphy.com/media/test1/giphy.gif', '', nil, 'https://media.giphy.com/media/test2/giphy.gif'] }
      
      expect(form.save).to be true
      
      observation.reload
      expect(observation.story_extras['gif_urls']).to eq(['https://media.giphy.com/media/test1/giphy.gif', 'https://media.giphy.com/media/test2/giphy.gif'])
    end

    it 'saves empty gif_urls array when all GIFs are removed' do
      # First add some GIFs
      observation.update!(story_extras: { 'gif_urls' => ['https://media.giphy.com/media/test1/giphy.gif'] })
      
      # Then remove them all
      form.story = 'Test story'
      form.privacy_level = 'observer_only'
      form.primary_feeling = 'happy'
      form.story_extras = { 'gif_urls' => [] }
      
      expect(form.save).to be true
      
      observation.reload
      expect(observation.story_extras).to eq({ 'gif_urls' => [] })
    end

    context 'with auto-added aspirations' do
      let(:aspiration1) { create(:aspiration, company: company, name: 'Company Growth', sort_order: 1) }
      let(:aspiration2) { create(:aspiration, company: company, name: 'Innovation', sort_order: 2) }
      let(:aspiration3) { create(:aspiration, company: company, name: 'Customer Satisfaction', sort_order: 3) }

      before do
        aspiration1
        aspiration2
        aspiration3
      end

      it 'can handle observations with auto-added aspirations (ratings with nil/default rating)' do
        # Build observation with auto-added aspirations (as controller would do)
        observation.observation_ratings.build(
          rateable_type: 'Aspiration',
          rateable_id: aspiration1.id
        )
        observation.observation_ratings.build(
          rateable_type: 'Aspiration',
          rateable_id: aspiration2.id
        )
        observation.observation_ratings.build(
          rateable_type: 'Aspiration',
          rateable_id: aspiration3.id
        )

        form.story = 'Test story'
        form.privacy_level = 'observer_only'
        form.primary_feeling = 'happy'

        expect(form).to be_valid
        expect(form.save).to be true

        observation.reload
        aspiration_ratings = observation.observation_ratings.where(rateable_type: 'Aspiration')
        expect(aspiration_ratings.count).to eq(3)
        aspiration_ratings.each do |rating|
          expect(rating.rating).to eq('na') # Default rating
        end
      end

      it 'saves observations with auto-added aspirations correctly' do
        # Build observation with auto-added aspirations
        observation.observation_ratings.build(
          rateable_type: 'Aspiration',
          rateable_id: aspiration1.id
        )
        observation.observation_ratings.build(
          rateable_type: 'Aspiration',
          rateable_id: aspiration2.id
        )

        form.story = 'Test story'
        form.privacy_level = 'observer_only'
        form.primary_feeling = 'happy'

        expect {
          form.save
        }.to change(ObservationRating, :count).by(2)

        observation.reload
        aspiration_ratings = observation.observation_ratings.where(rateable_type: 'Aspiration')
        expect(aspiration_ratings.count).to eq(2)
        expect(aspiration_ratings.pluck(:rateable_id)).to contain_exactly(aspiration1.id, aspiration2.id)
      end

      it 'allows updating ratings for auto-added aspirations' do
        # Build observation with auto-added aspirations
        observation.observation_ratings.build(
          rateable_type: 'Aspiration',
          rateable_id: aspiration1.id
        )
        observation.observation_ratings.build(
          rateable_type: 'Aspiration',
          rateable_id: aspiration2.id
        )

        # Populate form's observation_ratings collection from model
        # This simulates what happens when the form is initialized with an observation
        # that has built (but not saved) observation_ratings
        form.observation_ratings.clear
        observation.observation_ratings.each do |rating|
          form.observation_ratings << ObservationRating.new(
            rateable_type: rating.rateable_type,
            rateable_id: rating.rateable_id,
            rating: rating.rating
          )
        end

        # Update ratings through form collection
        form.story = 'Test story'
        form.privacy_level = 'observer_only'
        form.primary_feeling = 'happy'
        
        # Update the ratings in the form's collection
        aspiration1_rating_form = form.observation_ratings.find { |r| r.rateable_id == aspiration1.id }
        aspiration2_rating_form = form.observation_ratings.find { |r| r.rateable_id == aspiration2.id }
        aspiration1_rating_form.rating = 'strongly_agree'
        aspiration2_rating_form.rating = 'agree'

        expect(form.save).to be true

        observation.reload
        rating1_reloaded = observation.observation_ratings.find_by(rateable_id: aspiration1.id)
        rating2_reloaded = observation.observation_ratings.find_by(rateable_id: aspiration2.id)
        expect(rating1_reloaded.rating).to eq('strongly_agree')
        expect(rating2_reloaded.rating).to eq('agree')
      end
    end
  end
end
