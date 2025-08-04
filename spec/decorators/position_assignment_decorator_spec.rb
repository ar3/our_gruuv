require 'rails_helper'

RSpec.describe PositionAssignmentDecorator, type: :decorator do
  let(:company) { create(:organization, type: 'Company') }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:assignment) { create(:assignment, company: company, title: 'Code Review') }
  let(:position_assignment) { create(:position_assignment, position: position, assignment: assignment).decorate }

  describe '#display_title' do
    context 'when no energy information is present' do
      it 'returns just the assignment title' do
        expect(position_assignment.display_title).to eq('Code Review')
      end
    end

    context 'when only min energy is present' do
      before do
        position_assignment.min_estimated_energy = 25
      end

      it 'returns title with energy range' do
        expect(position_assignment.display_title).to eq('Code Review (25%+ of effort)')
      end
    end

    context 'when only max energy is present' do
      before do
        position_assignment.max_estimated_energy = 75
      end

      it 'returns title with energy range' do
        expect(position_assignment.display_title).to eq('Code Review (Up to 75% of effort)')
      end
    end

    context 'when both min and max energy are present' do
      before do
        position_assignment.min_estimated_energy = 25
        position_assignment.max_estimated_energy = 75
      end

      it 'returns title with energy range' do
        expect(position_assignment.display_title).to eq('Code Review (25%-75% of effort)')
      end
    end
  end

  describe '#display_title_with_type' do
    it 'returns title with assignment type' do
      expect(position_assignment.display_title_with_type).to eq('Code Review (Required)')
    end

    context 'when assignment type is suggested' do
      let(:position_assignment) { create(:position_assignment, :suggested, position: position, assignment: assignment).decorate }

      it 'returns title with suggested type' do
        expect(position_assignment.display_title_with_type).to eq('Code Review (Suggested)')
      end
    end
  end

  describe '#display_title_with_energy' do
    context 'when no energy information is present' do
      it 'returns just the assignment title' do
        expect(position_assignment.display_title_with_energy).to eq('Code Review')
      end
    end

    context 'when energy information is present' do
      before do
        position_assignment.min_estimated_energy = 25
        position_assignment.max_estimated_energy = 75
      end

      it 'returns title with energy information' do
        expect(position_assignment.display_title_with_energy).to eq('Code Review - 25%-75% of effort')
      end
    end
  end
end 