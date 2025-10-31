require 'rails_helper'

RSpec.describe Organizations::Abilities::AssignmentMilestonesController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let!(:ability) { create(:ability, organization: company) }
  let!(:assignment1) { create(:assignment, company: company) }
  let!(:assignment2) { create(:assignment, company: department) }
  let!(:assignment3) { create(:assignment, company: company) }

  before do
    session[:current_person_id] = person.id
    create(:teammate, person: person, organization: company, can_manage_maap: true)
    allow(controller).to receive(:current_person).and_return(person)
  end

  describe 'GET #show' do
    context 'when user can view ability' do
      before do
        allow_any_instance_of(AbilityPolicy).to receive(:show?).and_return(true)
      end

      it 'renders the show template' do
        get :show, params: { organization_id: company.id, ability_id: ability.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end

      it 'loads the ability' do
        get :show, params: { organization_id: company.id, ability_id: ability.id }
        expect(assigns(:ability)).to eq(ability)
      end

      it 'loads all assignments in company hierarchy' do
        get :show, params: { organization_id: company.id, ability_id: ability.id }
        
        assignments = assigns(:assignments)
        expect(assignments).to include(assignment1, assignment2, assignment3)
      end

      it 'loads existing associations' do
        create(:assignment_ability, ability: ability, assignment: assignment1, milestone_level: 3)
        
        get :show, params: { organization_id: company.id, ability_id: ability.id }
        
        associations = assigns(:existing_associations)
        expect(associations[assignment1.id]).to eq(3)
      end

      it 'initializes the form' do
        get :show, params: { organization_id: company.id, ability_id: ability.id }
        expect(assigns(:form)).to be_a(AbilityAssignmentMilestonesForm)
        expect(assigns(:form).model).to eq(ability)
      end
    end

    context 'when user cannot view ability' do
      before do
        allow_any_instance_of(AbilityPolicy).to receive(:show?).and_return(false)
      end

      it 'redirects when authorization fails' do
        get :show, params: { organization_id: company.id, ability_id: ability.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end

  describe 'PATCH #update' do
    context 'when user can update ability' do
      before do
        allow_any_instance_of(AbilityPolicy).to receive(:update?).and_return(true)
      end

      it 'updates associations successfully' do
        milestone_data = {
          assignment1.id.to_s => '3',
          assignment2.id.to_s => '5',
          assignment3.id.to_s => '0'
        }

        patch :update, params: {
          organization_id: company.id,
          ability_id: ability.id,
          ability_assignment_milestones_form: {
            assignment_milestones: milestone_data
          }
        }

        expect(response).to redirect_to(organization_ability_path(company, ability))
        expect(flash[:notice]).to be_present
        
        expect(ability.assignment_abilities.find_by(assignment: assignment1).milestone_level).to eq(3)
        expect(ability.assignment_abilities.find_by(assignment: assignment2).milestone_level).to eq(5)
        expect(ability.assignment_abilities.find_by(assignment: assignment3)).to be_nil
      end

      it 'handles form validation errors' do
        milestone_data = {
          assignment1.id.to_s => '6' # Invalid milestone level
        }

        patch :update, params: {
          organization_id: company.id,
          ability_id: ability.id,
          ability_assignment_milestones_form: {
            assignment_milestones: milestone_data
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:show)
      end
    end

    context 'when user cannot update ability' do
      before do
        allow_any_instance_of(AbilityPolicy).to receive(:update?).and_return(false)
        allow_any_instance_of(AbilityPolicy).to receive(:show?).and_return(true)
      end

      it 'redirects when authorization fails' do
        patch :update, params: {
          organization_id: company.id,
          ability_id: ability.id,
          ability_assignment_milestones_form: {
            assignment_milestones: { assignment1.id.to_s => '3' }
          }
        }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end
end

