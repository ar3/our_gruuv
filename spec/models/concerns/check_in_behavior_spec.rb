require 'rails_helper'

RSpec.describe CheckInBehavior, type: :model do
  # Create a test model that includes the concern
  let(:test_model_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'position_check_ins'
      include CheckInBehavior
      
      # Override the association methods to avoid database dependencies
      def teammate
        @teammate ||= double('teammate')
      end
      
      def finalized_by
        @finalized_by ||= double('finalized_by')
      end
      
      def maap_snapshot
        @maap_snapshot ||= double('maap_snapshot')
      end
    end
  end
  
  let(:check_in) { test_model_class.new }
  
  describe '#completion_state' do
    it 'returns :both_open when neither employee nor manager has completed' do
      allow(check_in).to receive(:employee_completed?).and_return(false)
      allow(check_in).to receive(:manager_completed?).and_return(false)
      expect(check_in.completion_state).to eq(:both_open)
    end
    
    it 'returns :manager_open_employee_complete when only employee has completed' do
      allow(check_in).to receive(:employee_completed?).and_return(true)
      allow(check_in).to receive(:manager_completed?).and_return(false)
      expect(check_in.completion_state).to eq(:manager_open_employee_complete)
    end
    
    it 'returns :manager_complete_employee_open when only manager has completed' do
      allow(check_in).to receive(:employee_completed?).and_return(false)
      allow(check_in).to receive(:manager_completed?).and_return(true)
      expect(check_in.completion_state).to eq(:manager_complete_employee_open)
    end
    
    it 'returns :both_complete when both employee and manager have completed' do
      allow(check_in).to receive(:employee_completed?).and_return(true)
      allow(check_in).to receive(:manager_completed?).and_return(true)
      expect(check_in.completion_state).to eq(:both_complete)
    end
  end
  
  describe '#viewer_display_mode' do
    context 'when viewer is employee' do
      it 'returns :show_open_fields for :both_open state' do
        allow(check_in).to receive(:employee_completed?).and_return(false)
        allow(check_in).to receive(:manager_completed?).and_return(false)
        expect(check_in.viewer_display_mode(:employee)).to eq(:show_open_fields)
      end
      
      it 'returns :show_complete_summary for :manager_open_employee_complete state' do
        allow(check_in).to receive(:employee_completed?).and_return(true)
        allow(check_in).to receive(:manager_completed?).and_return(false)
        expect(check_in.viewer_display_mode(:employee)).to eq(:show_complete_summary)
      end
      
      it 'returns :show_open_fields for :manager_complete_employee_open state' do
        allow(check_in).to receive(:employee_completed?).and_return(false)
        allow(check_in).to receive(:manager_completed?).and_return(true)
        expect(check_in.viewer_display_mode(:employee)).to eq(:show_open_fields)
      end
      
      it 'returns :show_complete_summary for :both_complete state' do
        allow(check_in).to receive(:employee_completed?).and_return(true)
        allow(check_in).to receive(:manager_completed?).and_return(true)
        expect(check_in.viewer_display_mode(:employee)).to eq(:show_complete_summary)
      end
    end
    
    context 'when viewer is manager' do
      it 'returns :show_open_fields for :both_open state' do
        allow(check_in).to receive(:employee_completed?).and_return(false)
        allow(check_in).to receive(:manager_completed?).and_return(false)
        expect(check_in.viewer_display_mode(:manager)).to eq(:show_open_fields)
      end
      
      it 'returns :show_open_fields for :manager_open_employee_complete state' do
        allow(check_in).to receive(:employee_completed?).and_return(true)
        allow(check_in).to receive(:manager_completed?).and_return(false)
        expect(check_in.viewer_display_mode(:manager)).to eq(:show_open_fields)
      end
      
      it 'returns :show_complete_summary for :manager_complete_employee_open state' do
        allow(check_in).to receive(:employee_completed?).and_return(false)
        allow(check_in).to receive(:manager_completed?).and_return(true)
        expect(check_in.viewer_display_mode(:manager)).to eq(:show_complete_summary)
      end
      
      it 'returns :show_complete_summary for :both_complete state' do
        allow(check_in).to receive(:employee_completed?).and_return(true)
        allow(check_in).to receive(:manager_completed?).and_return(true)
        expect(check_in.viewer_display_mode(:manager)).to eq(:show_complete_summary)
      end
    end
  end
  
  describe '#other_participant_display_mode' do
    context 'when viewer is employee' do
      it 'returns :show_other_participant_is_incomplete for :both_open state' do
        allow(check_in).to receive(:employee_completed?).and_return(false)
        allow(check_in).to receive(:manager_completed?).and_return(false)
        expect(check_in.other_participant_display_mode(:employee)).to eq(:show_other_participant_is_incomplete)
      end
      
      it 'returns :show_other_participant_is_incomplete for :manager_open_employee_complete state' do
        allow(check_in).to receive(:employee_completed?).and_return(true)
        allow(check_in).to receive(:manager_completed?).and_return(false)
        expect(check_in.other_participant_display_mode(:employee)).to eq(:show_other_participant_is_incomplete)
      end
      
      it 'returns :show_other_participant_is_complete for :manager_complete_employee_open state' do
        allow(check_in).to receive(:employee_completed?).and_return(false)
        allow(check_in).to receive(:manager_completed?).and_return(true)
        expect(check_in.other_participant_display_mode(:employee)).to eq(:show_other_participant_is_complete)
      end
      
      it 'returns :show_other_participant_is_complete for :both_complete state' do
        allow(check_in).to receive(:employee_completed?).and_return(true)
        allow(check_in).to receive(:manager_completed?).and_return(true)
        expect(check_in.other_participant_display_mode(:employee)).to eq(:show_other_participant_is_complete)
      end
    end
    
    context 'when viewer is manager' do
      it 'returns :show_other_participant_is_incomplete for :both_open state' do
        allow(check_in).to receive(:employee_completed?).and_return(false)
        allow(check_in).to receive(:manager_completed?).and_return(false)
        expect(check_in.other_participant_display_mode(:manager)).to eq(:show_other_participant_is_incomplete)
      end
      
      it 'returns :show_other_participant_is_complete for :manager_open_employee_complete state' do
        allow(check_in).to receive(:employee_completed?).and_return(true)
        allow(check_in).to receive(:manager_completed?).and_return(false)
        expect(check_in.other_participant_display_mode(:manager)).to eq(:show_other_participant_is_complete)
      end
      
      it 'returns :show_other_participant_is_incomplete for :manager_complete_employee_open state' do
        allow(check_in).to receive(:employee_completed?).and_return(false)
        allow(check_in).to receive(:manager_completed?).and_return(true)
        expect(check_in.other_participant_display_mode(:manager)).to eq(:show_other_participant_is_incomplete)
      end
      
      it 'returns :show_other_participant_is_complete for :both_complete state' do
        allow(check_in).to receive(:employee_completed?).and_return(true)
        allow(check_in).to receive(:manager_completed?).and_return(true)
        expect(check_in.other_participant_display_mode(:manager)).to eq(:show_other_participant_is_complete)
      end
    end
  end
end