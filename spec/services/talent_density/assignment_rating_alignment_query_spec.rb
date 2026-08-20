# frozen_string_literal: true

require "rails_helper"

RSpec.describe TalentDensity::AssignmentRatingAlignmentQuery do
  let(:company) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:ic) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:assignment) { create(:assignment, company: company, title: "Core Delivery") }

  before do
    create(:employment_tenure, company_teammate: ic, company: company, manager_teammate: manager)
  end

  describe ".classify" do
    it "classifies the five agreement patterns" do
      expect(described_class.classify("meeting", "meeting", "meeting")).to eq(:all_same)
      expect(described_class.classify("working_to_meet", "meeting", "exceeding")).to eq(:all_differed)
      expect(described_class.classify("meeting", "meeting", "exceeding")).to eq(:emp_mgr_same_final_differed)
      expect(described_class.classify("exceeding", "meeting", "exceeding")).to eq(:emp_final_same_mgr_differed)
      expect(described_class.classify("working_to_meet", "meeting", "meeting")).to eq(:mgr_final_same_emp_differed)
    end
  end

  describe ".arrow_for" do
    it "uses final vs manager except when mgr+final matched and emp differed" do
      expect(described_class.arrow_for(:all_same, "meeting", "meeting", "meeting")).to be_nil
      expect(described_class.arrow_for(:all_differed, "working_to_meet", "meeting", "exceeding")).to eq(:better)
      expect(described_class.arrow_for(:emp_mgr_same_final_differed, "meeting", "meeting", "working_to_meet")).to eq(:worse)
      expect(described_class.arrow_for(:emp_final_same_mgr_differed, "exceeding", "meeting", "exceeding")).to eq(:better)
      expect(described_class.arrow_for(:mgr_final_same_emp_differed, "exceeding", "meeting", "meeting")).to eq(:worse)
    end
  end

  it "places a teammate's last finalized check-in into the agreement grid" do
    create(
      :assignment_check_in,
      :officially_completed,
      teammate: ic,
      assignment: assignment,
      employee_rating: "meeting",
      manager_rating: "meeting",
      official_rating: "exceeding"
    )

    query = described_class.new(teammates: [ic])
    expect(query.assignments.map(&:id)).to eq([assignment.id])
    points = query.cell(assignment, :emp_mgr_same_final_differed)
    expect(points.map { |point| point.teammate.id }).to eq([ic.id])
    expect(points.first.arrow).to eq(:better)
  end
end
