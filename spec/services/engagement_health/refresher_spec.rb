# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EngagementHealth::Refresher do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: organization) }

  it 'persists one record per calculated row and replaces prior records on rerun' do
    described_class.call(teammate)
    first_run = EngagementHealthStatus.where(teammate: teammate, organization: organization).to_a

    # With no data: 2 OGO items + 2 OGO rollups + 3 category rollups (goal/clarity/milestones)
    expect(first_run.size).to eq(7)
    expect(first_run.map(&:category).uniq).to match_array(EngagementHealth::CATEGORIES)
    expect(first_run.select { |r| r.level == 'category' }.size).to eq(5)

    described_class.call(teammate)
    second_run = EngagementHealthStatus.where(teammate: teammate, organization: organization).to_a
    expect(second_run.size).to eq(7)
    expect(second_run.map(&:id)).not_to match_array(first_run.map(&:id))
  end

  it 'stores status, inputs, and computed_at on each record' do
    described_class.call(teammate)

    record = EngagementHealthStatus.items.for_category('ogo_given').find_by(teammate: teammate)
    expect(record.status).to eq(EngagementHealth::NEEDS_ATTENTION)
    expect(record.inputs['never']).to be(true)
    expect(record.inputs['healthy_within_days']).to eq(30)
    expect(record.computed_at).to be_present
  end
end
