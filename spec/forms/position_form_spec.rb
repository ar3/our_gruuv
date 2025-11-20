require 'rails_helper'

RSpec.describe PositionForm, type: :form do
  let(:organization) { create(:organization) }
  let(:position_type) { create(:position_type, organization: organization) }
  let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
  let(:person) { create(:person) }
  let(:position) { build(:position, position_type: position_type, position_level: position_level) }
  let(:form) { PositionForm.new(position) }

  before do
    form.current_person = person
  end

  describe 'validations' do
    it 'requires position_type_id' do
      params = { position_type_id: nil, position_level_id: position_level.id, version_type: 'ready' }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:position_type_id]).to include("can't be blank")
    end

    it 'requires position_level_id' do
      params = { position_type_id: position_type.id, position_level_id: nil, version_type: 'ready' }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:position_level_id]).to include("can't be blank")
    end

    it 'requires version_type for new records' do
      params = { position_type_id: position_type.id, position_level_id: position_level.id, version_type: nil }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:version_type]).to include("can't be blank")
    end
  end

  describe 'version calculation' do
    context 'for new records' do
      it 'sets version to 1.0.0 for ready' do
        params = { position_type_id: position_type.id, position_level_id: position_level.id, version_type: 'ready' }
        form.instance_variable_set(:@form_data_empty, false)
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(position.reload.semantic_version).to eq('1.0.0')
      end

      it 'sets version to 0.0.1 for early_draft' do
        params = { position_type_id: position_type.id, position_level_id: position_level.id, version_type: 'early_draft' }
        form.instance_variable_set(:@form_data_empty, false)
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(position.reload.semantic_version).to eq('0.0.1')
      end
    end

    context 'for existing records' do
      let(:existing_position) { create(:position, position_type: position_type, position_level: position_level, semantic_version: '2.1.3') }
      let(:form) { PositionForm.new(existing_position) }

      before do
        form.current_person = person
        form.instance_variable_set(:@form_data_empty, false)
      end

      it 'bumps major version for fundamental change' do
        params = { position_type_id: position_type.id, position_level_id: position_level.id, version_type: 'fundamental' }
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(existing_position.reload.semantic_version).to eq('3.0.0')
      end

      it 'bumps minor version for clarifying change' do
        params = { position_type_id: position_type.id, position_level_id: position_level.id, version_type: 'clarifying' }
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(existing_position.reload.semantic_version).to eq('2.2.0')
      end

      it 'bumps patch version for insignificant change' do
        params = { position_type_id: position_type.id, position_level_id: position_level.id, version_type: 'insignificant' }
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(existing_position.reload.semantic_version).to eq('2.1.4')
      end
    end
  end
end

