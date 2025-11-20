require 'rails_helper'

RSpec.describe AssignmentForm, type: :form do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:assignment) { build(:assignment, company: organization) }
  let(:form) { AssignmentForm.new(assignment) }

  before do
    form.current_person = person
  end

  describe 'validations' do
    it 'requires title' do
      params = { title: nil, tagline: 'Test tagline', version_type: 'ready' }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:title]).to include("can't be blank")
    end

    it 'requires tagline' do
      params = { title: 'Test Assignment', tagline: nil, version_type: 'ready' }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:tagline]).to include("can't be blank")
    end

    it 'requires version_type for new records' do
      params = { title: 'Test Assignment', tagline: 'Test tagline', version_type: nil }
      form.instance_variable_set(:@form_data_empty, false)
      expect(form.validate(params)).to be false
      expect(form.errors[:version_type]).to include("can't be blank")
    end
  end

  describe 'version calculation' do
    context 'for new records' do
      it 'sets version to 1.0.0 for ready' do
        params = { title: 'Test Assignment', tagline: 'Test tagline', version_type: 'ready' }
        form.instance_variable_set(:@form_data_empty, false)
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(assignment.reload.semantic_version).to eq('1.0.0')
      end

      it 'sets version to 0.0.1 for early_draft' do
        params = { title: 'Test Assignment', tagline: 'Test tagline', version_type: 'early_draft' }
        form.instance_variable_set(:@form_data_empty, false)
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(assignment.reload.semantic_version).to eq('0.0.1')
      end
    end

    context 'for existing records' do
      let(:existing_assignment) { create(:assignment, company: organization, semantic_version: '3.2.1') }
      let(:form) { AssignmentForm.new(existing_assignment) }

      before do
        form.current_person = person
        form.instance_variable_set(:@form_data_empty, false)
      end

      it 'bumps major version for fundamental change' do
        params = { title: 'Updated Assignment', tagline: existing_assignment.tagline, version_type: 'fundamental' }
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(existing_assignment.reload.semantic_version).to eq('4.0.0')
      end

      it 'bumps minor version for clarifying change' do
        params = { title: 'Updated Assignment', tagline: existing_assignment.tagline, version_type: 'clarifying' }
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(existing_assignment.reload.semantic_version).to eq('3.3.0')
      end

      it 'bumps patch version for insignificant change' do
        params = { title: 'Updated Assignment', tagline: existing_assignment.tagline, version_type: 'insignificant' }
        expect(form.validate(params)).to be true
        expect(form.save).to be true
        expect(existing_assignment.reload.semantic_version).to eq('3.2.2')
      end
    end
  end
end

