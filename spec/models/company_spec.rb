require 'rails_helper'

RSpec.describe Company, type: :model do
  let(:company) { Company.find_or_create_by!(name: 'Test Company', type: 'Company') }

  describe 'associations' do
    it { should have_many(:company_label_preferences).dependent(:destroy) }
  end

  describe '#label_for' do
    context 'when company has a custom label preference' do
      before do
        create(:company_label_preference, company: company, label_key: 'prompt', label_value: 'Reflection')
      end

      it 'returns the custom label value' do
        expect(company.label_for('prompt', 'Prompt')).to eq('Reflection')
      end

      it 'returns custom label even without default' do
        expect(company.label_for('prompt')).to eq('Reflection')
      end
    end

    context 'when company has no custom label preference' do
      it 'returns the default value when provided' do
        expect(company.label_for('prompt', 'Prompt')).to eq('Prompt')
      end

      it 'returns titleized key when no default provided' do
        expect(company.label_for('prompt')).to eq('Prompt')
      end
    end

    context 'when preference exists but label_value is blank' do
      before do
        create(:company_label_preference, company: company, label_key: 'prompt', label_value: '')
      end

      it 'returns the default value' do
        expect(company.label_for('prompt', 'Prompt')).to eq('Prompt')
      end
    end
  end
end
