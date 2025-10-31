require 'rails_helper'

RSpec.describe AbilityAssignmentMilestonesForm, type: :form do
  let(:company) { create(:organization, :company) }
  let(:ability) { create(:ability, organization: company) }
  let(:assignment1) { create(:assignment, company: company) }
  let(:assignment2) { create(:assignment, company: company) }
  let(:form) { AbilityAssignmentMilestonesForm.new(ability) }

  describe 'validations' do
    it 'validates milestone levels are between 1 and 5' do
      form.assignment_milestones = {
        assignment1.id.to_s => '6'
      }
      
      expect(form).not_to be_valid
      expect(form.errors[:assignment_milestones]).to be_present
    end

    it 'accepts 0 for no association' do
      form.assignment_milestones = {
        assignment1.id.to_s => '0'
      }
      
      expect(form).to be_valid
    end

    it 'accepts valid milestone levels (1-5)' do
      form.assignment_milestones = {
        assignment1.id.to_s => '3',
        assignment2.id.to_s => '5'
      }
      
      expect(form).to be_valid
    end

    it 'accepts empty string for no association' do
      form.assignment_milestones = {
        assignment1.id.to_s => '',
        assignment2.id.to_s => '2'
      }
      
      expect(form).to be_valid
    end
  end

  describe 'save method' do
    it 'calls UpdateAbilityAssignmentMilestones service with correct parameters' do
      milestone_data = {
        assignment1.id.to_s => '3',
        assignment2.id.to_s => '5'
      }
      form.assignment_milestones = milestone_data

      expect(UpdateAbilityAssignmentMilestones).to receive(:call).with(
        ability: ability,
        assignment_milestones: milestone_data
      ).and_return(Result.ok(ability))

      expect(form.save).to be true
    end

    it 'returns false when service returns error' do
      milestone_data = {
        assignment1.id.to_s => '3'
      }
      form.assignment_milestones = milestone_data

      expect(UpdateAbilityAssignmentMilestones).to receive(:call).with(
        ability: ability,
        assignment_milestones: milestone_data
      ).and_return(Result.err(['Error message']))

      expect(form.save).to be false
      expect(form.errors[:base]).to be_present
    end

    it 'handles empty milestone data' do
      form.assignment_milestones = {}

      expect(UpdateAbilityAssignmentMilestones).to receive(:call).with(
        ability: ability,
        assignment_milestones: {}
      ).and_return(Result.ok(ability))

      expect(form.save).to be true
    end
  end

  describe 'model association' do
    it 'wraps the ability model' do
      expect(form.model).to eq(ability)
    end
  end
end

