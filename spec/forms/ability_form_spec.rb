require 'rails_helper'

RSpec.describe AbilityForm, type: :form do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:ability) { Ability.new(company: company) }
  let(:form) { AbilityForm.new(ability) }

  let(:valid_params) do
    {
      name: 'Test Ability',
      description: 'A test ability',
      company_id: company.id,
      version_type: 'ready',
      milestone_1_description: 'Basic understanding'
    }
  end

  before do
    form.current_person = person
    form.instance_variable_set(:@form_data_empty, false)
  end

  describe '#save' do
    it 'sets created_by and updated_by before Reform persists (OURGRUUV-3V4)' do
      expect(form.validate(valid_params)).to be true

      save_snapshots = []
      allow(ability).to receive(:save).and_wrap_original do |method, *args|
        save_snapshots << {
          created_by_id: ability.created_by_id,
          updated_by_id: ability.updated_by_id
        }
        method.call(*args)
      end

      expect(form.save).to be true
      expect(save_snapshots).not_to be_empty
      expect(save_snapshots).to all(include(created_by_id: person.id, updated_by_id: person.id))

      ability.reload
      expect(ability.created_by).to eq(person)
      expect(ability.updated_by).to eq(person)
      expect(ability.semantic_version).to eq('1.0.0')
    end

    it 'updates updated_by without changing created_by' do
      existing = create(
        :ability,
        company: company,
        created_by: person,
        updated_by: person,
        semantic_version: '1.0.0',
        milestone_1_description: 'Basic understanding'
      )
      other_person = create(:person)
      update_form = AbilityForm.new(existing)
      update_form.current_person = other_person
      update_form.instance_variable_set(:@form_data_empty, false)

      params = {
        name: existing.name,
        description: existing.description,
        company_id: company.id,
        version_type: 'insignificant',
        milestone_1_description: existing.milestone_1_description
      }

      expect(update_form.validate(params)).to be true
      expect(update_form.save).to be true

      existing.reload
      expect(existing.created_by).to eq(person)
      expect(existing.updated_by).to eq(other_person)
    end
  end
end
