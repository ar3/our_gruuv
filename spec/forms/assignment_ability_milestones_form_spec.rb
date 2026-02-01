require 'rails_helper'

RSpec.describe AssignmentAbilityMilestonesForm, type: :form do
  let(:company) { create(:organization, :company) }
  let(:assignment) { create(:assignment, company: company) }
  let(:ability1) { create(:ability, company: company) }
  let(:ability2) { create(:ability, company: company) }
  let(:form) { AssignmentAbilityMilestonesForm.new(assignment) }

  describe 'validations' do
    it 'validates milestone levels are between 1 and 5' do
      form.ability_milestones = {
        ability1.id.to_s => '6'
      }
      
      expect(form).not_to be_valid
      expect(form.errors[:ability_milestones]).to be_present
    end

    it 'accepts 0 for no association' do
      form.ability_milestones = {
        ability1.id.to_s => '0'
      }
      
      expect(form).to be_valid
    end

    it 'accepts valid milestone levels (1-5)' do
      form.ability_milestones = {
        ability1.id.to_s => '3',
        ability2.id.to_s => '5'
      }
      
      expect(form).to be_valid
    end

    it 'accepts empty string for no association' do
      form.ability_milestones = {
        ability1.id.to_s => '',
        ability2.id.to_s => '2'
      }
      
      expect(form).to be_valid
    end
  end

  describe 'save method' do
    it 'calls UpdateAssignmentAbilityMilestones service with correct parameters' do
      milestone_data = {
        ability1.id.to_s => '3',
        ability2.id.to_s => '5'
      }
      form.ability_milestones = milestone_data

      expect(UpdateAssignmentAbilityMilestones).to receive(:call).with(
        assignment: assignment,
        ability_milestones: milestone_data
      ).and_return(Result.ok(assignment))

      expect(form.save).to be true
    end

    it 'returns false when service returns error' do
      milestone_data = {
        ability1.id.to_s => '3'
      }
      form.ability_milestones = milestone_data

      expect(UpdateAssignmentAbilityMilestones).to receive(:call).with(
        assignment: assignment,
        ability_milestones: milestone_data
      ).and_return(Result.err(['Error message']))

      expect(form.save).to be false
      expect(form.errors[:base]).to be_present
    end

    it 'handles empty milestone data' do
      form.ability_milestones = {}

      expect(UpdateAssignmentAbilityMilestones).to receive(:call).with(
        assignment: assignment,
        ability_milestones: {}
      ).and_return(Result.ok(assignment))

      expect(form.save).to be true
    end
  end

  describe 'model association' do
    it 'wraps the assignment model' do
      expect(form.model).to eq(assignment)
    end
  end
end

