# frozen_string_literal: true

require "rails_helper"

RSpec.describe TalentDensityStancePolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:report) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:stance) { create(:talent_density_stance, company_teammate: report, company: organization) }

  def pundit_user_for(teammate)
    OpenStruct.new(user: teammate, impersonating_teammate: nil)
  end

  before do
    create(:employment_tenure, company_teammate: report, company: organization, manager_teammate: manager)
  end

  it "allows the manager to show and update a report's stance" do
    policy = described_class.new(pundit_user_for(manager), stance)
    expect(policy.show?).to be true
    expect(policy.update?).to be true
  end

  it "never allows the subject to see their own stance" do
    own = create(:talent_density_stance, company_teammate: manager, company: organization)
    manager.update!(can_manage_employment: true)
    policy = described_class.new(pundit_user_for(manager), own)
    expect(policy.show?).to be false
    expect(policy.update?).to be false
  end
end
