require 'rails_helper'

RSpec.describe Aspiration, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:aspiration) { create(:aspiration, organization: organization, name: 'Test Aspiration') }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(aspiration).to be_valid
    end

    it 'requires a name' do
      aspiration.name = nil
      expect(aspiration).not_to be_valid
      expect(aspiration.errors[:name]).to include("can't be blank")
    end

    it 'requires a sort_order' do
      aspiration.sort_order = nil
      expect(aspiration).not_to be_valid
      expect(aspiration.errors[:sort_order]).to include("can't be blank")
    end

    it 'enforces unique names within the same organization' do
      create(:aspiration, organization: organization, name: 'Unique Name')
      
      duplicate = build(:aspiration, organization: organization, name: 'Unique Name')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end

    it 'allows same name in different organizations' do
      other_organization = create(:organization, :company)
      create(:aspiration, organization: organization, name: 'Shared Name')
      
      other_aspiration = build(:aspiration, organization: other_organization, name: 'Shared Name')
      expect(other_aspiration).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to an organization' do
      expect(aspiration.organization).to eq(organization)
    end

    it 'has many observation_ratings' do
      expect(aspiration.observation_ratings).to be_empty
    end

    it 'has many observations through observation_ratings' do
      expect(aspiration.observations).to be_empty
    end
  end

  describe 'scopes' do
    it 'orders by sort_order then name' do
      asp1 = create(:aspiration, organization: organization, name: 'Zebra', sort_order: 2)
      asp2 = create(:aspiration, organization: organization, name: 'Alpha', sort_order: 1)
      asp3 = create(:aspiration, organization: organization, name: 'Beta', sort_order: 1)
      
      expect(Aspiration.ordered).to eq([asp2, asp3, asp1])
    end

    it 'filters within hierarchy' do
      department = create(:organization, :department, parent: organization)
      asp1 = create(:aspiration, organization: organization)
      asp2 = create(:aspiration, organization: department)
      
      expect(Aspiration.within_hierarchy(organization)).to include(asp1, asp2)
    end
  end

  describe 'soft delete' do
    it 'soft deletes an aspiration' do
      aspiration.soft_delete!
      expect(aspiration.deleted?).to be true
      expect(aspiration.deleted_at).to be_present
    end

    it 'excludes soft deleted aspirations by default' do
      aspiration.soft_delete!
      expect(Aspiration.all).not_to include(aspiration)
    end

    it 'includes soft deleted with with_deleted scope' do
      aspiration.soft_delete!
      expect(Aspiration.with_deleted).to include(aspiration)
    end
  end

  describe '#to_param' do
    it 'returns id-name-parameterized format based on name' do
      aspiration = create(:aspiration, organization: organization, name: 'Technical Excellence')
      expect(aspiration.to_param).to eq("#{aspiration.id}-technical-excellence")
    end

    it 'handles special characters in name' do
      aspiration = create(:aspiration, organization: organization, name: 'Team & Collaboration!')
      expect(aspiration.to_param).to eq("#{aspiration.id}-team-collaboration")
    end
  end

  describe '.find_by_param' do
    let(:aspiration) { create(:aspiration, organization: organization, name: 'Test Aspiration') }

    it 'finds by numeric id' do
      expect(Aspiration.find_by_param(aspiration.id.to_s)).to eq(aspiration)
    end

    it 'finds by id-name-parameterized format' do
      param = "#{aspiration.id}-test-aspiration"
      expect(Aspiration.find_by_param(param)).to eq(aspiration)
    end

    it 'extracts id from id-name format' do
      param = "#{aspiration.id}-some-other-name"
      expect(Aspiration.find_by_param(param)).to eq(aspiration)
    end

    it 'raises error for invalid id' do
      expect {
        Aspiration.find_by_param('999999')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

