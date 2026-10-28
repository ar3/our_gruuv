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

  describe '#check_in_early?' do
    it 'is false when never finalized' do
      allow(check_in).to receive(:official_check_in_completed_at).and_return(nil)
      expect(check_in.check_in_early?).to be(false)
    end

    it 'is true when finalized within the check-in early window' do
      allow(check_in).to receive(:official_check_in_completed_at).and_return(10.days.ago)
      expect(check_in.check_in_early?).to be(true)
    end

    it 'is false when finalized after the check-in early window' do
      days = EngagementHealth::Thresholds::CHECK_IN_EARLY_WITHIN_DAYS + 1
      allow(check_in).to receive(:official_check_in_completed_at).and_return(days.days.ago)
      expect(check_in.check_in_early?).to be(false)
    end
  end

  describe ".latest_finalized_index_by" do

    it "returns the most recent finalized check-in per group key" do
      teammate = create(:teammate)
      aspiration = create(:aspiration, company: teammate.organization)

      older = create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: aspiration,
        official_check_in_completed_at: 6.months.ago,
        official_rating: "meeting"
      )
      newer = create(
        :aspiration_check_in,
        :finalized,
        teammate: teammate,
        aspiration: aspiration,
        official_check_in_completed_at: 1.week.ago,
        official_rating: "working_to_meet"
      )

      indexed = AspirationCheckIn.latest_finalized_index_by(
        AspirationCheckIn.where(company_teammate: teammate),
        :aspiration_id
      )

      expect(indexed[aspiration.id]).to eq(newer)
      expect(indexed[aspiration.id]).not_to eq(older)
    end
  end

  describe ".check_in_early?" do
    it "is false when timestamp is blank" do
      expect(described_class.check_in_early?(nil)).to be(false)
    end

    it "is true within the early window" do
      t = EngagementHealth::Thresholds::CHECK_IN_EARLY_WITHIN_DAYS.days.ago
      expect(described_class.check_in_early?(t)).to be(true)
    end

    it "is false after the early window" do
      t = (EngagementHealth::Thresholds::CHECK_IN_EARLY_WITHIN_DAYS + 1).days.ago
      expect(described_class.check_in_early?(t)).to be(false)
    end
  end
end
