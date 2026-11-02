# frozen_string_literal: true

require "rails_helper"

RSpec.describe SlackPogoAutoRefresh::ScheduleJob, type: :job do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:runner) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }

  before { create(:teammate_identity, :slack_search, teammate: runner) }

  it "enqueues refresh jobs for due enrollments" do
    create(
      :slack_pogo_auto_refresh_enrollment,
      organization: organization,
      runner_company_teammate: runner,
      subject_company_teammate: subject_teammate,
      last_refreshed_at: nil
    )

    expect {
      described_class.perform_now
    }.to have_enqueued_job(SlackPogoAutoRefresh::RefreshEnrollmentJob)
  end
end
