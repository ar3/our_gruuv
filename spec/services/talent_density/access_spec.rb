# frozen_string_literal: true

require "rails_helper"

RSpec.describe TalentDensity::Access do
  let(:company) { create(:organization, :company) }
  let(:vp) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:manager) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:ic) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:other_manager) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:other_ic) { create(:company_teammate, :assigned_employee, organization: company) }

  before do
    create(:employment_tenure, company_teammate: manager, company: company, manager_teammate: vp)
    create(:employment_tenure, company_teammate: ic, company: company, manager_teammate: manager)
    create(:employment_tenure, company_teammate: other_ic, company: company, manager_teammate: other_manager)
  end

  def access_for(viewer, org_wide: false)
    described_class.new(viewer: viewer, organization: company, org_wide: org_wide)
  end

  describe "#selectable_managers" do
    it "includes self and descendant managers for a skip-level manager" do
      ids = access_for(vp).selectable_managers.map(&:id)
      expect(ids).to include(vp.id, manager.id)
      expect(ids).not_to include(other_manager.id)
    end

    it "includes every manager when org_wide" do
      ids = access_for(vp, org_wide: true).selectable_managers.map(&:id)
      expect(ids).to include(vp.id, manager.id, other_manager.id)
    end
  end

  describe "#active_teammates_for_exclude" do
    it "includes every employed teammate, not only the current manager's tree" do
      ids = access_for(vp).active_teammates_for_exclude.map(&:id)
      expect(ids).to include(vp.id, manager.id, ic.id, other_manager.id, other_ic.id)
    end
  end

  describe "#teammates_in_scope" do
    it "includes skip-level reports for hierarchy and not for directs" do
      directs = access_for(vp).teammates_in_scope(vp, scope: "directs")
      hierarchy = access_for(vp).teammates_in_scope(vp, scope: "hierarchy")
      expect(directs.map(&:id)).to eq([manager.id])
      expect(hierarchy.map(&:id)).to include(manager.id, ic.id)
    end

    it "omits the viewer when they would appear as a direct report" do
      reports = access_for(manager, org_wide: true).reports_for(vp)
      expect(reports.map(&:id)).not_to include(manager.id)
    end

    it "returns none for a manager outside the viewer's tree" do
      expect(access_for(vp).reports_for(other_manager)).to be_empty
    end
  end

  describe "#can_edit?" do
    it "allows skip-level edits of an indirect report" do
      expect(access_for(vp).can_edit?(ic)).to be true
    end

    it "never allows editing yourself" do
      expect(access_for(manager).can_edit?(manager)).to be false
      expect(access_for(manager, org_wide: true).can_edit?(manager)).to be false
    end

    it "denies people outside the tree unless org_wide" do
      expect(access_for(vp).can_edit?(other_ic)).to be false
      expect(access_for(vp, org_wide: true).can_edit?(other_ic)).to be true
    end
  end

  describe "#viewers_for_subject" do
    it "lists the manager chain and employment managers, excluding the subject" do
      hr = create(:company_teammate, :assigned_employee, :employment_manager, organization: company)
      names = access_for(vp).viewers_for_subject(ic).map { |tm| tm.person.casual_name }
      expect(names).to include(vp.person.casual_name, manager.person.casual_name, hr.person.casual_name)
      expect(names).not_to include(ic.person.casual_name)
    end
  end
end
