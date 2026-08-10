# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::Debug::IntegrityReportService do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization, last_terminated_at: nil) }

  describe ".call" do
    it "returns all section keys" do
      result = described_class.call(organization: organization, slack_users_provider: -> { [] })
      expect(result[:sections].map(&:key)).to eq(
        %i[
          active_assignments_without_employment
          archived_with_open_check_ins
          teammates_without_slack
          slack_without_teammate
          multiple_open_position_check_ins
          position_check_in_wrong_tenure
          employment_state_drift
        ]
      )
    end

    it "flags active assignment tenures when employment is inactive" do
      assignment = create(:assignment, company: organization)
      create(
        :assignment_tenure,
        teammate: teammate,
        assignment: assignment,
        started_at: 1.month.ago,
        ended_at: nil
      )
      # No active employment tenure for teammate

      result = described_class.call(organization: organization, slack_users_provider: -> { [] })
      section = result[:sections].find { |s| s.key == :active_assignments_without_employment }

      expect(section.items.size).to eq(1)
      expect(section.items.first[:teammate]).to eq(teammate)
      expect(section.items.first[:assignment_titles]).to include(assignment.title)
      expect(section.heals_nightly).to be false
    end

    it "flags open check-ins on archived assignments" do
      assignment = create(:assignment, company: organization)
      create(
        :assignment_check_in,
        teammate: teammate,
        assignment: assignment,
        official_check_in_completed_at: nil
      )
      assignment.update_columns(deleted_at: Time.current)

      result = described_class.call(organization: organization, slack_users_provider: -> { [] })
      section = result[:sections].find { |s| s.key == :archived_with_open_check_ins }

      expect(section.items.map { |i| i[:kind] }).to include(:archived_assignment_open_check_in)
      expect(section.items.find { |i| i[:kind] == :archived_assignment_open_check_in }[:record_title]).to eq(assignment.title)
    end

    it "flags multiple open position check-ins as nightly-healing" do
      create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      tenure = teammate.employment_tenures.active.first
      create(:position_check_in, teammate: teammate, employment_tenure: tenure, check_in_started_on: Date.current, official_check_in_completed_at: nil)
      second = build(:position_check_in, teammate: teammate, employment_tenure: tenure, check_in_started_on: Date.yesterday, official_check_in_completed_at: nil)
      second.save!(validate: false)

      result = described_class.call(organization: organization, slack_users_provider: -> { [] })
      section = result[:sections].find { |s| s.key == :multiple_open_position_check_ins }

      expect(section.heals_nightly).to be true
      expect(section.items.size).to eq(1)
      expect(section.items.first[:count]).to eq(2)
    end

    it "flags employment state drift via preview" do
      create(
        :employment_tenure,
        teammate: teammate,
        company: organization,
        started_at: 1.year.ago,
        ended_at: nil
      )
      # Active tenure implies last_terminated_at should be nil; plant drift
      teammate.update_columns(first_employed_at: 1.year.ago, last_terminated_at: 1.day.ago)

      result = described_class.call(organization: organization, slack_users_provider: -> { [] })
      section = result[:sections].find { |s| s.key == :employment_state_drift }

      expect(section.heals_nightly).to be true
      expect(section.items.map { |i| i[:teammate] }).to include(teammate)
      expect(section.items.find { |i| i[:teammate] == teammate }[:changed_fields]).to include(:last_terminated_at)
    end

    it "lists unlinked slack users when configured" do
      create(:slack_configuration, organization: organization)
      organization.reload
      create(:teammate_identity, :slack, teammate: teammate, uid: "U_LINKED")

      provider = lambda do
        [
          { "id" => "U_LINKED", "name" => "linked", "profile" => { "real_name" => "Linked" } },
          { "id" => "U_FREE", "name" => "free", "profile" => { "real_name" => "Free User", "email" => "free@example.com" } },
          { "id" => "UBOT", "name" => "bot", "is_bot" => true, "profile" => { "real_name" => "Bot" } }
        ]
      end

      result = described_class.call(organization: organization, slack_users_provider: provider)
      section = result[:sections].find { |s| s.key == :slack_without_teammate }

      expect(section.items.map { |i| i[:slack_user_id] }).to eq(["U_FREE"])
    end

    it "flags non-terminated teammates without slack when configured" do
      teammate # ensure exists before report runs
      create(:slack_configuration, organization: organization)
      organization.reload

      result = described_class.call(organization: organization, slack_users_provider: -> { [] })
      section = result[:sections].find { |s| s.key == :teammates_without_slack }

      expect(section.items.map { |i| i[:teammate] }).to include(teammate)
    end
  end
end
