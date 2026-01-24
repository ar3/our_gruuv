require 'rails_helper'

RSpec.describe TitleSaveService, type: :service do
  let(:company) { create(:organization, type: 'Company') }
  let(:position_major_level1) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:position_major_level2) { create(:position_major_level, major_level: 2, set_name: 'Engineering') }
  let(:position_level1) { create(:position_level, position_major_level: position_major_level1, level: '1.1') }
  let(:position_level2) { create(:position_level, position_major_level: position_major_level1, level: '1.2') }
  let(:title) { create(:title, organization: company, position_major_level: position_major_level1) }
  let(:position1) { create(:position, title: title, position_level: position_level1) }
  let(:position2) { create(:position, title: title, position_level: position_level2) }

  describe '.create' do
    let(:new_title) { Title.new(organization: company, position_major_level: position_major_level1) }
    let(:params) { { external_title: 'Test Title' } }

    it 'creates a title successfully' do
      result = described_class.create(title: new_title, params: params)
      
      expect(result.ok?).to be true
      expect(result.value).to be_persisted
      expect(result.value.external_title).to eq('Test Title')
    end

    it 'returns error when validation fails' do
      result = described_class.create(title: new_title, params: {})
      
      expect(result.ok?).to be false
      expect(result.error).to be_present
    end
  end

  describe '.update' do
    context 'when position_major_level_id does not change' do
      it 'updates the title successfully' do
        params = { external_title: 'Updated Title' }
        result = described_class.update(title: title, params: params)
        
        expect(result.ok?).to be true
        expect(title.reload.external_title).to eq('Updated Title')
      end

      it 'does not update associated positions' do
        position1 # Create position
        original_position_level_id = position1.position_level_id
        
        params = { external_title: 'Updated Title' }
        described_class.update(title: title, params: params)
        
        expect(position1.reload.position_level_id).to eq(original_position_level_id)
      end
    end

    context 'when position_major_level_id changes' do
      before do
        position1 # Create positions
        position2
      end

      it 'updates the title successfully' do
        params = { position_major_level_id: position_major_level2.id }
        result = described_class.update(title: title, params: params)
        
        expect(result.ok?).to be true
        expect(title.reload.position_major_level_id).to eq(position_major_level2.id)
      end

      it 'updates all associated positions to use position levels from the new major level' do
        # Create position levels in the new major level with the new level format
        # Old level "1.1" (minor part "1") becomes "2.1" when major level changes to 2
        # Old level "1.2" (minor part "2") becomes "2.2" when major level changes to 2
        new_position_level1 = create(:position_level, position_major_level: position_major_level2, level: '2.1')
        new_position_level2 = create(:position_level, position_major_level: position_major_level2, level: '2.2')
        
        params = { position_major_level_id: position_major_level2.id }
        described_class.update(title: title, params: params)
        
        expect(position1.reload.position_level).to eq(new_position_level1)
        expect(position2.reload.position_level).to eq(new_position_level2)
      end

      it 'creates position levels in the new major level if they do not exist' do
        params = { position_major_level_id: position_major_level2.id }
        described_class.update(title: title, params: params)
        
        # Verify position levels were created with the new format
        # Old level "1.1" (minor part "1") becomes "2.1" when major level changes to 2
        # Old level "1.2" (minor part "2") becomes "2.2" when major level changes to 2
        new_level1 = PositionLevel.find_by(position_major_level: position_major_level2, level: '2.1')
        new_level2 = PositionLevel.find_by(position_major_level: position_major_level2, level: '2.2')
        
        expect(new_level1).to be_present
        expect(new_level2).to be_present
        expect(position1.reload.position_level).to eq(new_level1)
        expect(position2.reload.position_level).to eq(new_level2)
      end

      it 'creates new position levels with the correct format combining new major level and minor level' do
        params = { position_major_level_id: position_major_level2.id }
        described_class.update(title: title, params: params)
        
        # Old level "1.1" should become "2.1" (major level 2 + minor level 1)
        # Old level "1.2" should become "2.2" (major level 2 + minor level 2)
        expect(position1.reload.position_level.level).to eq('2.1')
        expect(position2.reload.position_level.level).to eq('2.2')
      end

      it 'returns error when validation fails' do
        params = { external_title: '' }
        result = described_class.update(title: title, params: params)
        
        expect(result.ok?).to be false
        expect(result.error).to be_present
      end
    end
  end

  describe '.delete' do
    before do
      position1 # Create position
    end

    it 'deletes the title successfully' do
      result = described_class.delete(title: title)
      
      expect(result.ok?).to be true
      expect(Title.find_by(id: title.id)).to be_nil
    end

    it 'deletes associated positions due to dependent: :destroy' do
      position_id = position1.id
      described_class.delete(title: title)
      
      expect(Position.find_by(id: position_id)).to be_nil
    end
  end
end
