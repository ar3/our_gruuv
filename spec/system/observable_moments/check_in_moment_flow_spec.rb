require 'rails_helper'

RSpec.describe 'Check-In Observable Moment Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person) }
  let(:manager_teammate) { create(:teammate, organization: company, person: manager_person) }
  let(:employee_person) { create(:person) }
  let(:employee_teammate) { create(:teammate, organization: company, person: employee_person) }
  let(:employment_tenure) { create(:employment_tenure, teammate: employee_teammate, company: company, manager_teammate: manager_teammate) }
  
  before do
    sign_in_as(manager_person, company)
  end
  
  describe 'rating improvement detection' do
    it 'creates moment when position check-in rating improved' do
      # Create previous check-in with lower rating
      previous_check_in = create(:position_check_in,
                                 teammate: employee_teammate,
                                 employment_tenure: employment_tenure,
                                 official_rating: 1,
                                 official_check_in_completed_at: 1.month.ago,
                                 finalized_by: manager_person)
      
      # Create current check-in with improved rating
      current_check_in = create(:position_check_in,
                                :ready_for_finalization,
                                teammate: employee_teammate,
                                employment_tenure: employment_tenure)
      
      # Finalize check-in (this should create observable moment)
      # Note: In real flow, this would be done through the UI, but for system spec we'll call the service
      Finalizers::PositionCheckInFinalizer.new(
        check_in: current_check_in,
        official_rating: 2,
        shared_notes: 'Improved!',
        finalized_by: manager_person
      ).finalize
      
      # Check that observable moment was created
      moment = ObservableMoment.last
      expect(moment).to be_present
      expect(moment.moment_type).to eq('check_in_completed')
      expect(moment.momentable).to eq(current_check_in)
      
      # Visit dashboard to see the moment
      visit get_shit_done_organization_path(company)
      expect(page).to have_content('Check-In Completed')
    end
    
    it 'does not create moment when rating did not improve' do
      # Create previous check-in with higher rating
      previous_check_in = create(:position_check_in,
                                 teammate: employee_teammate,
                                 employment_tenure: employment_tenure,
                                 official_rating: 3,
                                 official_check_in_completed_at: 1.month.ago,
                                 finalized_by: manager_person)
      
      current_check_in = create(:position_check_in,
                                :ready_for_finalization,
                                teammate: employee_teammate,
                                employment_tenure: employment_tenure)
      
      initial_count = ObservableMoment.count
      
      Finalizers::PositionCheckInFinalizer.new(
        check_in: current_check_in,
        official_rating: 2,
        shared_notes: 'Lower rating',
        finalized_by: manager_person
      ).finalize
      
      # Should not create observable moment
      expect(ObservableMoment.count).to eq(initial_count)
    end
  end
end

