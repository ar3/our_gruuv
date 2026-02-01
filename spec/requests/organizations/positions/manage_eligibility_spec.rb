require 'rails_helper'

RSpec.describe 'Position Eligibility Management', type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, person: person, organization: company, can_manage_maap: true) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  
  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/positions/:id/manage_eligibility' do
    it 'renders the manage eligibility form' do
      get manage_eligibility_organization_position_path(company, position)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Eligibility Requirements Configuration')
    end

    it 'requires can_manage_maap permission on company teammate record' do
      teammate.update(can_manage_maap: false)
      
      get manage_eligibility_organization_position_path(company, position)
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end

    it 'pre-populates form with existing eligibility requirements' do
      position.update!(
        eligibility_requirements_explicit: {
          'mileage_requirements' => { 'minimum_mileage_points' => 20 },
          'position_check_in_requirements' => { 'minimum_rating' => 2, 'minimum_months_at_or_above_rating_criteria' => 6 }
        }
      )
      
      get manage_eligibility_organization_position_path(company, position)
      
      expect(response).to have_http_status(:success)
      eligibility_data = assigns(:eligibility_data)
      expect(eligibility_data['mileage_requirements']['minimum_mileage_points']).to eq(20)
      expect(eligibility_data['position_check_in_requirements']['minimum_rating']).to eq(2)
    end

    it 'handles position with no eligibility requirements' do
      get manage_eligibility_organization_position_path(company, position)
      
      expect(response).to have_http_status(:success)
      eligibility_data = assigns(:eligibility_data)
      expect(eligibility_data).to eq({})
    end
  end

  describe 'PATCH /organizations/:organization_id/positions/:id/update_eligibility' do
    it 'updates mileage requirements' do
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          mileage_requirements: {
            minimum_mileage_points: '25'
          }
        }
      }
      
      expect(response).to redirect_to(organization_position_path(company, position))
      expect(flash[:notice]).to be_present
      
      position.reload
      expect(position.eligibility_requirements_explicit['mileage_requirements']['minimum_mileage_points']).to eq(25)
    end

    it 'validates minimum mileage is not lower than required assignments total' do
      # Create required assignments with abilities
      assignment1 = create(:assignment, company: company)
      assignment2 = create(:assignment, company: company)
      ability1 = create(:ability, company: company)
      ability2 = create(:ability, company: company)
      
      # Create assignment abilities with milestone levels
      create(:assignment_ability, assignment: assignment1, ability: ability1, milestone_level: 2) # 2 points
      create(:assignment_ability, assignment: assignment2, ability: ability2, milestone_level: 3) # 3 points
      # Total minimum: 5 points
      
      # Create position assignments
      create(:position_assignment, position: position, assignment: assignment1, assignment_type: 'required')
      create(:position_assignment, position: position, assignment: assignment2, assignment_type: 'required')
      
      # Try to set mileage below minimum (5 points)
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          mileage_requirements: {
            minimum_mileage_points: '3'
          }
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:alert]).to include('cannot be lower than the total from required assignments (5)')
    end

    it 'allows minimum mileage equal to required assignments total' do
      # Create required assignments with abilities
      assignment1 = create(:assignment, company: company)
      ability1 = create(:ability, company: company)
      
      # Create assignment ability with milestone level 2 (2 points)
      create(:assignment_ability, assignment: assignment1, ability: ability1, milestone_level: 2)
      
      # Create position assignment
      create(:position_assignment, position: position, assignment: assignment1, assignment_type: 'required')
      
      # Set mileage equal to minimum (2 points)
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          mileage_requirements: {
            minimum_mileage_points: '2'
          }
        }
      }
      
      expect(response).to redirect_to(organization_position_path(company, position))
      expect(flash[:notice]).to be_present
    end

    it 'updates position check-in requirements' do
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          position_check_in_requirements: {
            minimum_rating: '2',
            minimum_months_at_or_above_rating_criteria: '6'
          }
        }
      }
      
      expect(response).to redirect_to(organization_position_path(company, position))
      
      position.reload
      expect(position.eligibility_requirements_explicit['position_check_in_requirements']['minimum_rating']).to eq(2)
      expect(position.eligibility_requirements_explicit['position_check_in_requirements']['minimum_months_at_or_above_rating_criteria']).to eq(6)
    end

    it 'updates required assignment check-in requirements' do
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          required_assignment_check_in_requirements: {
            minimum_rating: 'meeting',
            minimum_months_at_or_above_rating_criteria: '6',
            minimum_percentage_of_assignments: '100'
          }
        }
      }
      
      expect(response).to redirect_to(organization_position_path(company, position))
      
      position.reload
      req_data = position.eligibility_requirements_explicit['required_assignment_check_in_requirements']
      expect(req_data['minimum_rating']).to eq('meeting')
      expect(req_data['minimum_months_at_or_above_rating_criteria']).to eq(6)
      expect(req_data['minimum_percentage_of_assignments']).to eq(100.0)
    end

    it 'updates all requirement types in single request' do
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          mileage_requirements: {
            minimum_mileage_points: '20'
          },
          position_check_in_requirements: {
            minimum_rating: '2',
            minimum_months_at_or_above_rating_criteria: '6'
          },
          required_assignment_check_in_requirements: {
            minimum_rating: 'meeting',
            minimum_months_at_or_above_rating_criteria: '6',
            minimum_percentage_of_assignments: '100'
          },
          unique_to_you_assignment_check_in_requirements: {
            minimum_rating: 'exceeding',
            minimum_months_at_or_above_rating_criteria: '3',
            minimum_percentage_of_assignments: '50'
          },
          company_aspirational_values_check_in_requirements: {
            minimum_rating: 'meeting',
            minimum_months_at_or_above_rating_criteria: '6',
            minimum_percentage_of_aspirational_values: '100'
          },
          title_department_aspirational_values_check_in_requirements: {
            minimum_rating: 'meeting',
            minimum_months_at_or_above_rating_criteria: '6',
            minimum_percentage_of_aspirational_values: '100'
          }
        }
      }
      
      expect(response).to redirect_to(organization_position_path(company, position))
      
      position.reload
      data = position.eligibility_requirements_explicit
      expect(data['mileage_requirements']).to be_present
      expect(data['position_check_in_requirements']).to be_present
      expect(data['required_assignment_check_in_requirements']).to be_present
      expect(data['unique_to_you_assignment_check_in_requirements']).to be_present
      expect(data['company_aspirational_values_check_in_requirements']).to be_present
      expect(data['title_department_aspirational_values_check_in_requirements']).to be_present
    end

    it 'removes requirement sections when all fields are blank' do
      position.update!(
        eligibility_requirements_explicit: {
          'mileage_requirements' => { 'minimum_mileage_points' => 20 },
          'position_check_in_requirements' => { 'minimum_rating' => 2, 'minimum_months_at_or_above_rating_criteria' => 6 }
        }
      )
      
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          mileage_requirements: {
            minimum_mileage_points: ''
          },
          position_check_in_requirements: {
            minimum_rating: '',
            minimum_months_at_or_above_rating_criteria: ''
          }
        }
      }
      
      expect(response).to redirect_to(organization_position_path(company, position))
      
      position.reload
      expect(position.eligibility_requirements_explicit).to eq({})
    end

    it 'validates minimum months >= 0' do
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          position_check_in_requirements: {
            minimum_rating: '2',
            minimum_months_at_or_above_rating_criteria: '-1'
          }
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:alert]).to include('Minimum months must be >= 0')
    end

    it 'validates minimum percentage between 0 and 100' do
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          required_assignment_check_in_requirements: {
            minimum_rating: 'meeting',
            minimum_months_at_or_above_rating_criteria: '6',
            minimum_percentage_of_assignments: '150'
          }
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:alert]).to include('Minimum percentage must be between 0 and 100')
    end

    it 'validates position check-in rating range' do
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          position_check_in_requirements: {
            minimum_rating: '5',
            minimum_months_at_or_above_rating_criteria: '6'
          }
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:alert]).to include('Position check-in minimum rating must be between -3 and 3')
    end

    it 'requires can_manage_maap permission on company teammate record' do
      teammate.update(can_manage_maap: false)
      
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {}
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end

    it 'handles partial updates - only updates provided sections' do
      position.update!(
        eligibility_requirements_explicit: {
          'mileage_requirements' => { 'minimum_mileage_points' => 20 },
          'position_check_in_requirements' => { 'minimum_rating' => 2, 'minimum_months_at_or_above_rating_criteria' => 6 }
        }
      )
      
      patch update_eligibility_organization_position_path(company, position), params: {
        eligibility_requirements: {
          mileage_requirements: {
            minimum_mileage_points: '30'
          }
        }
      }
      
      expect(response).to redirect_to(organization_position_path(company, position))
      
      position.reload
      expect(position.eligibility_requirements_explicit['mileage_requirements']['minimum_mileage_points']).to eq(30)
      # Position check-in requirements should be removed since not provided
      expect(position.eligibility_requirements_explicit['position_check_in_requirements']).to be_nil
    end
  end
end
