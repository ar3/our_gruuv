require 'rails_helper'

RSpec.describe 'Check-In Observable Moment Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person) }
  let!(:manager_teammate) { CompanyTeammate.find_or_create_by!(person: manager_person, organization: company) }
  let(:employee_person) { create(:person) }
  let!(:employee_teammate) { CompanyTeammate.find_or_create_by!(person: employee_person, organization: company) }
  let(:employment_tenure) { create(:employment_tenure, teammate: employee_teammate, company: company, manager_teammate: manager_teammate) }
  
  before do
    sign_in_as(manager_person, company)
  end
  
  describe 'rating improvement detection' do
    it 'does not create observable moment when position check-in is finalized (position check-ins no longer create moments)' do
      current_check_in = create(:position_check_in,
                                :ready_for_finalization,
                                teammate: employee_teammate,
                                employment_tenure: employment_tenure)
      initial_count = ObservableMoment.count

      Finalizers::PositionCheckInFinalizer.new(
        check_in: current_check_in,
        official_rating: 2,
        shared_notes: 'Improved!',
        finalized_by: manager_teammate
      ).finalize

      expect(ObservableMoment.count).to eq(initial_count)
    end

    it 'does not create moment when rating did not improve' do
      # Create previous check-in with higher rating
      previous_check_in = create(:position_check_in,
                                 teammate: employee_teammate,
                                 employment_tenure: employment_tenure,
                                 official_rating: 3,
                                 official_check_in_completed_at: 1.month.ago,
                                 finalized_by_teammate: manager_teammate)
      
      current_check_in = create(:position_check_in,
                                :ready_for_finalization,
                                teammate: employee_teammate,
                                employment_tenure: employment_tenure)
      
      initial_count = ObservableMoment.count
      
      Finalizers::PositionCheckInFinalizer.new(
        check_in: current_check_in,
        official_rating: 2,
        shared_notes: 'Lower rating',
        finalized_by: manager_teammate
      ).finalize
      
      # Should not create observable moment
      expect(ObservableMoment.count).to eq(initial_count)
    end
  end
end

