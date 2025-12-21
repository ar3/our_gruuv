require 'rails_helper'

RSpec.describe Organizations::PositionTypesController, type: :controller do
  let(:organization) { create(:organization) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let(:person) { create(:person) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:source_position) { create(:position, position_type: position_type, position_level: position_level) }

  before do
    teammate = sign_in_as_teammate(person, organization)
    teammate.update(can_manage_maap: true)
  end

  describe 'GET #index' do
    it 'authorizes the organization for view_position_types?' do
      allow(controller).to receive(:authorize).and_call_original
      expect(controller).to receive(:authorize).with(anything, :view_position_types?)
      get :index, params: { organization_id: organization.id }
    end
  end

  describe 'GET #new' do
    it 'authorizes the organization for manage_maap?' do
      allow(controller).to receive(:authorize).and_call_original
      expect(controller).to receive(:authorize).with(anything, :manage_maap?)
      get :new, params: { organization_id: organization.id }
    end
  end

  describe 'POST #create' do
    it 'authorizes the organization for manage_maap?' do
      allow(controller).to receive(:authorize).and_call_original
      expect(controller).to receive(:authorize).with(anything, :manage_maap?)
      post :create, params: { 
        organization_id: organization.id,
        position_type: {
          position_major_level_id: position_major_level.id,
          external_title: 'Test Position Type'
        }
      }
    end
  end

  describe 'POST #clone_positions' do
    context 'when position_type is found' do
      before do
        source_position # Create the source position
      end

      it 'authorizes the position_type' do
        allow(controller).to receive(:authorize).and_call_original
        expect(controller).to receive(:authorize).with(position_type)
        post :clone_positions, params: { 
          organization_id: organization.id,
          id: position_type.id, 
          source_position_id: source_position.id, 
          target_level_ids: [position_level.id] 
        }
      end

      it 'successfully clones positions without errors' do
        expect {
          post :clone_positions, params: { 
            organization_id: organization.id,
            id: position_type.id, 
            source_position_id: source_position.id, 
            target_level_ids: [position_level.id] 
          }
        }.not_to raise_error
      end

      it 'redirects to organization_position_type_path with success message when positions are created' do
        # Create a different position level for the target
        target_level = create(:position_level, position_major_level: position_major_level)
        
        post :clone_positions, params: { 
          organization_id: organization.id,
          id: position_type.id, 
          source_position_id: source_position.id, 
          target_level_ids: [target_level.id] 
        }
        
        expect(response).to redirect_to(organization_position_type_path(organization, position_type))
        expect(flash[:notice]).to include('Successfully created')
      end

      it 'redirects to organization_position_type_path with alert when no positions are created' do
        # Create a different position level and a position that already exists for it
        target_level = create(:position_level, position_major_level: position_major_level)
        create(:position, position_type: position_type, position_level: target_level)
        
        post :clone_positions, params: { 
          organization_id: organization.id,
          id: position_type.id, 
          source_position_id: source_position.id, 
          target_level_ids: [target_level.id] 
        }
        
        expect(response).to redirect_to(organization_position_type_path(organization, position_type))
        expect(flash[:alert]).to include('No new positions were created')
      end
    end

    context 'when position_type is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          post :clone_positions, params: { 
            organization_id: organization.id,
            id: 999999, 
            source_position_id: source_position.id, 
            target_level_ids: [position_level.id] 
          }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end

