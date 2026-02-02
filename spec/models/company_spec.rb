require 'rails_helper'

# Tests for Organization's label_for functionality (formerly in Company STI subclass)
RSpec.describe Organization, type: :model do
  let(:organization) { Organization.find_or_create_by!(name: 'Test Organization') }

  describe 'company_label_preferences associations' do
    it { should have_many(:company_label_preferences).dependent(:destroy) }
  end

  describe '#label_for' do
    context 'when organization has a custom label preference' do
      before do
        create(:company_label_preference, company: organization, label_key: 'prompt', label_value: 'Reflection')
      end

      it 'returns the custom label value' do
        expect(organization.label_for('prompt', 'Prompt')).to eq('Reflection')
      end

      it 'returns custom label even without default' do
        expect(organization.label_for('prompt')).to eq('Reflection')
      end
    end

    context 'when organization has no custom label preference' do
      it 'returns the default value when provided' do
        expect(organization.label_for('prompt', 'Prompt')).to eq('Prompt')
      end

      it 'returns titleized key when no default provided' do
        expect(organization.label_for('prompt')).to eq('Prompt')
      end
    end

    context 'when preference exists but label_value is blank' do
      before do
        create(:company_label_preference, company: organization, label_key: 'prompt', label_value: '')
      end

      it 'returns the default value' do
        expect(organization.label_for('prompt', 'Prompt')).to eq('Prompt')
      end
    end
  end
end
