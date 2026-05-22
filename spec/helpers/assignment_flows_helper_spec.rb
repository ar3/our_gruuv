# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AssignmentFlowsHelper, type: :helper do
  let(:organization) { create(:organization, :company) }

  describe '#mermaid_flowchart_dsl' do
    it 'returns empty string when assignments are blank' do
      expect(helper.mermaid_flowchart_dsl([], [], organization: organization)).to eq('')
    end

    it 'escapes characters that break Mermaid flowchart syntax in labels' do
      assignment = create(
        :assignment,
        company: organization,
        title: 'Sales [Q1] (50%) & "Priority" #1'
      )
      dsl = helper.mermaid_flowchart_dsl([assignment], [], organization: organization)

      expect(dsl).to include('flowchart TB')
      expect(dsl).to include('n_')
      expect(dsl).not_to include('[Q1]')
      expect(dsl).to include('#91;Q1#93;')
      expect(dsl).to match(/n_#{assignment.id}\("/)
      expect(dsl).not_to include('click ')
    end

    it 'neutralizes arrow-like sequences in titles' do
      assignment = create(:assignment, company: organization, title: 'Plan A --> Plan B')
      dsl = helper.mermaid_flowchart_dsl([assignment], [], organization: organization)

      expect(dsl).not_to include('-->')
    end

    it 'includes supplier to consumer edges' do
      supplier = create(:assignment, company: organization, title: 'Supplier')
      consumer = create(:assignment, company: organization, title: 'Consumer')
      relationship = create(
        :assignment_supply_relationship,
        supplier_assignment: supplier,
        consumer_assignment: consumer
      )
      dsl = helper.mermaid_flowchart_dsl(
        [supplier, consumer],
        [relationship],
        organization: organization
      )

      expect(dsl).to include("n_#{supplier.id} --> n_#{consumer.id}")
    end
  end

  describe '#mermaid_assignment_click_urls' do
    it 'maps node ids to assignment paths' do
      assignment = create(:assignment, company: organization, title: 'Supplier')
      urls = helper.mermaid_assignment_click_urls([assignment], organization: organization)

      expect(urls).to eq(
        "n_#{assignment.id}" => helper.organization_assignment_path(organization, assignment)
      )
    end
  end
end
