# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Positions::AbilityMilestonesController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let!(:position) { create(:position, title: title, position_level: position_level) }
  let!(:ability1) { create(:ability, company: organization) }
  let!(:ability2) { create(:ability, company: organization) }
  let!(:ability3) { create(:ability, company: organization) }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #show' do
    context 'when user can view position' do
      before do
        allow_any_instance_of(PositionPolicy).to receive(:show?).and_return(true)
      end

      it 'renders the show template' do
        get :show, params: { organization_id: organization.id, position_id: position.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end

      it 'loads the position' do
        get :show, params: { organization_id: organization.id, position_id: position.id }
        expect(assigns(:position)).to eq(position)
      end

      it 'loads all abilities in company hierarchy' do
        get :show, params: { organization_id: organization.id, position_id: position.id }

        abilities = assigns(:abilities)
        expect(abilities).to include(ability1, ability2, ability3)
      end

      it 'loads existing associations' do
        create(:position_ability, position: position, ability: ability1, milestone_level: 3)

        get :show, params: { organization_id: organization.id, position_id: position.id }

        associations = assigns(:existing_associations)
        expect(associations[ability1.id]).to eq(3)
      end

      it 'initializes the form' do
        get :show, params: { organization_id: organization.id, position_id: position.id }
        expect(assigns(:form)).to be_a(PositionAbilityMilestonesForm)
        expect(assigns(:form).model).to eq(position)
      end
    end

    context 'when user cannot view position' do
      before do
        allow_any_instance_of(PositionPolicy).to receive(:show?).and_return(false)
      end

      it 'redirects when authorization fails' do
        get :show, params: { organization_id: organization.id, position_id: position.id }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end

  describe 'PATCH #update' do
    context 'when user can update position' do
      before do
        allow_any_instance_of(PositionPolicy).to receive(:update?).and_return(true)
      end

      it 'updates associations successfully' do
        milestone_data = {
          ability1.id.to_s => '3',
          ability2.id.to_s => '5',
          ability3.id.to_s => '0'
        }

        patch :update, params: {
          organization_id: organization.id,
          position_id: position.id,
          position_ability_milestones_form: {
            ability_milestones: milestone_data
          }
        }

        expect(response).to redirect_to(organization_position_path(organization, position))
        expect(flash[:notice]).to be_present

        expect(position.position_abilities.find_by(ability: ability1).milestone_level).to eq(3)
        expect(position.position_abilities.find_by(ability: ability2).milestone_level).to eq(5)
        expect(position.position_abilities.find_by(ability: ability3)).to be_nil
      end

      it 'handles form validation errors' do
        milestone_data = {
          ability1.id.to_s => '6' # Invalid milestone level
        }

        patch :update, params: {
          organization_id: organization.id,
          position_id: position.id,
          position_ability_milestones_form: {
            ability_milestones: milestone_data
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:show)
      end
    end

    context 'when user cannot update position' do
      before do
        allow_any_instance_of(PositionPolicy).to receive(:update?).and_return(false)
        allow_any_instance_of(PositionPolicy).to receive(:show?).and_return(true)
      end

      it 'redirects when authorization fails' do
        patch :update, params: {
          organization_id: organization.id,
          position_id: position.id,
          position_ability_milestones_form: {
            ability_milestones: { ability1.id.to_s => '3' }
          }
        }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end
end
