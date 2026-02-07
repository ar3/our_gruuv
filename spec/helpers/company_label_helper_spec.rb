require 'rails_helper'

RSpec.describe CompanyLabelHelper, type: :helper do
  let(:company) { create(:organization, :company, name: 'Test Company') }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: company) }

  before do
    # Define the controller methods that are available in helpers
    def helper.current_organization
      @current_organization
    end

    def helper.current_company_teammate
      @current_company_teammate
    end

    helper.instance_variable_set(:@current_organization, company)
    helper.instance_variable_set(:@current_company_teammate, teammate)
  end

  describe '#company_label_for' do
    context 'when company has a custom label preference' do
      before do
        create(:company_label_preference, company: company, label_key: 'prompt', label_value: 'Reflection')
      end

      it 'returns the custom label value' do
        expect(helper.company_label_for('prompt', 'Prompt')).to eq('Reflection')
      end

      it 'returns custom label even without default' do
        expect(helper.company_label_for('prompt')).to eq('Reflection')
      end
    end

    context 'when company has no custom label preference' do
      it 'returns the default value when provided' do
        expect(helper.company_label_for('prompt', 'Prompt')).to eq('Prompt')
      end

      it 'returns titleized key when no default provided' do
        expect(helper.company_label_for('prompt')).to eq('Prompt')
      end
    end

    context 'when organization is not a company' do
      let(:department) { create(:department, company: company, name: 'Dept') }

      before do
        helper.instance_variable_set(:@current_organization, department)
      end

      it 'returns default value' do
        expect(helper.company_label_for('prompt', 'Prompt')).to eq('Prompt')
      end
    end

    context 'when current_organization is nil' do
      before do
        helper.instance_variable_set(:@current_organization, nil)
      end

      it 'returns default value' do
        expect(helper.company_label_for('prompt', 'Prompt')).to eq('Prompt')
      end
    end
  end

  describe '#company_label_plural' do
    context 'when company has a custom label preference' do
      before do
        create(:company_label_preference, company: company, label_key: 'prompt', label_value: 'Reflection')
      end

      it 'returns the pluralized custom label' do
        expect(helper.company_label_plural('prompt', 'Prompt')).to eq('Reflections')
      end
    end

    context 'when company has no custom label preference' do
      it 'returns the pluralized default value' do
        expect(helper.company_label_plural('prompt', 'Prompt')).to eq('Prompts')
      end
    end

    context 'with kudos_point key' do
      it 'returns pluralized default when no preference' do
        expect(helper.company_label_plural('kudos_point', 'Kudos Point')).to eq('Kudos Points')
      end

      it 'returns pluralized custom label when preference set' do
        create(:company_label_preference, company: company, label_key: 'kudos_point', label_value: 'Star')
        expect(helper.company_label_plural('kudos_point', 'Kudos Point')).to eq('Stars')
      end
    end
  end
end
