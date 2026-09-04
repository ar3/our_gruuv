# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssignmentSurveys::ExpectationAlignmentScore do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:viewer) { create(:teammate, :assigned_employee, organization: organization, can_manage_maap: true) }
  let(:reference_time) { Time.zone.parse("2026-09-02 12:00:00") }

  def create_employee
    teammate = create(:teammate, :assigned_employee, organization: organization)
    create(:employment_tenure, company_teammate: teammate, company: organization)
    teammate
  end

  def create_finalized_check_in(teammate:, finalized_at:, employee_rating:, manager_rating:)
    create(
      :assignment_check_in,
      :officially_completed,
      teammate: teammate,
      assignment: assignment,
      employee_rating: employee_rating,
      manager_rating: manager_rating,
      official_rating: manager_rating,
      official_check_in_completed_at: finalized_at
    )
  end

  def create_survey(teammate:, submitted_at:, understandable: nil, possible: nil, relevant: nil)
    create(
      :assignment_survey_response,
      :submitted,
      company_teammate: teammate,
      assignment: assignment,
      organization: organization,
      submitted_at: submitted_at,
      understandable_rating: understandable,
      possible_rating: possible,
      relevant_rating: relevant,
      personal_alignment: nil
    )
  end

  before do
    create(:employment_tenure, company_teammate: viewer, company: organization)
  end

  describe ".likert_to_0_100" do
    it "maps 1→0, 6→100, 3.5→50" do
      expect(described_class.likert_to_0_100(1)).to eq(0.0)
      expect(described_class.likert_to_0_100(6)).to eq(100.0)
      expect(described_class.likert_to_0_100(3.5)).to eq(50.0)
    end
  end

  describe ".band_for_score" do
    it "maps the 0–100 bands using alignment language keys" do
      expect(described_class.band_for_score(0)[:key]).to eq(:strongly_misaligned)
      expect(described_class.band_for_score(29.9)[:label]).to eq("Strongly Mis-aligned")
      expect(described_class.band_for_score(30)[:key]).to eq(:misaligned)
      expect(described_class.band_for_score(50)[:key]).to eq(:slightly_misaligned)
      expect(described_class.band_for_score(65)[:key]).to eq(:slightly_aligned)
      expect(described_class.band_for_score(80)[:key]).to eq(:aligned)
      expect(described_class.band_for_score(95)[:key]).to eq(:strongly_aligned)
      expect(described_class.band_for_score(100)[:label]).to eq("Strongly Aligned")
    end
  end

  describe ".callout_text_align" do
    it "left-aligns low scores, centers mid scores, and right-aligns high scores" do
      expect(described_class.callout_text_align(0)).to eq("start")
      expect(described_class.callout_text_align(30)).to eq("start")
      expect(described_class.callout_text_align(50)).to eq("center")
      expect(described_class.callout_text_align(70)).to eq("end")
      expect(described_class.callout_text_align(100)).to eq("end")
    end
  end

  describe ".recalculate!" do
    it "persists a weighted score and cell breakdown" do
      a = create_employee
      b = create_employee

      create_finalized_check_in(
        teammate: a,
        finalized_at: reference_time - 10.days,
        employee_rating: "meeting",
        manager_rating: "meeting"
      )
      create_finalized_check_in(
        teammate: b,
        finalized_at: reference_time - 10.days,
        employee_rating: "meeting",
        manager_rating: "exceeding"
      )
      create_survey(
        teammate: a,
        submitted_at: reference_time - 5.days,
        understandable: 6,
        possible: 6,
        relevant: 6
      )

      record = described_class.recalculate!(assignment: assignment, reference_time: reference_time)

      expect(record.score.to_f).to eq(66.7)
      expect(record.check_in_teammate_count).to eq(2)
      expect(record.survey_respondent_count).to eq(1)
      expect(record.cells.size).to eq(6)
      expect(record.calculated_at).to be_within(1.second).of(reference_time)
    end

    it "ignores official rating and personal-alignment-only survey rows" do
      a = create_employee
      create_finalized_check_in(
        teammate: a,
        finalized_at: reference_time - 5.days,
        employee_rating: "meeting",
        manager_rating: "meeting"
      )
      AssignmentCheckIn.last.update_columns(official_rating: "exceeding")

      create(
        :assignment_survey_response,
        :submitted,
        company_teammate: a,
        assignment: assignment,
        organization: organization,
        submitted_at: reference_time - 5.days,
        personal_alignment: "love",
        understandable_rating: nil,
        possible_rating: nil,
        relevant_rating: nil
      )

      record = described_class.recalculate!(assignment: assignment, reference_time: reference_time)
      fresh_alignment = record.cells.find { |c| c["band"] == "fresh" && c["signal"] == "alignment" }
      fresh_upr = record.cells.find { |c| c["band"] == "fresh" && c["signal"] == "upr" }

      expect(fresh_alignment["score_0_100"]).to eq(100.0)
      expect(fresh_upr["included"]).to be(false)
      expect(record.survey_respondent_count).to eq(0)
    end
  end

  describe ".for_viewer" do
    it "shows uncalculated state only to privileged viewers" do
      regular = create(:teammate, :assigned_employee, organization: organization, can_manage_maap: false)
      create(:employment_tenure, company_teammate: regular, company: organization)

      privileged = described_class.for_viewer(
        assignment: assignment,
        viewer: viewer,
        organization: organization
      )
      public_view = described_class.for_viewer(
        assignment: assignment,
        viewer: regular,
        organization: organization
      )

      expect(privileged.show_card?).to be(true)
      expect(privileged.calculated?).to be(false)
      expect(privileged.can_refresh?).to be(true)

      expect(public_view.show_card?).to be(false)
      expect(public_view.can_refresh?).to be(false)
    end

    it "reads the cached score for viewers who pass the threshold" do
      a = create_employee
      b = create_employee
      create_finalized_check_in(
        teammate: a,
        finalized_at: reference_time - 5.days,
        employee_rating: "meeting",
        manager_rating: "meeting"
      )
      create_finalized_check_in(
        teammate: b,
        finalized_at: reference_time - 5.days,
        employee_rating: "meeting",
        manager_rating: "exceeding"
      )
      described_class.recalculate!(assignment: assignment, reference_time: reference_time)

      regular = create(:teammate, :assigned_employee, organization: organization, can_manage_maap: false)
      create(:employment_tenure, company_teammate: regular, company: organization)

      result = described_class.for_viewer(
        assignment: assignment,
        viewer: regular,
        organization: organization
      )

      expect(result.calculated?).to be(true)
      expect(result.can_see_score?).to be(true)
      expect(result.can_refresh?).to be(true)
      expect(result.score).to eq(50.0)
    end

    it "hides the numeric score for non-privileged viewers below the 2-employee threshold" do
      a = create_employee
      create_finalized_check_in(
        teammate: a,
        finalized_at: reference_time - 5.days,
        employee_rating: "meeting",
        manager_rating: "meeting"
      )
      create_survey(teammate: a, submitted_at: reference_time - 5.days, understandable: 5)
      described_class.recalculate!(assignment: assignment, reference_time: reference_time)

      regular = create(:teammate, :assigned_employee, organization: organization, can_manage_maap: false)
      create(:employment_tenure, company_teammate: regular, company: organization)

      result = described_class.for_viewer(
        assignment: assignment,
        viewer: regular,
        organization: organization
      )

      expect(result.show_card?).to be(true)
      expect(result.can_see_score?).to be(false)
      expect(result.can_refresh?).to be(false)
      expect(result.threshold_met?).to be(false)
      expect(result.score).to eq(93.3)
    end

    it "shows for assignment maintainers even with one employee" do
      maintainer = create(:teammate, :assigned_employee, organization: organization, can_manage_maap: false)
      create(:employment_tenure, company_teammate: maintainer, company: organization)
      assignment.object_maintainers.create!(company_teammate: maintainer)
      a = create_employee
      create_finalized_check_in(
        teammate: a,
        finalized_at: reference_time - 5.days,
        employee_rating: "meeting",
        manager_rating: "exceeding"
      )
      described_class.recalculate!(assignment: assignment, reference_time: reference_time)

      result = described_class.for_viewer(
        assignment: assignment,
        viewer: maintainer,
        organization: organization
      )

      expect(result.can_see_score?).to be(true)
      expect(result.can_refresh?).to be(true)
      expect(result.score).to eq(0.0)
    end
  end
end
