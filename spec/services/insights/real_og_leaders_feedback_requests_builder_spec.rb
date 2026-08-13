# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::RealOgLeadersFeedbackRequestsBuilder do
  let(:company) { create(:organization, :company) }
  let(:requestor_person) { create(:person, first_name: "Rita", last_name: "Requestor") }
  let(:subject_person) { create(:person, first_name: "Sam", last_name: "Subject") }
  let(:responder_person) { create(:person, first_name: "Reese", last_name: "Responder") }
  let!(:requestor) { create(:teammate, person: requestor_person, organization: company) }
  let!(:subject_tm) { create(:teammate, person: subject_person, organization: company) }
  let!(:responder) { create(:teammate, person: responder_person, organization: company) }

  def create_request!(attrs = {})
    create(
      :feedback_request,
      {
        company: company,
        requestor_teammate: requestor,
        subject_of_feedback_teammate: subject_tm,
        created_at: 2.days.ago
      }.merge(attrs)
    )
  end

  describe "#call" do
    it "counts subject, requestor, respondent, and completed signals and stars all four" do
      fr = create_request!
      fr.feedback_request_responders.create!(teammate: responder, created_at: 2.days.ago, completed_at: 1.day.ago)

      # Give subject and requestor the other roles so someone can hit all four
      fr2 = create(
        :feedback_request,
        company: company,
        requestor_teammate: responder,
        subject_of_feedback_teammate: requestor,
        created_at: 2.days.ago
      )
      fr2.feedback_request_responders.create!(
        teammate: subject_tm,
        created_at: 2.days.ago,
        completed_at: 1.day.ago
      )
      fr3 = create(
        :feedback_request,
        company: company,
        requestor_teammate: subject_tm,
        subject_of_feedback_teammate: responder,
        created_at: 2.days.ago
      )
      fr3.feedback_request_responders.create!(
        teammate: requestor,
        created_at: 2.days.ago,
        completed_at: 12.hours.ago
      )

      rows = described_class.new(company: company, range: 90.days.ago..Time.current).call
      by_name = rows.index_by { |r| r.person }

      expect(by_name[requestor_person].has_all_four).to be true
      expect(by_name[subject_person].has_all_four).to be true
      expect(by_name[responder_person].has_all_four).to be true
    end

    it "ignores soft-deleted feedback requests" do
      fr = create_request!(deleted_at: Time.current)
      fr.feedback_request_responders.create!(teammate: responder, created_at: 1.day.ago, completed_at: 1.day.ago)

      rows = described_class.new(company: company, range: nil).call
      expect(rows).to be_empty
    end

    it "attributes received by responder created_at and completed by completed_at" do
      fr = create_request!(created_at: 120.days.ago)
      fr.feedback_request_responders.create!(
        teammate: responder,
        created_at: 120.days.ago,
        completed_at: 1.day.ago
      )

      rows = described_class.new(company: company, range: 90.days.ago..Time.current).call
      expect(rows.size).to eq(1)
      row = rows.first
      expect(row.person).to eq(responder_person)
      expect(row.has_received).to be false
      expect(row.has_completed).to be true
      expect(row.completed_count).to eq(1)
      expect(row.has_sent).to be false
      expect(row.has_requested_about).to be false
    end

    it "sorts all-four first, then prefer subject-only over sent-only" do
      # subject only
      create_request!(created_at: 3.days.ago)

      # sent only (different requestor; subject is someone else with no other signals beyond being subject on first)
      other_requestor_person = create(:person, first_name: "Only", last_name: "Sender")
      other_requestor = create(:teammate, person: other_requestor_person, organization: company)
      other_subject_person = create(:person, first_name: "Quiet", last_name: "Subject")
      other_subject = create(:teammate, person: other_subject_person, organization: company)
      create(
        :feedback_request,
        company: company,
        requestor_teammate: other_requestor,
        subject_of_feedback_teammate: other_subject,
        created_at: 1.day.ago
      )

      names = described_class.new(company: company, range: nil).call.map(&:display_name)
      # Both subject-only people rank above requestor-only (other_requestor) when signal count is 1
      # First request: requestor has sent, subject has requested_about
      # Second: other_requestor has sent, other_subject has requested_about
      # Among singles: subjects before requestors
      subject_positions = names.each_with_index.select { |n, _| n.include?("Subject") }.map(&:last)
      sender_positions = names.each_with_index.select { |n, _| n.include?("Requestor") || n.include?("Sender") }.map(&:last)
      expect(subject_positions.max).to be < sender_positions.min
    end
  end
end
