require 'rails_helper'

RSpec.describe "Assignments", type: :request do
  let(:company) { create(:organization, type: 'Company') }
  let(:assignment) { create(:assignment, company: company) }

  describe "GET /assignments" do
    it "returns http success" do
      get assignments_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /assignments/:id" do
    it "returns http success" do
      get assignment_path(assignment)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /assignments/new" do
    it "returns http success" do
      get new_assignment_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /assignments" do
    it "creates a new assignment" do
      expect {
        post assignments_path, params: { assignment: { 
          title: "Test Assignment",
          tagline: "Test tagline",
          company_id: company.id
        }}
      }.to change(Assignment, :count).by(1)
      
      expect(response).to redirect_to(assignment_path(Assignment.last))
    end

    it "creates an assignment with external references" do
      expect {
        post assignments_path, params: { assignment: { 
          title: "Test Assignment",
          tagline: "Test tagline",
          company_id: company.id,
          published_source_url: "https://docs.google.com/document/d/published",
          draft_source_url: "https://docs.google.com/document/d/draft"
        }}
      }.to change(Assignment, :count).by(1)
      .and change(ExternalReference, :count).by(2)
      
      assignment = Assignment.last
      expect(assignment.published_url).to eq("https://docs.google.com/document/d/published")
      expect(assignment.draft_url).to eq("https://docs.google.com/document/d/draft")
      expect(response).to redirect_to(assignment_path(assignment))
    end
  end

  describe "GET /assignments/:id/edit" do
    it "returns http success" do
      get edit_assignment_path(assignment)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /assignments/:id" do
    it "updates the assignment" do
      patch assignment_path(assignment), params: { assignment: { title: "Updated Title" } }
      expect(response).to redirect_to(assignment_path(assignment))
      expect(assignment.reload.title).to eq("Updated Title")
    end

    it "updates external references" do
      # Create initial references
      assignment.create_published_external_reference!(url: "https://old-published.com", reference_type: 'published')
      assignment.create_draft_external_reference!(url: "https://old-draft.com", reference_type: 'draft')
      
      patch assignment_path(assignment), params: { assignment: { 
        published_source_url: "https://new-published.com",
        draft_source_url: "https://new-draft.com"
      }}
      
      expect(response).to redirect_to(assignment_path(assignment))
      assignment.reload
      expect(assignment.published_url).to eq("https://new-published.com")
      expect(assignment.draft_url).to eq("https://new-draft.com")
    end

    it "removes external references when URLs are cleared" do
      # Create initial references
      assignment.create_published_external_reference!(url: "https://old-published.com", reference_type: 'published')
      assignment.create_draft_external_reference!(url: "https://old-draft.com", reference_type: 'draft')
      
      patch assignment_path(assignment), params: { assignment: { 
        published_source_url: "",
        draft_source_url: ""
      }}
      
      expect(response).to redirect_to(assignment_path(assignment))
      assignment.reload
      expect(assignment.published_url).to be_nil
      expect(assignment.draft_url).to be_nil
    end
  end

  describe "DELETE /assignments/:id" do
    it "deletes the assignment" do
      assignment_to_delete = assignment
      expect {
        delete assignment_path(assignment_to_delete)
      }.to change(Assignment, :count).by(-1)
      
      expect(response).to redirect_to(assignments_path)
    end
  end
end
