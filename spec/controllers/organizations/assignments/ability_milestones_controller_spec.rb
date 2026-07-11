require 'rails_helper'

RSpec.describe Organizations::Assignments::AbilityMilestonesController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization) }
  let(:department) { create(:department, company: company) }
  let!(:assignment) { create(:assignment, company: company) }
  let!(:ability1) { create(:ability, company: company) }
  let!(:ability2) { create(:ability, company: company, department: department) }
  let!(:ability3) { create(:ability, company: company) }

  before do
    sign_in_as_teammate(person, company)
  end

  describe 'GET #show' do
    context 'when user can view assignment' do
      before do
        allow_any_instance_of(AssignmentPolicy).to receive(:show?).and_return(true)
      end

      it 'renders the show template' do
        get :show, params: { organization_id: company.id, assignment_id: assignment.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end

      it 'loads the assignment' do
        get :show, params: { organization_id: company.id, assignment_id: assignment.id }
        expect(assigns(:assignment)).to eq(assignment)
      end

      it 'splits abilities into associated and available lists' do
        create(:assignment_ability, assignment: assignment, ability: ability1, milestone_level: 3)

        get :show, params: { organization_id: company.id, assignment_id: assignment.id }

        expect(assigns(:associated_abilities)).to eq([ability1])
        expect(assigns(:available_abilities)).to include(ability2, ability3)
        expect(assigns(:available_abilities)).not_to include(ability1)
      end

      it 'sorts abilities by department then name' do
        dept_b = create(:department, company: company, name: 'Zebra Dept')
        dept_a = create(:department, company: company, name: 'Alpha Dept')
        ability_z = create(:ability, company: company, department: dept_b, name: 'AAA Ability')
        ability_a = create(:ability, company: company, department: dept_a, name: 'ZZZ Ability')

        get :show, params: { organization_id: company.id, assignment_id: assignment.id }

        available = assigns(:available_abilities)
        expect(available.index(ability_a)).to be < available.index(ability_z)
      end

      it 'loads existing associations' do
        create(:assignment_ability, assignment: assignment, ability: ability1, milestone_level: 3)
        
        get :show, params: { organization_id: company.id, assignment_id: assignment.id }
        
        associations = assigns(:existing_associations)
        expect(associations[ability1.id]).to eq(3)
      end

      it 'initializes the form' do
        get :show, params: { organization_id: company.id, assignment_id: assignment.id }
        expect(assigns(:form)).to be_a(AssignmentAbilityMilestonesForm)
        expect(assigns(:form).model).to eq(assignment)
      end
    end

    context 'when user cannot view assignment' do
      before do
        allow_any_instance_of(AssignmentPolicy).to receive(:show?).and_return(false)
      end

      it 'redirects when authorization fails' do
        get :show, params: { organization_id: company.id, assignment_id: assignment.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end

  describe 'PATCH #update' do

    context 'when user can update assignment' do
      before do
        allow_any_instance_of(AssignmentPolicy).to receive(:update?).and_return(true)
      end

      it 'updates associations successfully' do
        milestone_data = {
          ability1.id.to_s => '3',
          ability2.id.to_s => '5',
          ability3.id.to_s => '0'
        }

        patch :update, params: {
          organization_id: company.id,
          assignment_id: assignment.id,
          assignment_ability_milestones_form: {
            ability_milestones: milestone_data
          }
        }

        expect(response).to redirect_to(organization_assignment_path(company, assignment))
        expect(flash[:notice]).to be_present
        
        expect(assignment.assignment_abilities.find_by(ability: ability1).milestone_level).to eq(3)
        expect(assignment.assignment_abilities.find_by(ability: ability2).milestone_level).to eq(5)
        expect(assignment.assignment_abilities.find_by(ability: ability3)).to be_nil
      end

      it 'handles form validation errors' do
        milestone_data = {
          ability1.id.to_s => '6' # Invalid milestone level
        }

        patch :update, params: {
          organization_id: company.id,
          assignment_id: assignment.id,
          assignment_ability_milestones_form: {
            ability_milestones: milestone_data
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:show)
      end
    end

    context 'when user cannot update assignment' do
      before do
        allow_any_instance_of(AssignmentPolicy).to receive(:update?).and_return(false)
        allow_any_instance_of(AssignmentPolicy).to receive(:show?).and_return(true)
      end

      it 'redirects when authorization fails' do
        patch :update, params: {
          organization_id: company.id,
          assignment_id: assignment.id,
          assignment_ability_milestones_form: {
            ability_milestones: { ability1.id.to_s => '3' }
          }
        }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end
end

