require 'rails_helper'

RSpec.describe AspirationForm, type: :form do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:aspiration) { build(:aspiration, organization: organization) }
  let(:form) { AspirationForm.new(aspiration) }

  before do
    form.current_person = person
  end

  describe 'validations' do
    it 'requires name' do
      params = { name: nil, sort_order: 1, organization_id: organization.id, version_type: 'ready' }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:name]).to include("can't be blank")
    end

    it 'requires sort_order' do
      params = { name: 'Test', sort_order: nil, organization_id: organization.id, version_type: 'ready' }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:sort_order]).to include("can't be blank")
    end

    it 'requires organization_id' do
      params = { name: 'Test', sort_order: 1, organization_id: nil, version_type: 'ready' }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:organization_id]).to include("can't be blank")
    end

    it 'requires version_type for new records' do
      params = { name: 'Test', sort_order: 1, organization_id: organization.id, version_type: nil }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:version_type]).to include("can't be blank")
    end

    it 'requires version_type for existing records' do
      existing_aspiration = create(:aspiration, organization: organization, semantic_version: '1.0.0')
      form = AspirationForm.new(existing_aspiration)
      form.current_person = person
      params = { name: 'Updated', description: existing_aspiration.description, sort_order: existing_aspiration.sort_order, organization_id: existing_aspiration.organization_id, version_type: nil }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:version_type]).to include("can't be blank")
    end

    it 'validates version_type for new records' do
      params = { name: 'Test', sort_order: 1, organization_id: organization.id, version_type: 'invalid' }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:version_type]).to be_present
    end

    it 'validates version_type for existing records' do
      existing_aspiration = create(:aspiration, organization: organization, semantic_version: '1.0.0')
      form = AspirationForm.new(existing_aspiration)
      form.current_person = person
      params = { name: 'Updated', description: existing_aspiration.description, sort_order: existing_aspiration.sort_order, organization_id: existing_aspiration.organization_id, version_type: 'ready' }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:version_type]).to be_present
    end
  end

  describe 'version calculation' do
    context 'for new records' do
      it 'sets version to 1.0.0 for ready' do
        params = {
          name: 'Test',
          sort_order: 1,
          organization_id: organization.id,
          version_type: 'ready'
        }
        form.instance_variable_set(:@form_data_empty, false)
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(aspiration.reload.semantic_version).to eq('1.0.0')
      end

      it 'sets version to 0.1.0 for nearly_ready' do
        params = {
          name: 'Test',
          sort_order: 1,
          organization_id: organization.id,
          version_type: 'nearly_ready'
        }
        form.instance_variable_set(:@form_data_empty, false)
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(aspiration.reload.semantic_version).to eq('0.1.0')
      end

      it 'sets version to 0.0.1 for early_draft' do
        params = {
          name: 'Test',
          sort_order: 1,
          organization_id: organization.id,
          version_type: 'early_draft'
        }
        form.instance_variable_set(:@form_data_empty, false)
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(aspiration.reload.semantic_version).to eq('0.0.1')
      end
    end

    context 'for existing records' do
      let(:existing_aspiration) { create(:aspiration, organization: organization, semantic_version: '1.2.3') }
      let(:form) { AspirationForm.new(existing_aspiration) }

      before do
        form.current_person = person
        form.instance_variable_set(:@form_data_empty, false)
      end

      it 'bumps major version for fundamental change' do
        params = {
          name: 'Updated',
          description: existing_aspiration.description,
          sort_order: existing_aspiration.sort_order,
          organization_id: existing_aspiration.organization_id,
          version_type: 'fundamental'
        }
        expect(form.validate(params)).to be true
        form.save
        expect(existing_aspiration.reload.semantic_version).to eq('2.0.0')
      end

      it 'bumps minor version for clarifying change' do
        params = {
          name: 'Updated',
          description: existing_aspiration.description,
          sort_order: existing_aspiration.sort_order,
          organization_id: existing_aspiration.organization_id,
          version_type: 'clarifying'
        }
        expect(form.validate(params)).to be true
        form.save
        expect(existing_aspiration.reload.semantic_version).to eq('1.3.0')
      end

      it 'bumps patch version for insignificant change' do
        params = {
          name: 'Updated',
          description: existing_aspiration.description,
          sort_order: existing_aspiration.sort_order,
          organization_id: existing_aspiration.organization_id,
          version_type: 'insignificant'
        }
        expect(form.validate(params)).to be true
        form.save
        expect(existing_aspiration.reload.semantic_version).to eq('1.2.4')
      end
    end
  end
end

