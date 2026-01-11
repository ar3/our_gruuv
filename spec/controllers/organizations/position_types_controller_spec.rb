require 'rails_helper'

RSpec.describe Organizations::PositionTypesController, type: :controller do
  let(:organization) { create(:organization) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let(:person) { create(:person) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
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

    it 'uses PositionTypeSaveService to create' do
      allow(PositionTypeSaveService).to receive(:create) do |args|
        # Simulate what the service does - modify the position_type
        args[:position_type].assign_attributes(args[:params]) if args[:params]
        args[:position_type].save!
        Result.ok(args[:position_type])
      end
      
      post :create, params: { 
        organization_id: organization.id,
        position_type: {
          position_major_level_id: position_major_level.id,
          external_title: 'Test Position Type'
        }
      }
      
      expect(PositionTypeSaveService).to have_received(:create)
    end

    it 'creates a position type successfully' do
      expect {
        post :create, params: { 
          organization_id: organization.id,
          position_type: {
            position_major_level_id: position_major_level.id,
            external_title: 'New Position Type'
          }
        }
      }.to change(PositionType, :count).by(1)
      
      expect(response).to redirect_to(organization_position_type_path(organization, PositionType.last))
      expect(flash[:notice]).to eq('Position type was successfully created.')
    end

    it 'renders new with errors when creation fails' do
      post :create, params: { 
        organization_id: organization.id,
        position_type: {
          position_major_level_id: position_major_level.id,
          external_title: '' # Invalid
        }
      }
      
      expect(response).to render_template(:new)
      expect(response.status).to eq(422)
    end
  end

  describe 'PATCH #update' do
    it 'authorizes the position_type' do
      allow(controller).to receive(:authorize).and_call_original
      expect(controller).to receive(:authorize).with(position_type)
      patch :update, params: { 
        organization_id: organization.id,
        id: position_type.id,
        position_type: {
          external_title: 'Updated Title'
        }
      }
    end

    it 'uses PositionTypeSaveService to update' do
      allow(PositionTypeSaveService).to receive(:update).and_return(Result.ok(position_type))
      
      patch :update, params: { 
        organization_id: organization.id,
        id: position_type.id,
        position_type: {
          external_title: 'Updated Title'
        }
      }
      
      expect(PositionTypeSaveService).to have_received(:update)
    end

    it 'updates a position type successfully' do
      patch :update, params: { 
        organization_id: organization.id,
        id: position_type.id,
        position_type: {
          external_title: 'Updated Title'
        }
      }
      
      expect(position_type.reload.external_title).to eq('Updated Title')
      expect(response).to redirect_to(organization_position_type_path(organization, position_type))
      expect(flash[:notice]).to eq('Position type was successfully updated.')
    end

    it 'updates position levels when major level changes' do
      new_major_level = create(:position_major_level, major_level: 2, set_name: 'Engineering')
      position1 = create(:position, position_type: position_type, position_level: position_level)
      original_level_value = position_level.level # e.g., "1.1"
      minor_level = original_level_value.split('.').last # e.g., "1"
      expected_new_level = "#{new_major_level.major_level}.#{minor_level}" # e.g., "2.1"
      
      patch :update, params: { 
        organization_id: organization.id,
        id: position_type.id,
        position_type: {
          position_major_level_id: new_major_level.id
        }
      }
      
      expect(position_type.reload.position_major_level_id).to eq(new_major_level.id)
      new_position_level = PositionLevel.find_by(position_major_level: new_major_level, level: expected_new_level)
      expect(new_position_level).to be_present
      expect(position1.reload.position_level).to eq(new_position_level)
      expect(position1.reload.position_level.level).to eq(expected_new_level)
    end

    it 'renders edit with errors when update fails' do
      patch :update, params: { 
        organization_id: organization.id,
        id: position_type.id,
        position_type: {
          external_title: '' # Invalid
        }
      }
      
      expect(response).to render_template(:edit)
      expect(response.status).to eq(422)
    end
  end

  describe 'DELETE #destroy' do
    it 'authorizes the position_type' do
      allow(controller).to receive(:authorize).and_call_original
      expect(controller).to receive(:authorize).with(position_type)
      delete :destroy, params: { 
        organization_id: organization.id,
        id: position_type.id
      }
    end

    it 'uses PositionTypeSaveService to delete' do
      allow(PositionTypeSaveService).to receive(:delete).and_return(Result.ok(position_type))
      allow(position_type).to receive(:destroy).and_return(true)
      
      delete :destroy, params: { 
        organization_id: organization.id,
        id: position_type.id
      }
      
      expect(PositionTypeSaveService).to have_received(:delete)
    end

    it 'deletes a position type successfully' do
      position_type_id = position_type.id
      
      expect {
        delete :destroy, params: { 
          organization_id: organization.id,
          id: position_type.id
        }
      }.to change(PositionType, :count).by(-1)
      
      expect(PositionType.find_by(id: position_type_id)).to be_nil
      expect(response).to redirect_to(organization_position_types_path(organization))
      expect(flash[:notice]).to eq('Position type was successfully deleted.')
    end

    it 'redirects with alert when deletion fails' do
      allow(PositionTypeSaveService).to receive(:delete).and_return(Result.err('Deletion failed'))
      
      delete :destroy, params: { 
        organization_id: organization.id,
        id: position_type.id
      }
      
      expect(response).to redirect_to(organization_position_types_path(organization))
      expect(flash[:alert]).to eq('Deletion failed')
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

      it 'clones position assignments with min, max, and type attributes' do
        # Create a different position level for the target
        target_level = create(:position_level, position_major_level: position_major_level)
        
        # Create source position assignments with min, max, and type
        assignment1 = create(:assignment)
        assignment2 = create(:assignment)
        
        source_pa1 = create(:position_assignment,
          position: source_position,
          assignment: assignment1,
          assignment_type: 'required',
          min_estimated_energy: 20,
          max_estimated_energy: 40
        )
        source_pa2 = create(:position_assignment,
          position: source_position,
          assignment: assignment2,
          assignment_type: 'suggested',
          min_estimated_energy: 10,
          max_estimated_energy: 30
        )
        
        post :clone_positions, params: { 
          organization_id: organization.id,
          id: position_type.id, 
          source_position_id: source_position.id, 
          target_level_ids: [target_level.id] 
        }
        
        # Find the cloned position
        cloned_position = Position.find_by(position_type: position_type, position_level: target_level)
        expect(cloned_position).to be_present
        
        # Verify the cloned position assignments
        cloned_assignments = cloned_position.position_assignments.order(:id)
        expect(cloned_assignments.count).to eq(2)
        
        # Verify first assignment
        cloned_pa1 = cloned_assignments.find_by(assignment: assignment1)
        expect(cloned_pa1).to be_present
        expect(cloned_pa1.assignment_type).to eq('required')
        expect(cloned_pa1.min_estimated_energy).to eq(20)
        expect(cloned_pa1.max_estimated_energy).to eq(40)
        
        # Verify second assignment
        cloned_pa2 = cloned_assignments.find_by(assignment: assignment2)
        expect(cloned_pa2).to be_present
        expect(cloned_pa2.assignment_type).to eq('suggested')
        expect(cloned_pa2.min_estimated_energy).to eq(10)
        expect(cloned_pa2.max_estimated_energy).to eq(30)
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

