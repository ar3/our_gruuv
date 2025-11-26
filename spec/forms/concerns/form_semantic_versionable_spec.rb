require 'rails_helper'

RSpec.describe FormSemanticVersionable, type: :form do
  # Use AspirationForm which includes the concern
  let(:organization) { create(:organization) }
  let(:test_model) { build(:aspiration, organization: organization) }
  let(:form) { AspirationForm.new(test_model) }
  let(:person) { create(:person) }

  before do
    form.current_person = person
  end

  describe '#calculate_semantic_version' do
    context 'for new records' do
      it 'returns 1.0.0 for ready' do
        form.version_type = 'ready'
        expect(form.calculate_semantic_version).to eq('1.0.0')
      end

      it 'returns 0.1.0 for nearly_ready' do
        form.version_type = 'nearly_ready'
        expect(form.calculate_semantic_version).to eq('0.1.0')
      end

      it 'returns 0.0.1 for early_draft' do
        form.version_type = 'early_draft'
        expect(form.calculate_semantic_version).to eq('0.0.1')
      end
    end

    context 'for existing records' do
      let(:existing_model) { create(:aspiration, organization: organization, semantic_version: '2.3.4') }
      let(:form) { AspirationForm.new(existing_model) }

      before do
        form.current_person = person
      end

      it 'returns incremented major version for fundamental' do
        form.version_type = 'fundamental'
        expect(form.calculate_semantic_version).to eq('3.0.0')
      end

      it 'returns incremented minor version for clarifying' do
        form.version_type = 'clarifying'
        expect(form.calculate_semantic_version).to eq('2.4.0')
      end

      it 'returns incremented patch version for insignificant' do
        form.version_type = 'insignificant'
        expect(form.calculate_semantic_version).to eq('2.3.5')
      end
    end
  end

  describe 'validations' do
    it 'requires version_type for new records' do
      form.name = 'Test'
      form.sort_order = 1
      form.organization_id = organization.id
      form.version_type = nil
      form.instance_variable_set(:@form_data_empty, false)
      expect(form).not_to be_valid
      expect(form.errors[:version_type]).to be_present
    end

    it 'validates version_type values for new records' do
      form.name = 'Test'
      form.sort_order = 1
      form.organization_id = organization.id
      form.version_type = 'invalid'
      form.instance_variable_set(:@form_data_empty, false)
      expect(form).not_to be_valid
      expect(form.errors[:version_type]).to be_present
    end

    it 'validates version_type values for existing records' do
      existing_model = create(:aspiration, organization: organization)
      form = AspirationForm.new(existing_model)
      form.current_person = person
      form.name = 'Test'
      form.version_type = 'ready' # Invalid for updates
      form.instance_variable_set(:@form_data_empty, false)
      expect(form).not_to be_valid
      expect(form.errors[:version_type]).to be_present
    end
  end
end

