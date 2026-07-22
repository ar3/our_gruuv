# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Single-item check-in save buttons", type: :request do
  let(:organization) { create(:organization) }
  let(:employee_person) { create(:person) }
  let(:manager_person) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, person: employee_person, organization: organization) }
  let!(:manager_teammate) do
    create(:company_teammate, person: manager_person, organization: organization, can_manage_employment: true)
  end

  let!(:manager_employment) do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  let!(:employee_employment) do
    create(:employment_tenure,
      teammate: employee_teammate,
      company: organization,
      started_at: 1.year.ago,
      ended_at: nil,
      manager_teammate: manager_teammate)
  end

  before do
    manager_teammate.update!(first_employed_at: 1.year.ago) if manager_teammate.respond_to?(:first_employed_at)
    employee_teammate.update!(first_employed_at: 1.year.ago) if employee_teammate.respond_to?(:first_employed_at)
  end

  def apply_state!(check_in, state)
    now = Time.current
    attrs = case state
    when :emp_draft_mgr_draft
      { employee_completed_at: nil, manager_completed_at: nil, manager_completed_by_teammate_id: nil }
    when :emp_draft_mgr_ready
      { employee_completed_at: nil, manager_completed_at: now, manager_completed_by_teammate_id: manager_teammate.id }
    when :emp_ready_mgr_draft
      { employee_completed_at: now, manager_completed_at: nil, manager_completed_by_teammate_id: nil }
    when :emp_ready_mgr_ready
      { employee_completed_at: now, manager_completed_at: now, manager_completed_by_teammate_id: manager_teammate.id }
    else
      raise ArgumentError, "Unknown state: #{state}"
    end
    check_in.update_columns(attrs)
  end

  def side_ready?(state, side)
    return [:emp_ready_mgr_draft, :emp_ready_mgr_ready].include?(state) if side == :employee

    [:emp_draft_mgr_ready, :emp_ready_mgr_ready].include?(state)
  end

  def save_button_for(side_ready:, action:)
    return(side_ready ? "save_and_complete_go_to_next" : "save_and_draft_stay") if action == :without_switch

    side_ready ? "save_and_draft_stay" : "save_and_complete_go_to_next"
  end

  shared_examples "single item save matrix" do |type_name:, check_in_proc:, path_proc:, current_type:, current_id_proc:, nested_proc:|
    let!(:open_check_in) { instance_exec(&check_in_proc) }
    let(:show_path) { instance_exec(&path_proc) }
    let(:current_id_value) { instance_exec(&current_id_proc) }

    [:emp_draft_mgr_draft, :emp_draft_mgr_ready, :emp_ready_mgr_draft, :emp_ready_mgr_ready].each do |state|
      [:employee, :manager].each do |viewer_side|
        [:without_switch, :with_switch].each do |action|
          it "#{type_name} #{state} #{viewer_side} #{action} saves without exception" do
            apply_state!(open_check_in, state)
            ready_before = side_ready?(state, viewer_side)
            submit_button = save_button_for(side_ready: ready_before, action: action)
            expected_after_ready = action == :without_switch ? ready_before : !ready_before
            viewer_person = viewer_side == :employee ? employee_person : manager_person

            sign_in_as_teammate_for_request(viewer_person, organization)

            patch organization_company_teammate_check_ins_path(organization, employee_teammate),
              params: {
                check_ins: {
                  current_url: show_path,
                  current_type: current_type,
                  current_id: current_id_value
                }.merge(instance_exec(viewer_side, open_check_in, &nested_proc)),
                submit_button => "Save"
              }

            expect(response).to have_http_status(:redirect)
            open_check_in.reload
            actual_ready = viewer_side == :employee ? open_check_in.employee_completed? : open_check_in.manager_completed?
            expect(actual_ready).to eq(expected_after_ready)
          end
        end
      end
    end
  end

  context "aspiration item" do
    include_examples "single item save matrix",
      type_name: "aspiration",
      check_in_proc: lambda {
        aspiration = create(:aspiration, company: organization, name: "Matrix Aspiration")
        AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration)
      },
      path_proc: -> { organization_teammate_aspiration_path(organization, employee_teammate, open_check_in.aspiration) },
      current_type: "aspiration",
      current_id_proc: -> { open_check_in.aspiration_id.to_s },
      nested_proc: lambda { |viewer_side, check_in|
        attrs = { aspiration_id: check_in.aspiration_id.to_s }
        attrs[viewer_side == :employee ? :employee_private_notes : :manager_private_notes] = "save"
        { aspiration_check_ins: { check_in.id.to_s => attrs } }
      }
  end

  context "assignment item" do
    include_examples "single item save matrix",
      type_name: "assignment",
      check_in_proc: lambda {
        assignment = create(:assignment, company: organization, title: "Matrix Assignment")
        create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, anticipated_energy_percentage: 35)
        AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
      },
      path_proc: -> { organization_teammate_assignment_path(organization, employee_teammate, open_check_in.assignment) },
      current_type: "assignment",
      current_id_proc: -> { open_check_in.assignment_id.to_s },
      nested_proc: lambda { |viewer_side, check_in|
        attrs = { assignment_id: check_in.assignment_id.to_s }
        attrs[viewer_side == :employee ? :employee_private_notes : :manager_private_notes] = "save"
        { assignment_check_ins: { check_in.id.to_s => attrs } }
      }
  end

  context "position item" do
    include_examples "single item save matrix",
      type_name: "position",
      check_in_proc: lambda {
        position_major_level = create(:position_major_level)
        title = create(:title, company: organization, position_major_level: position_major_level)
        position_level = create(:position_level, position_major_level: position_major_level)
        position = create(:position, title: title, position_level: position_level)
        employee_employment.update!(position: position)
        PositionCheckIn.find_or_create_open_for(employee_teammate)
      },
      path_proc: -> { position_check_in_organization_teammate_path(organization, employee_teammate) },
      current_type: "position",
      current_id_proc: -> { "" },
      nested_proc: lambda { |viewer_side, _check_in|
        attrs = {}
        attrs[viewer_side == :employee ? :employee_private_notes : :manager_private_notes] = "save"
        { position_check_in: attrs }
      }
  end

  describe "Gruuv Health refresh after save" do
    let!(:assignment) { create(:assignment, company: organization, title: "Refresh Assignment") }
    let!(:assignment_tenure) do
      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, anticipated_energy_percentage: 35)
    end
    let!(:open_check_in) { AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment) }
    let(:show_path) { organization_teammate_assignment_path(organization, employee_teammate, assignment) }

    before { sign_in_as_teammate_for_request(employee_person, organization) }

    def patch_assignment_check_in(submit_button:)
      patch organization_company_teammate_check_ins_path(organization, employee_teammate),
        params: {
          check_ins: {
            current_url: show_path,
            current_type: "assignment",
            current_id: assignment.id.to_s,
            assignment_check_ins: {
              open_check_in.id.to_s => {
                assignment_id: assignment.id.to_s,
                employee_private_notes: "notes"
              }
            }
          },
          submit_button => "Save"
        }
    end

    it "refreshes synchronously on save and go to next" do
      expect(EngagementHealth::Refresher).to receive(:call).with(
        an_object_having_attributes(id: employee_teammate.id)
      ).and_call_original

      expect {
        patch_assignment_check_in(submit_button: "save_and_complete_go_to_next")
      }.not_to have_enqueued_job(EngagementHealthRefreshJob)

      expect(response).to have_http_status(:redirect)
    end

    it "queues async refresh on save and stay" do
      expect(EngagementHealth::Refresher).not_to receive(:call)

      expect {
        patch_assignment_check_in(submit_button: "save_and_draft_stay")
      }.to have_enqueued_job(EngagementHealthRefreshJob).with(employee_teammate.id)

      expect(response).to have_http_status(:redirect)
    end

    it "still redirects and queues async when sync refresh fails on go to next" do
      allow(EngagementHealth::Refresher).to receive(:call).and_raise(StandardError, "boom")

      expect {
        patch_assignment_check_in(submit_button: "save_and_complete_go_to_next")
      }.to have_enqueued_job(EngagementHealthRefreshJob).with(employee_teammate.id)

      expect(response).to have_http_status(:redirect)
    end
  end
end
