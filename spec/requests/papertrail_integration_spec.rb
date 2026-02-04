require 'rails_helper'

RSpec.describe 'PaperTrail Integration', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }

  before do
    # Enable PaperTrail for these tests
    PaperTrail.enabled = true
    sign_in_as_teammate_for_request(person, organization)
  end

  after do
    # Disable PaperTrail after tests
    PaperTrail.enabled = false
  end

  describe 'controller_info storage in meta column' do
    it 'stores controller info in meta JSONB column, not as direct attributes' do
      expect {
        post "/organizations/#{organization.id}/abilities", params: {
          ability: {
            name: 'Test Ability',
            description: 'A test ability',
            organization_id: organization.id,
            milestone_1_description: 'Basic understanding',
            version_type: 'ready'
          }
        }
      }.not_to raise_error(ActiveModel::UnknownAttributeError)
    end

    it 'creates version records with meta column populated' do
      post "/organizations/#{organization.id}/abilities", params: {
        ability: {
          name: 'Test Ability',
          description: 'A test ability',
          organization_id: organization.id,
          milestone_1_description: 'Basic understanding',
          version_type: 'ready'
        }
      }

      expect(response).to have_http_status(:redirect)
      
      # Check that a version was created
      ability = Ability.last
      expect(ability).to be_present
      
      # Check that PaperTrail created a version
      versions = PaperTrail::Version.where(item: ability)
      expect(versions.count).to eq(1)
      
      version = versions.first
      expect(version.meta).to be_present
      # Controller sets current_teammate_id, not current_person_id
      expect(version.meta['current_teammate_id']).to eq(teammate.id)
    end

    it 'handles impersonation info in meta column' do
      # Simulate impersonation - controller uses session[:impersonating_teammate_id]
      allow_any_instance_of(ApplicationController).to receive(:impersonating?).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:session).and_return({ impersonating_teammate_id: teammate.id })

      post "/organizations/#{organization.id}/abilities", params: {
        ability: {
          name: 'Test Ability',
          description: 'A test ability',
          organization_id: organization.id,
          milestone_1_description: 'Basic understanding',
          version_type: 'ready'
        }
      }

      expect(response).to have_http_status(:redirect)
      
      ability = Ability.last
      versions = PaperTrail::Version.where(item: ability)
      version = versions.first
      
      # Controller sets impersonating_teammate_id, not impersonating_person_id
      expect(version.meta['impersonating_teammate_id']).to eq(teammate.id)
    end

    it 'does not try to set current_person_id as direct attribute' do
      # This test ensures PaperTrail doesn't try to set current_person_id as a direct attribute
      # which would cause ActiveModel::UnknownAttributeError
      
      expect {
        post "/organizations/#{organization.id}/abilities", params: {
          ability: {
            name: 'Test Ability',
            description: 'A test ability',
            organization_id: organization.id,
            milestone_1_description: 'Basic understanding',
            version_type: 'ready'
          }
        }
      }.not_to raise_error(ActiveModel::UnknownAttributeError)
    end
  end

  describe 'PaperTrail configuration validation' do
    it 'ensures meta column exists in versions table' do
      # Check that the versions table has the meta column
      columns = ActiveRecord::Base.connection.columns('versions')
      meta_column = columns.find { |c| c.name == 'meta' }
      
      expect(meta_column).to be_present
      expect(meta_column.type).to eq(:jsonb)
    end

    it 'ensures controller_info is properly configured' do
      # Test that PaperTrail.request.controller_info works without errors
      expect {
        PaperTrail.request.controller_info = {
          current_person_id: person.id,
          impersonating_person_id: nil
        }
      }.not_to raise_error
    end
  end

  describe 'multiple model PaperTrail integration' do
    it 'works with Ability model' do
      expect {
        post "/organizations/#{organization.id}/abilities", params: {
          ability: {
            name: 'Test Ability',
            description: 'A test ability',
            organization_id: organization.id,
            milestone_1_description: 'Basic understanding',
            version_type: 'ready'
          }
        }
      }.not_to raise_error(ActiveModel::UnknownAttributeError)
    end

    it 'works with Organization model updates' do
      expect {
        patch "/organizations/#{organization.id}", params: {
          organization: {
            name: 'Updated Organization Name'
          }
        }
      }.not_to raise_error(ActiveModel::UnknownAttributeError)
    end
  end
end
