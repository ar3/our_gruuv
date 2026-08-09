# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObjectMaintainers::Updater do
  let(:organization) { create(:organization) }
  let(:maap_admin) { create(:teammate, :assigned_employee, :maap_manager, organization: organization) }
  let(:maintainer) { create(:teammate, :assigned_employee, organization: organization) }
  let(:peer) { create(:teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  before do
    create(:object_maintainer, maintainable: assignment, company_teammate: maintainer, added_by: maap_admin)
  end

  it "lets a MAAP admin add and remove maintainers including self-removals" do
    described_class.new(
      maintainable: assignment,
      actor: maap_admin,
      selected_teammate_ids: [ peer.id ],
      unrestricted: true
    ).call

    expect(assignment.reload.maintainers).to contain_exactly(peer)
  end

  it "lets a maintainer add others but not remove themselves" do
    described_class.new(
      maintainable: assignment,
      actor: maintainer,
      selected_teammate_ids: [ peer.id ],
      unrestricted: false
    ).call

    expect(assignment.reload.maintainers).to contain_exactly(maintainer, peer)
  end
end
