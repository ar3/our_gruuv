# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Assignments::MaapProposals", type: :request do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Ops Cadence", tagline: "Keep ops smooth") }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let!(:person_teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }
  let!(:manager_teammate) do
    create(:teammate, :unassigned_employee, :maap_manager, person: manager, organization: organization)
  end

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  describe "GET index" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "lists proposals for the assignment" do
      get organization_assignment_maap_proposals_path(organization, assignment)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(assignment.title)
      expect(response.body).to include("Propose edit")
      expect(response.body).to include("aria-label=\"Propose edit\"")
      expect(response.body).to include("Switch assignment for proposed edits")
      expect(response.body).to include("All proposed edits (0)")
      expect(response.body).to include("Download markdown template")
      expect(response.body).to include("Upload markdown")
      expect(response.body).to include("assignmentMaapProposalsPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("keep it relevant")
      expect(response.body).to include("How proposals move")
      expect(response.body).to include("Submitted")
      expect(response.body).to include("Applied")
      expect(response.body).to include("proposal_status_draft")
      expect(response.body).to include("proposal_status_submitted")
      expect(response.body).to include("proposal_status_applied")
    end

    it "sorts by creation date and filters by status checkboxes" do
      older = create(
        :maap_proposal,
        :submitted,
        assignment: assignment,
        proposer: person_teammate,
        created_at: 2.days.ago,
        proposed_payload: {
          "schema_version" => 1,
          "title" => "Older Submitted",
          "tagline" => "tag",
          "outcomes" => [],
          "ability_milestones" => [],
          "consumer_assignment_ids" => [],
          "supplier_assignment_ids" => []
        }
      )
      newer = create(
        :maap_proposal,
        assignment: assignment,
        proposer: person_teammate,
        created_at: 1.hour.ago,
        proposed_payload: {
          "schema_version" => 1,
          "title" => "Newer Draft",
          "tagline" => "tag",
          "outcomes" => [],
          "ability_milestones" => [],
          "consumer_assignment_ids" => [],
          "supplier_assignment_ids" => []
        }
      )
      applied = create(
        :maap_proposal,
        :applied,
        assignment: assignment,
        proposer: person_teammate,
        decided_by: manager_teammate,
        created_at: 3.days.ago,
        proposed_payload: {
          "schema_version" => 1,
          "title" => "Applied Proposal",
          "tagline" => "tag",
          "outcomes" => [],
          "ability_milestones" => [],
          "consumer_assignment_ids" => [],
          "supplier_assignment_ids" => []
        }
      )

      get organization_assignment_maap_proposals_path(organization, assignment)
      expect(response).to have_http_status(:success)
      body = response.body
      expect(body.index("Newer Draft")).to be < body.index("Older Submitted")
      expect(body.index("Older Submitted")).to be < body.index("Applied Proposal")
      expect(body).to include("proposal_status_rejected")

      get organization_assignment_maap_proposals_path(organization, assignment, statuses: %w[draft])
      expect(response.body).to include(organization_assignment_maap_proposal_path(organization, assignment, newer))
      expect(response.body).not_to include(organization_assignment_maap_proposal_path(organization, assignment, older))
      expect(response.body).not_to include(organization_assignment_maap_proposal_path(organization, assignment, applied))
    end

    it "downloads a markdown template for the live assignment" do
      get markdown_template_organization_assignment_maap_proposals_path(organization, assignment)
      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to include("assignment-#{assignment.id}-proposal-template.md")
      expect(response.body).to include("proposable_id: #{assignment.id}")
      expect(response.body).to include(assignment.title)
    end
  end

  describe "proposal lifecycle via requests" do
    it "lets a teammate draft and submit, and a MAAP manager apply" do
      sign_in_as_teammate_for_request(person, organization)

      expect do
        get new_organization_assignment_maap_proposal_path(organization, assignment)
      end.to change(MaapProposal, :count).by(1)

      proposal = MaapProposal.last
      expect(response).to redirect_to(edit_organization_assignment_maap_proposal_path(organization, assignment, proposal))

      patch organization_assignment_maap_proposal_path(organization, assignment, proposal), params: {
        maap_proposal: {
          title: "Ops Cadence Improved",
          tagline: "Keep ops smoother",
          required_activities: assignment.required_activities,
          handbook: assignment.handbook,
          outcomes: [
            { description: "Fewer surprises", outcome_type: "sentiment" }
          ]
        }
      }
      expect(response).to redirect_to(organization_assignment_maap_proposal_path(organization, assignment, proposal))

      post submit_organization_assignment_maap_proposal_path(organization, assignment, proposal)
      expect(response).to redirect_to(organization_assignment_maap_proposal_path(organization, assignment, proposal))
      expect(proposal.reload).to be_submitted

      sign_in_as_teammate_for_request(manager, organization)
      get organization_assignment_maap_proposal_path(organization, assignment, proposal)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Apply proposal")
      expect(response.body).to include(apply_organization_assignment_maap_proposal_path(organization, assignment, proposal))
      expect(response.body).not_to include("You need MAAP management permissions to apply or reject this proposal.")

      post apply_organization_assignment_maap_proposal_path(organization, assignment, proposal), params: {
        version_type: "clarifying"
      }
      expect(response).to redirect_to(organization_assignment_path(organization, assignment))
      expect(assignment.reload.title).to eq("Ops Cadence Improved")
      expect(proposal.reload).to be_applied
      expect(proposal.baseline_payload["title"]).to eq("Ops Cadence")
    end
  end

  describe "markdown download and upload" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "downloads markdown and creates a draft from upload" do
      proposal = MaapProposals::CreateAssignmentEditDraft.call(
        assignment: assignment,
        proposer: person_teammate
      ).value
      MaapProposals::UpdateAssignmentEditDraft.call(
        proposal: proposal,
        attributes: { "title" => "From MD", "tagline" => assignment.tagline }
      )

      get markdown_organization_assignment_maap_proposal_path(organization, assignment, proposal)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("proposable_id: #{assignment.id}")
      expect(response.body).to include("From MD")

      expect do
        post upload_markdown_organization_assignment_maap_proposals_path(organization, assignment), params: {
          markdown_body: response.body.sub("From MD", "From Upload")
        }
      end.to change(MaapProposal, :count).by(1)

      uploaded = MaapProposal.order(:id).last
      expect(uploaded.proposed_payload["title"]).to eq("From Upload")
      expect(uploaded.source).to eq("markdown")
    end
  end

  describe "assignment show links" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "surfaces proposed edits entry points" do
      get organization_assignment_path(organization, assignment)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("All proposed edits (0)")
      expect(response.body).to include("Propose edit")
    end
  end

  describe "GET show with diffs" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "renders field diffs against the live assignment" do
      proposal = MaapProposals::CreateAssignmentEditDraft.call(
        assignment: assignment,
        proposer: person_teammate
      ).value
      MaapProposals::UpdateAssignmentEditDraft.call(
        proposal: proposal,
        attributes: { "title" => "Diffed Title", "tagline" => assignment.tagline }
      )

      get organization_assignment_maap_proposal_path(organization, assignment, proposal)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Changes vs current assignment")
      expect(response.body).to include("Title")
      expect(response.body).to include("Diffed Title")
      expect(response.body).to include('class="diff"')
      expect(response.body).to include("assignmentMaapProposalShowPageHelp")
      expect(response.body).to include("How proposals move")
      expect(response.body).to include("Apply proposal")
      expect(response.body).to include("Reject proposal")
      expect(response.body).to include("Only submitted proposals can be applied or rejected")
    end

    it "disables apply/reject for teammates without MAAP permission even when submitted" do
      proposal = MaapProposals::CreateAssignmentEditDraft.call(
        assignment: assignment,
        proposer: person_teammate
      ).value
      MaapProposals::UpdateAssignmentEditDraft.call(
        proposal: proposal,
        attributes: { "title" => "Needs Review", "tagline" => assignment.tagline }
      )
      MaapProposals::SubmitAssignmentEdit.call(proposal: proposal.reload)

      get organization_assignment_maap_proposal_path(organization, assignment, proposal)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Apply proposal")
      expect(response.body).to include("Reject proposal")
      expect(response.body).to include("You need MAAP management permissions to apply or reject this proposal.")
      expect(response.body).not_to include(apply_organization_assignment_maap_proposal_path(organization, assignment, proposal))
    end

    it "renders decided proposals against the stored baseline, not a later live assignment" do
      proposal = MaapProposals::CreateAssignmentEditDraft.call(
        assignment: assignment,
        proposer: person_teammate
      ).value
      MaapProposals::UpdateAssignmentEditDraft.call(
        proposal: proposal,
        attributes: { "title" => "Proposed At Decision", "tagline" => assignment.tagline }
      )
      MaapProposals::SubmitAssignmentEdit.call(proposal: proposal.reload)
      MaapProposals::RejectAssignmentEdit.call(
        proposal: proposal.reload,
        decided_by: manager_teammate,
        decision_note: "Not the right timing"
      )

      assignment.update!(handbook: "Later handbook that must not appear in decided diffs")

      get organization_assignment_maap_proposal_path(organization, assignment, proposal)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Changes vs assignment at decision")
      expect(response.body).to include("Proposed At Decision")
      expect(response.body).to include("Ops Cadence")
      expect(response.body).not_to include("Later handbook that must not appear in decided diffs")
      expect(response.body).to include("Proposal rejected")
      expect(response.body).to include(manager.display_name)
      expect(response.body).to include("rejected this proposal")
      expect(response.body).to include("Not the right timing")
      expect(response.body).not_to include("Apply proposal")
    end
  end

  describe "editing outcomes" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "adds and removes outcomes on draft save" do
      create(:assignment_outcome, assignment: assignment, description: "Keep me", outcome_type: "quantitative")
      create(:assignment_outcome, assignment: assignment, description: "Drop me", outcome_type: "sentiment")

      proposal = MaapProposals::CreateAssignmentEditDraft.call(
        assignment: assignment,
        proposer: person_teammate
      ).value

      get edit_organization_assignment_maap_proposal_path(organization, assignment, proposal)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Add outcome")
      expect(response.body).to include("Ability milestones")
      expect(response.body).to include("Consumer assignments")
      expect(response.body).to include("Supplier assignments")
      expect(response.body).to include("rely on this one")
      expect(response.body).to include("this one relies on")
      expect(response.body).to include("To be qualified for #{assignment.title}")
      expect(response.body).to include("M1 – Demonstrated")
      expect(response.body).to include("M2 – Advanced")
      expect(response.body).not_to include("Published source URL")
      expect(response.body).not_to include("Progress report URL")

      patch organization_assignment_maap_proposal_path(organization, assignment, proposal), params: {
        maap_proposal: {
          title: assignment.title,
          tagline: assignment.tagline,
          required_activities: assignment.required_activities,
          handbook: assignment.handbook,
          outcomes: [
            { description: "Keep me", outcome_type: "quantitative" },
            { description: "Brand new outcome", outcome_type: "sentiment" }
          ]
        }
      }

      expect(response).to redirect_to(organization_assignment_maap_proposal_path(organization, assignment, proposal))
      outcomes = proposal.reload.proposed_payload["outcomes"]
      expect(outcomes.map { |o| o["description"] }).to eq(["Keep me", "Brand new outcome"])
    end
  end
end
