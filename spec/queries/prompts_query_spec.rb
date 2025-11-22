require 'rails_helper'

RSpec.describe PromptsQuery do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: company) }
  let(:template1) { create(:prompt_template, company: company, title: 'Template 1') }
  let(:template2) { create(:prompt_template, company: company, title: 'Template 2') }
  
  # Create prompts owned by the current person so they show up in policy scope
  let!(:prompt1) { create(:prompt, company_teammate: teammate, prompt_template: template1) }
  let!(:prompt2) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template2) }

  describe '#call' do
    it 'returns prompts from policy scope' do
      query = PromptsQuery.new(company, {}, current_person: person)
      results = query.call
      expect(results).to include(prompt1, prompt2)
    end

    it 'filters by template' do
      query = PromptsQuery.new(company, { template: template1.id }, current_person: person)
      results = query.call
      expect(results).to include(prompt1)
      expect(results).not_to include(prompt2)
    end

    it 'filters by status open' do
      query = PromptsQuery.new(company, { status: 'open' }, current_person: person)
      results = query.call
      expect(results).to include(prompt1)
      expect(results).not_to include(prompt2)
    end

    it 'filters by status closed' do
      query = PromptsQuery.new(company, { status: 'closed' }, current_person: person)
      results = query.call
      expect(results).to include(prompt2)
      expect(results).not_to include(prompt1)
    end

    it 'sorts by created_at desc by default' do
      query = PromptsQuery.new(company, {}, current_person: person)
      results = query.call.to_a
      expect(results.first).to eq(prompt2) # Most recent
    end
  end

  describe '#current_filters' do
    it 'returns empty hash when no filters' do
      query = PromptsQuery.new(company, {}, current_person: person)
      expect(query.current_filters).to eq({})
    end

    it 'returns filters when present' do
      query = PromptsQuery.new(company, { template: template1.id, status: 'open' }, current_person: person)
      filters = query.current_filters
      expect(filters[:template]).to eq(template1.id)
      expect(filters[:status]).to eq('open')
    end
  end

  describe '#current_sort' do
    it 'defaults to created_at_desc' do
      query = PromptsQuery.new(company, {}, current_person: person)
      expect(query.current_sort).to eq('created_at_desc')
    end

    it 'returns specified sort' do
      query = PromptsQuery.new(company, { sort: 'template_title' }, current_person: person)
      expect(query.current_sort).to eq('template_title')
    end
  end

  describe '#filter_by_teammate' do
    let(:other_person) { create(:person) }
    let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: company) }
    let!(:other_prompt) { create(:prompt, company_teammate: other_teammate, prompt_template: template1) }

    it 'filters by teammate' do
      query = PromptsQuery.new(company, { teammate: teammate.id }, current_person: person)
      results = query.call
      expect(results).to include(prompt1, prompt2)
      expect(results).not_to include(other_prompt)
    end
  end

  describe '#apply_sort' do
    # Use prompts owned by the current person so they're in the policy scope
    let!(:old_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template1, created_at: 2.days.ago, updated_at: 2.days.ago) }
    let!(:new_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template2, created_at: 1.day.ago, updated_at: 1.day.ago) }

    it 'sorts by created_at_desc by default' do
      query = PromptsQuery.new(company, {}, current_person: person)
      results = query.call.to_a
      # Results should include prompts from policy scope
      expect(results).to include(new_prompt, old_prompt)
      # Most recent should be first
      expect(results.first.created_at).to be >= results.second.created_at if results.length >= 2
    end

    it 'sorts by created_at_asc' do
      query = PromptsQuery.new(company, { sort: 'created_at_asc' }, current_person: person)
      results = query.call.to_a
      expect(results).to include(old_prompt, new_prompt)
      # Oldest should be first
      expect(results.first.created_at).to be <= results.second.created_at if results.length >= 2
    end

    it 'sorts by updated_at_desc' do
      query = PromptsQuery.new(company, { sort: 'updated_at_desc' }, current_person: person)
      results = query.call.to_a
      expect(results).to include(new_prompt, old_prompt)
      # Most recently updated should be first
      expect(results.first.updated_at).to be >= results.second.updated_at if results.length >= 2
    end

    it 'sorts by updated_at_asc' do
      query = PromptsQuery.new(company, { sort: 'updated_at_asc' }, current_person: person)
      results = query.call.to_a
      expect(results).to include(old_prompt, new_prompt)
      # Oldest updated should be first
      expect(results.first.updated_at).to be <= results.second.updated_at if results.length >= 2
    end

    it 'sorts by template_title' do
      query = PromptsQuery.new(company, { sort: 'template_title' }, current_person: person)
      results = query.call.to_a
      # Template 1 should come before Template 2 alphabetically
      template_titles = results.map { |p| p.prompt_template.title }.uniq.sort
      expect(template_titles).to include('Template 1', 'Template 2')
    end

    it 'sorts by template_title_desc' do
      query = PromptsQuery.new(company, { sort: 'template_title_desc' }, current_person: person)
      results = query.call.to_a
      # Template 2 should come before Template 1 alphabetically descending
      template_titles = results.map { |p| p.prompt_template.title }.uniq.sort.reverse
      expect(template_titles).to include('Template 2', 'Template 1')
    end
  end

  describe '#current_view' do
    it 'defaults to table' do
      query = PromptsQuery.new(company, {}, current_person: person)
      expect(query.current_view).to eq('table')
    end

    it 'returns specified view' do
      query = PromptsQuery.new(company, { view: 'card' }, current_person: person)
      expect(query.current_view).to eq('card')
    end

    it 'returns viewStyle if view is blank' do
      query = PromptsQuery.new(company, { viewStyle: 'list' }, current_person: person)
      expect(query.current_view).to eq('list')
    end

    it 'prefers view over viewStyle' do
      query = PromptsQuery.new(company, { view: 'card', viewStyle: 'list' }, current_person: person)
      expect(query.current_view).to eq('card')
    end
  end

  describe '#current_spotlight' do
    it 'defaults to overview' do
      query = PromptsQuery.new(company, {}, current_person: person)
      expect(query.current_spotlight).to eq('overview')
    end

    it 'returns specified spotlight' do
      query = PromptsQuery.new(company, { spotlight: 'details' }, current_person: person)
      expect(query.current_spotlight).to eq('details')
    end
  end

  describe '#has_active_filters?' do
    it 'returns false when no filters' do
      query = PromptsQuery.new(company, {}, current_person: person)
      expect(query.has_active_filters?).to be false
    end

    it 'returns true when template filter is present' do
      query = PromptsQuery.new(company, { template: template1.id }, current_person: person)
      expect(query.has_active_filters?).to be true
    end

    it 'returns true when status filter is present' do
      query = PromptsQuery.new(company, { status: 'open' }, current_person: person)
      expect(query.has_active_filters?).to be true
    end

    it 'returns false when status is "all"' do
      query = PromptsQuery.new(company, { status: 'all' }, current_person: person)
      expect(query.has_active_filters?).to be false
    end

    it 'returns true when teammate filter is present' do
      query = PromptsQuery.new(company, { teammate: teammate.id }, current_person: person)
      expect(query.has_active_filters?).to be true
    end
  end

  describe '#base_scope' do
    it 'returns policy-scoped prompts' do
      query = PromptsQuery.new(company, {}, current_person: person)
      results = query.base_scope
      expect(results).to include(prompt1, prompt2)
    end

    it 'returns empty scope when person has no teammate' do
      other_person = create(:person)
      query = PromptsQuery.new(company, {}, current_person: other_person)
      expect(query.base_scope).to be_empty
    end
  end
end

