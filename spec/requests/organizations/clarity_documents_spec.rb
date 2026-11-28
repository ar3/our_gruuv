# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::ClarityDocuments", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:other_person) { create(:person) }
  let!(:person_teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }
  let!(:manager_teammate) do
    create(:teammate, :unassigned_employee, :maap_manager, person: manager, organization: organization)
  end
  let!(:other_teammate) { create(:teammate, :unassigned_employee, person: other_person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Support Lead") }

  before do
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe "GET index" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "renders the OG Clarity Library list" do
      create(:document, :with_text_block, organization: organization, owner: person_teammate, title: "Shared Process")

      get organization_clarity_documents_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("OG Clarity Library")
      expect(response.body).to include("clarityLibraryIndexPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Shared Process")
      expect(response.body).to include("Add new Document")
    end
  end

  describe "GET show" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "renders a document with block content and linked assignments" do
      document = create(:document, :with_text_block, :linked_to_assignment,
                        organization: organization,
                        owner: person_teammate,
                        assignment: assignment,
                        title: "Escalation Guide",
                        body: "Page the on-call.",
                        kind: "troubleshooting")

      get organization_clarity_document_path(organization, document)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Escalation Guide")
      expect(response.body).to include("clarityLibraryShowPageHelp")
      expect(response.body).to include("Page the on-call.")
      expect(response.body).to include("Support Lead")
      expect(response.body).to include("Linked Assignments")
      expect(response.body).to include("Troubleshooting")
    end

    it "lets a MAAP manager unlink without offering edit" do
      document = create(:document, :with_text_block, :linked_to_assignment,
                        organization: organization,
                        owner: person_teammate,
                        assignment: assignment,
                        title: "Owned by someone else")

      sign_in_as_teammate_for_request(manager, organization)
      get organization_clarity_document_path(organization, document)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Unlink")
      expect(response.body).to include("only the owner")
      expect(response.body).not_to include('aria-label="Edit Document"')
    end
  end

  describe "POST create" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "creates a document owned by the creator and links when started from an Assignment" do
      expect {
        post organization_clarity_documents_path(organization), params: {
          assignment_id: assignment.id,
          document: {
            title: "New How-To",
            kind: "how_to",
            body: "Follow these steps.",
            owner_key: "CompanyTeammate_#{other_teammate.id}"
          }
        }
      }.to change(Document, :count).by(1)
        .and change(Block, :count).by(1)
        .and change(DocumentLink, :count).by(1)

      document = Document.order(:id).last
      expect(response).to redirect_to(organization_assignment_path(organization, assignment))
      expect(document.owner).to eq(person_teammate)
      expect(document.blocks.first.content).to eq("Follow these steps.")
      expect(document.linked_assignments).to contain_exactly(assignment)
    end

    it "creates a standalone document without assignment links" do
      expect {
        post organization_clarity_documents_path(organization), params: {
          document: {
            title: "Standalone Guide",
            kind: "faq_reference",
            body: "Library-only content.",
            owner_key: "CompanyTeammate_#{person_teammate.id}"
          }
        }
      }.to change(Document, :count).by(1)
        .and change(DocumentLink, :count).by(0)

      document = Document.order(:id).last
      expect(response).to redirect_to(organization_clarity_document_path(organization, document))
      expect(document.linked_assignments).to be_empty
      expect(document.kind).to eq("faq_reference")
    end
  end

  describe "DELETE unlink_assignment" do
    it "allows a MAAP manager to unlink without owning the document" do
      document = create(:document, :with_text_block, :linked_to_assignment,
                        organization: organization,
                        owner: person_teammate,
                        assignment: assignment)

      sign_in_as_teammate_for_request(manager, organization)

      expect {
        delete unlink_assignment_organization_clarity_document_path(organization, document, assignment_id: assignment.id)
      }.to change(DocumentLink, :count).by(-1)

      expect(response).to redirect_to(organization_clarity_document_path(organization, document))
      expect(document.reload.linked_assignments).to be_empty
    end
  end

  describe "GET new" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "shows a will-link indicator without assignment multi-select" do
      get new_organization_clarity_document_path(organization, assignment_id: assignment.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("New Clarity Library Document")
      expect(response.body).to include("Will link to Assignment")
      expect(response.body).to include(assignment.title)
      expect(response.body).to include("associate additional Assignments later")
      expect(response.body).to include(%(name="assignment_id"))
      expect(response.body).not_to include("Linked Assignments")
    end

    it "defaults kind to Playbook / Handbook when started from an Assignment" do
      get new_organization_clarity_document_path(organization, assignment_id: assignment.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('id="document_kind_playbook"')
      expect(response.body).to match(/id="document_kind_playbook"[^>]*checked/)
    end

    it "groups owner teams by department for Clarity Library Admins" do
      admin_person = create(:person)
      create(:teammate, :unassigned_employee, :clarity_library_admin, person: admin_person, organization: organization)
      department = create(:department, company: organization, name: "Customer Experience")
      create(:team, company: organization, department: nil, name: "Company Ops")
      create(:team, company: organization, department: department, name: "CX Pod")

      sign_in_as_teammate_for_request(admin_person, organization)
      get new_organization_clarity_document_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<optgroup label=\"Teams · Company-wide\">")
      expect(response.body).to include("<optgroup label=\"Teams · Customer Experience\">")
      expect(response.body).to include("Company Ops")
      expect(response.body).to include("CX Pod")
    end

    it "shows kinds with descriptions and owner help" do
      get new_organization_clarity_document_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('aria-label="Document kind"')
      expect(response.body).to include("Used day to day")
      expect(response.body).to include("Change infrequently")
      expect(response.body).to include("Dated")
      expect(response.body).to include("data-bs-toggle=\"popover\"")
      expect(response.body).to include("race between time and negative reactions")
      expect(response.body).to include("Warning after 60 days")
      expect(response.body).to include("Warning after 6 months")
      expect(response.body).to include("Warning after 1 year")
      expect(response.body).to include("FAQ / Reference")
      expect(response.body).to include("How-to / SOP")
      expect(response.body).to include("Policy / Process")
      expect(response.body).to include("Playbook / Handbook")
      expect(response.body).to include("Profile")
      expect(response.body).to include("working with me")
      expect(response.body).to include("Announcement")
      expect(response.body).to include("Does not go")
      expect(response.body).to include("stale")
      expect(response.body).to include("Training record")
      expect(response.body).to include("Generic")
      expect(response.body).to include("gDocs, Word")
      expect(response.body).to include("form-check-input")
      expect(response.body).to include("<optgroup label=\"Me\">")
      expect(response.body).to include("can edit")
      expect(response.body).to include("must periodically verify")
    end
  end
end
