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
  end
end
