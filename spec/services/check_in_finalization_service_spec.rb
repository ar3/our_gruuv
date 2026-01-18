require 'rails_helper'

RSpec.describe CheckInFinalizationService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  
  let!(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }
  let!(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  
  let!(:assignment_tenure) do
    create(:assignment_tenure,
           teammate: employee_teammate,
           assignment: assignment,
           anticipated_energy_percentage: 50,
           started_at: 1.month.ago)
  end
  
  let!(:assignment_check_in) do
    create(:assignment_check_in,
           :ready_for_finalization,
           teammate: employee_teammate,
           assignment: assignment,
           employee_rating: 'meeting',
           manager_rating: 'exceeding',
           manager_completed_by_teammate: manager_teammate)
  end
  
  let!(:employment_tenure) do
    create(:employment_tenure,
           teammate: employee_teammate,
           company: organization,
           manager_teammate: manager_teammate,
           started_at: 1.month.ago)
  end
  
  let(:finalization_params) do
    {
      assignment_check_ins: {
        assignment_check_in.id => {
          finalize: '1',
          official_rating: 'meeting',
          shared_notes: 'Good work'
        }
      }
    }
  end
  
  let(:request_info) do
    {
      ip_address: '127.0.0.1',
      user_agent: 'Test Agent',
      timestamp: Time.current.iso8601
    }
  end
  
  describe '#call' do
    context 'when maap_snapshot_reason is provided' do
      it 'uses provided reason when creating snapshot' do
        service = described_class.new(
          teammate: employee_teammate,
          finalization_params: finalization_params,
          finalized_by: manager_teammate,
          request_info: request_info,
          maap_snapshot_reason: 'Q4 2024 Performance Review'
        )
        
        result = service.call
        
        expect(result.ok?).to be true
        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq('Q4 2024 Performance Review')
      end
      
      it 'preserves whitespace in custom reason' do
        custom_reason = '  Q4 2024 Performance Review  '
        service = described_class.new(
          teammate: employee_teammate,
          finalization_params: finalization_params,
          finalized_by: manager_teammate,
          request_info: request_info,
          maap_snapshot_reason: custom_reason
        )
        
        result = service.call
        
        expect(result.ok?).to be true
        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq(custom_reason)
      end
    end
    
    context 'when maap_snapshot_reason is blank' do
      it 'falls back to default reason when reason is blank' do
        service = described_class.new(
          teammate: employee_teammate,
          finalization_params: finalization_params,
          finalized_by: manager_teammate,
          request_info: request_info,
          maap_snapshot_reason: ''
        )
        
        result = service.call
        
        expect(result.ok?).to be true
        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq("Check-in finalization for #{employee.display_name}")
      end
    end
    
    context 'when maap_snapshot_reason is nil' do
      it 'falls back to default reason when reason is nil' do
        service = described_class.new(
          teammate: employee_teammate,
          finalization_params: finalization_params,
          finalized_by: manager_teammate,
          request_info: request_info,
          maap_snapshot_reason: nil
        )
        
        result = service.call
        
        expect(result.ok?).to be true
        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq("Check-in finalization for #{employee.display_name}")
      end
      
      it 'falls back to default reason when reason is not provided' do
        service = described_class.new(
          teammate: employee_teammate,
          finalization_params: finalization_params,
          finalized_by: manager_teammate,
          request_info: request_info
        )
        
        result = service.call
        
        expect(result.ok?).to be true
        snapshot = MaapSnapshot.last
        expect(snapshot.reason).to eq("Check-in finalization for #{employee.display_name}")
      end
    end

    context 'position check-in finalization' do
      let(:position_type) { create(:position_type, organization: organization) }
      let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
      let(:position) { create(:position, position_type: position_type, position_level: position_level) }
      let(:employment_tenure) do
        EmploymentTenure.find_by(teammate: employee_teammate, company: organization) ||
          create(:employment_tenure,
            teammate: employee_teammate,
            company: organization,
            manager_teammate: manager_teammate,
            position: position,
            started_at: 1.month.ago)
      end
      let!(:position_check_in) do
        create(:position_check_in,
          :ready_for_finalization,
          teammate: employee_teammate,
          employment_tenure: employment_tenure,
          employee_rating: 1,
          manager_rating: 2)
      end
      let(:position_finalization_params) do
        {
          position_check_in: {
            finalize: '1',
            official_rating: '2',
            shared_notes: 'Excellent performance'
          }
        }
      end

      context 'position check-in rating matches snapshot rating' do
        it 'snapshot contains the same rating as the finalized check-in' do
          service = described_class.new(
            teammate: employee_teammate,
            finalization_params: position_finalization_params,
            finalized_by: manager_teammate,
            request_info: request_info
          )
          
          result = service.call
          
          expect(result.ok?).to be true
          
          # Reload check-in to get updated data
          position_check_in.reload
          snapshot = MaapSnapshot.last
          
          # Verify check-in has the correct rating
          expect(position_check_in.official_rating).to eq(2)
          
          # Verify snapshot's position rating matches check-in rating
          snapshot_rating = snapshot.maap_data['position']['rated_position']['official_position_rating']
          expect(snapshot_rating).to eq(2)
          expect(snapshot_rating).to eq(position_check_in.official_rating)
        end

        it 'tenure rating also matches check-in and snapshot rating' do
          service = described_class.new(
            teammate: employee_teammate,
            finalization_params: position_finalization_params,
            finalized_by: manager_teammate,
            request_info: request_info
          )
          
          result = service.call
          
          expect(result.ok?).to be true
          
          position_check_in.reload
          snapshot = MaapSnapshot.last
          
          # Find the closed tenure (the one that was just finalized)
          closed_tenure = employee_teammate.employment_tenures.inactive.order(ended_at: :desc).first
          
          expect(closed_tenure.official_position_rating).to eq(2)
          expect(closed_tenure.official_position_rating).to eq(position_check_in.official_rating)
          
          snapshot_rating = snapshot.maap_data['position']['rated_position']['official_position_rating']
          expect(snapshot_rating).to eq(closed_tenure.official_position_rating)
        end
      end

      context 'check-in links to snapshot' do
        it 'check-in maap_snapshot_id is set to created snapshot' do
          service = described_class.new(
            teammate: employee_teammate,
            finalization_params: position_finalization_params,
            finalized_by: manager_teammate,
            request_info: request_info
          )
          
          result = service.call
          
          expect(result.ok?).to be true
          
          position_check_in.reload
          snapshot = MaapSnapshot.last
          
          # Verify the check-in is linked to the snapshot
          expect(position_check_in.maap_snapshot_id).to eq(snapshot.id)
          expect(position_check_in.maap_snapshot).to eq(snapshot)
        end

        it 'check-in can access snapshot via association' do
          service = described_class.new(
            teammate: employee_teammate,
            finalization_params: position_finalization_params,
            finalized_by: manager_teammate,
            request_info: request_info
          )
          
          result = service.call
          
          expect(result.ok?).to be true
          
          position_check_in.reload
          snapshot = MaapSnapshot.last
          
          # Verify bidirectional relationship works
          expect(position_check_in.maap_snapshot).to eq(snapshot)
          expect(position_check_in.maap_snapshot_id).to be_present
        end
      end

      context 'full position finalization flow' do
        context 'when rating improved' do
          let!(:previous_position_check_in) do
            create(:position_check_in,
                   teammate: employee_teammate,
                   employment_tenure: employment_tenure,
                   official_rating: 1,
                   official_check_in_completed_at: 1.month.ago,
                   finalized_by_teammate: manager_teammate)
          end
          
          it 'creates observable moment when position check-in rating improved' do
            params = {
              position_check_in: {
                finalize: '1',
                official_rating: '2',
                shared_notes: 'Improved rating'
              }
            }
            
            expect {
              described_class.new(
                teammate: employee_teammate,
                finalization_params: params,
                finalized_by: manager_teammate,
                request_info: request_info
              ).call
            }.to change { ObservableMoment.count }.by(1)
            
            moment = ObservableMoment.last
            expect(moment.moment_type).to eq('check_in_completed')
            expect(moment.momentable).to be_a(PositionCheckIn)
          end
        end
        
        context 'when rating did not improve' do
          let!(:previous_position_check_in) do
            create(:position_check_in,
                   teammate: employee_teammate,
                   employment_tenure: employment_tenure,
                   official_rating: 3,
                   official_check_in_completed_at: 1.month.ago,
                   finalized_by_teammate: manager_teammate)
          end
          
          it 'does not create observable moment when rating decreased' do
            params = {
              position_check_in: {
                finalize: '1',
                official_rating: '2',
                shared_notes: 'Lower rating'
              }
            }
            
            expect {
              described_class.new(
                teammate: employee_teammate,
                finalization_params: params,
                finalized_by: manager_teammate,
                request_info: request_info
              ).call
            }.not_to change { ObservableMoment.count }
          end
        end
        
        it 'finalizes position, creates snapshot, and links check-in with consistent ratings' do
          service = described_class.new(
            teammate: employee_teammate,
            finalization_params: position_finalization_params,
            finalized_by: manager_teammate,
            request_info: request_info
          )
          
          result = service.call
          
          expect(result.ok?).to be true
          
          position_check_in.reload
          snapshot = MaapSnapshot.last
          closed_tenure = employee_teammate.employment_tenures.inactive.order(ended_at: :desc).first
          
          # Verify check-in is finalized
          expect(position_check_in.officially_completed?).to be true
          expect(position_check_in.official_rating).to eq(2)
          expect(position_check_in.shared_notes).to eq('Excellent performance')
          
          # Verify tenure is closed with correct rating
          expect(closed_tenure.ended_at).to be_present
          expect(closed_tenure.official_position_rating).to eq(2)
          
          # Verify snapshot is created
          expect(snapshot).to be_present
          expect(snapshot.employee).to eq(employee)
          expect(snapshot.created_by).to eq(manager)
          
          # Verify snapshot position data structure
          expect(snapshot.maap_data['position']).to be_present
          expect(snapshot.maap_data['position']['rated_position']).to be_present
          
          # Verify all three have consistent ratings
          expect(position_check_in.official_rating).to eq(closed_tenure.official_position_rating)
          snapshot_rating = snapshot.maap_data['position']['rated_position']['official_position_rating']
          expect(snapshot_rating).to eq(position_check_in.official_rating)
          expect(snapshot_rating).to eq(closed_tenure.official_position_rating)
          
          # Verify check-in is linked to snapshot
          expect(position_check_in.maap_snapshot_id).to eq(snapshot.id)
          expect(position_check_in.maap_snapshot).to eq(snapshot)
        end

        it 'snapshot contains correct position data structure' do
          service = described_class.new(
            teammate: employee_teammate,
            finalization_params: position_finalization_params,
            finalized_by: manager_teammate,
            request_info: request_info
          )
          
          result = service.call
          
          expect(result.ok?).to be true
          
          snapshot = MaapSnapshot.last
          closed_tenure = employee_teammate.employment_tenures.inactive.order(ended_at: :desc).first
          
          position_data = snapshot.maap_data['position']
          expect(position_data).to be_present
          
          rated_position = position_data['rated_position']
          expect(rated_position).to be_present
          expect(rated_position['official_position_rating']).to eq(2)
          expect(rated_position['position_id']).to eq(closed_tenure.position_id)
          expect(rated_position['manager_teammate_id']).to eq(closed_tenure.manager_teammate_id)
          expect(rated_position['started_at']).to be_present
          expect(rated_position['ended_at']).to be_present
        end

        it 'uses the most recently closed tenure when multiple closed tenures exist' do
          # Create an older closed tenure with a different rating
          old_tenure = create(:employment_tenure,
            teammate: employee_teammate,
            company: organization,
            manager_teammate: manager_teammate,
            position: position,
            started_at: 3.months.ago,
            ended_at: 2.months.ago,
            official_position_rating: 1)
          
          service = described_class.new(
            teammate: employee_teammate,
            finalization_params: position_finalization_params,
            finalized_by: manager_teammate,
            request_info: request_info
          )
          
          result = service.call
          
          expect(result.ok?).to be true
          
          position_check_in.reload
          snapshot = MaapSnapshot.last
          
          # The snapshot should use the NEWEST closed tenure (rating 2), not the old one (rating 1)
          newest_closed_tenure = employee_teammate.employment_tenures.inactive.order(ended_at: :desc).first
          
          expect(newest_closed_tenure.official_position_rating).to eq(2)
          expect(newest_closed_tenure.id).not_to eq(old_tenure.id)
          
          snapshot_rating = snapshot.maap_data['position']['rated_position']['official_position_rating']
          expect(snapshot_rating).to eq(2)
          expect(snapshot_rating).not_to eq(old_tenure.official_position_rating)
        end
        
        it 'creates observable moment when rating improved from previous check-in' do
          # Create previous check-in with lower rating
          create(:position_check_in,
                 :closed,
                 teammate: employee_teammate,
                 employment_tenure: employment_tenure,
                 official_rating: 1,
                 finalized_by_teammate: manager_teammate)
          
          expect {
            described_class.new(
              teammate: employee_teammate,
              finalization_params: position_finalization_params,
              finalized_by: manager_teammate,
              request_info: request_info
            ).call
          }.to change { ObservableMoment.count }.by(1)
          
          moment = ObservableMoment.last
          expect(moment.moment_type).to eq('check_in_completed')
          expect(moment.momentable).to eq(position_check_in)
        end

        it 'results hash contains check_in for linking' do
          service = described_class.new(
            teammate: employee_teammate,
            finalization_params: position_finalization_params,
            finalized_by: manager_teammate,
            request_info: request_info
          )
          
          result = service.call
          
          expect(result.ok?).to be true
          
          # Verify results hash structure
          expect(result.value[:results][:position]).to be_present
          expect(result.value[:results][:position][:check_in]).to be_present
          expect(result.value[:results][:position][:check_in]).to eq(position_check_in)
        end

        it 'results hash contains rating_data with official_rating' do
          service = described_class.new(
            teammate: employee_teammate,
            finalization_params: position_finalization_params,
            finalized_by: manager_teammate,
            request_info: request_info
          )
          
          result = service.call
          
          expect(result.ok?).to be true
          
          # Verify rating_data is in results
          expect(result.value[:results][:position][:rating_data]).to be_present
          expect(result.value[:results][:position][:rating_data][:official_rating]).to eq(2)
        end

        it 'snapshot rating should match rating from results hash, not database query' do
          # This test ensures the snapshot uses the rating from the finalization results
          # rather than querying the database, which could be inconsistent
          service = described_class.new(
            teammate: employee_teammate,
            finalization_params: position_finalization_params,
            finalized_by: manager_teammate,
            request_info: request_info
          )
          
          result = service.call
          
          expect(result.ok?).to be true
          
          position_check_in.reload
          snapshot = MaapSnapshot.last
          
          # Get rating from results hash
          results_rating = result.value[:results][:position][:rating_data][:official_rating]
          
          # Verify snapshot uses the same rating
          snapshot_rating = snapshot.maap_data['position']['rated_position']['official_position_rating']
          expect(snapshot_rating).to eq(results_rating)
          expect(snapshot_rating).to eq(position_check_in.official_rating)
        end
      end
    end

    context 'conditional snapshot creation' do
      let(:position_type) { create(:position_type, organization: organization) }
      let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
      let(:position) { create(:position, position_type: position_type, position_level: position_level) }
      let(:employment_tenure) do
        EmploymentTenure.find_by(teammate: employee_teammate, company: organization) ||
          create(:employment_tenure,
            teammate: employee_teammate,
            company: organization,
            manager_teammate: manager_teammate,
            position: position,
            started_at: 1.month.ago)
      end
      let!(:position_check_in) do
        create(:position_check_in,
          :ready_for_finalization,
          teammate: employee_teammate,
          employment_tenure: employment_tenure,
          employee_rating: 1,
          manager_rating: 2)
      end

      context 'when no check-ins are finalized' do
        it 'does not create a snapshot' do
          empty_params = {}
          
          expect {
            described_class.new(
              teammate: employee_teammate,
              finalization_params: empty_params,
              finalized_by: manager_teammate,
              request_info: request_info
            ).call
          }.not_to change { MaapSnapshot.count }
        end

        it 'returns success with nil snapshot' do
          empty_params = {}
          
          result = described_class.new(
            teammate: employee_teammate,
            finalization_params: empty_params,
            finalized_by: manager_teammate,
            request_info: request_info
          ).call
          
          expect(result.ok?).to be true
          expect(result.value[:snapshot]).to be_nil
        end

        it 'does not create snapshot when finalize flag is not set' do
          params_without_finalize = {
            position_check_in: {
              official_rating: '2',
              shared_notes: 'Not finalizing'
            }
          }
          
          expect {
            described_class.new(
              teammate: employee_teammate,
              finalization_params: params_without_finalize,
              finalized_by: manager_teammate,
              request_info: request_info
            ).call
          }.not_to change { MaapSnapshot.count }
        end

        it 'does not create snapshot when assignment_check_ins exists but none are finalized' do
          params_with_empty_assignments = {
            assignment_check_ins: {
              assignment_check_in.id => {
                finalize: '0',
                official_rating: 'meeting',
                shared_notes: 'Not finalizing'
              }
            }
          }
          
          expect {
            described_class.new(
              teammate: employee_teammate,
              finalization_params: params_with_empty_assignments,
              finalized_by: manager_teammate,
              request_info: request_info
            ).call
          }.not_to change { MaapSnapshot.count }
        end
      end

      context 'when some check-ins are finalized' do
        it 'creates snapshot when position is finalized' do
          position_params = {
            position_check_in: {
              finalize: '1',
              official_rating: '2',
              shared_notes: 'Finalizing position'
            }
          }
          
          expect {
            described_class.new(
              teammate: employee_teammate,
              finalization_params: position_params,
              finalized_by: manager_teammate,
              request_info: request_info
            ).call
          }.to change { MaapSnapshot.count }.by(1)
        end

        it 'creates snapshot when assignment is finalized' do
          expect {
            described_class.new(
              teammate: employee_teammate,
              finalization_params: finalization_params,
              finalized_by: manager_teammate,
              request_info: request_info
            ).call
          }.to change { MaapSnapshot.count }.by(1)
        end

        it 'creates snapshot when only one of multiple assignments is finalized' do
          assignment2 = create(:assignment, company: organization)
          assignment_tenure2 = create(:assignment_tenure,
            teammate: employee_teammate,
            assignment: assignment2,
            anticipated_energy_percentage: 30,
            started_at: 1.month.ago)
          assignment_check_in2 = create(:assignment_check_in,
            :ready_for_finalization,
            teammate: employee_teammate,
            assignment: assignment2,
            employee_rating: 'meeting',
            manager_rating: 'exceeding',
            manager_completed_by_teammate: manager_teammate)
          
          params_with_one_finalized = {
            assignment_check_ins: {
              assignment_check_in.id => {
                finalize: '1',
                official_rating: 'meeting',
                shared_notes: 'Finalizing this one'
              },
              assignment_check_in2.id => {
                finalize: '0',
                official_rating: 'exceeding',
                shared_notes: 'Not finalizing'
              }
            }
          }
          
          expect {
            described_class.new(
              teammate: employee_teammate,
              finalization_params: params_with_one_finalized,
              finalized_by: manager_teammate,
              request_info: request_info
            ).call
          }.to change { MaapSnapshot.count }.by(1)
        end
      end

      context 'when all check-ins are finalized' do
        let(:aspiration) { create(:aspiration, organization: organization) }
        let!(:aspiration_check_in) do
          create(:aspiration_check_in,
            :ready_for_finalization,
            teammate: employee_teammate,
            aspiration: aspiration,
            employee_rating: 'meeting',
            manager_rating: 'exceeding',
            manager_completed_by_teammate: manager_teammate)
        end

        it 'creates snapshot when position, assignment, and aspiration are all finalized' do
          all_params = {
            position_check_in: {
              finalize: '1',
              official_rating: '2',
              shared_notes: 'Finalizing position'
            },
            assignment_check_ins: {
              assignment_check_in.id => {
                finalize: '1',
                official_rating: 'meeting',
                shared_notes: 'Finalizing assignment'
              }
            },
            aspiration_check_ins: {
              aspiration_check_in.id => {
                finalize: '1',
                official_rating: 'exceeding',
                shared_notes: 'Finalizing aspiration'
              }
            }
          }
          
          expect {
            described_class.new(
              teammate: employee_teammate,
              finalization_params: all_params,
              finalized_by: manager_teammate,
              request_info: request_info
            ).call
          }.to change { MaapSnapshot.count }.by(1)
          
          snapshot = MaapSnapshot.last
          expect(snapshot.change_type).to eq('bulk_check_in_finalization')
        end
      end
    end
  end
end

