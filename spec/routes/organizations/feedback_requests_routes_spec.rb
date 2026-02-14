require 'rails_helper'

RSpec.describe "Organizations::FeedbackRequests Routes", type: :routing do
  let(:organization_id) { "1" }
  let(:feedback_request_id) { "1" }

  describe "Collection routes" do
    it "routes GET /organizations/:organization_id/feedback_requests to organizations/feedback_requests#index" do
      expect(get: "/organizations/#{organization_id}/feedback_requests").to route_to(
        controller: "organizations/feedback_requests",
        action: "index",
        organization_id: organization_id
      )
    end

    it "generates the correct path helper" do
      expect(organization_feedback_requests_path(organization_id)).to eq("/organizations/#{organization_id}/feedback_requests")
    end

    it "routes GET /organizations/:organization_id/feedback_requests/new to organizations/feedback_requests#new" do
      expect(get: "/organizations/#{organization_id}/feedback_requests/new").to route_to(
        controller: "organizations/feedback_requests",
        action: "new",
        organization_id: organization_id
      )
    end

    it "generates the correct new path helper" do
      expect(new_organization_feedback_request_path(organization_id)).to eq("/organizations/#{organization_id}/feedback_requests/new")
    end

    it "routes POST /organizations/:organization_id/feedback_requests to organizations/feedback_requests#create" do
      expect(post: "/organizations/#{organization_id}/feedback_requests").to route_to(
        controller: "organizations/feedback_requests",
        action: "create",
        organization_id: organization_id
      )
    end

    it "generates the correct create path helper" do
      expect(organization_feedback_requests_path(organization_id)).to eq("/organizations/#{organization_id}/feedback_requests")
    end

    it "routes GET /organizations/:organization_id/feedback_requests/as_subject to organizations/feedback_requests#as_subject" do
      expect(get: "/organizations/#{organization_id}/feedback_requests/as_subject").to route_to(
        controller: "organizations/feedback_requests",
        action: "as_subject",
        organization_id: organization_id
      )
    end

    it "routes GET /organizations/:organization_id/feedback_requests/requested_for_others to organizations/feedback_requests#requested_for_others" do
      expect(get: "/organizations/#{organization_id}/feedback_requests/requested_for_others").to route_to(
        controller: "organizations/feedback_requests",
        action: "requested_for_others",
        organization_id: organization_id
      )
    end

    it "routes GET /organizations/:organization_id/feedback_requests/customize_view to organizations/feedback_requests#customize_view" do
      expect(get: "/organizations/#{organization_id}/feedback_requests/customize_view").to route_to(
        controller: "organizations/feedback_requests",
        action: "customize_view",
        organization_id: organization_id
      )
    end

    it "routes PATCH /organizations/:organization_id/feedback_requests/update_view to organizations/feedback_requests#update_view" do
      expect(patch: "/organizations/#{organization_id}/feedback_requests/update_view").to route_to(
        controller: "organizations/feedback_requests",
        action: "update_view",
        organization_id: organization_id
      )
    end
  end

  describe "Member routes" do
    it "routes GET /organizations/:organization_id/feedback_requests/:id to organizations/feedback_requests#show" do
      expect(get: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}").to route_to(
        controller: "organizations/feedback_requests",
        action: "show",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "generates the correct show path helper" do
      expect(organization_feedback_request_path(organization_id, feedback_request_id)).to eq("/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}")
    end

    it "routes GET /organizations/:organization_id/feedback_requests/:id/edit to organizations/feedback_requests#edit" do
      expect(get: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/edit").to route_to(
        controller: "organizations/feedback_requests",
        action: "edit",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "generates the correct edit path helper" do
      expect(edit_organization_feedback_request_path(organization_id, feedback_request_id)).to eq("/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/edit")
    end

    it "routes PATCH /organizations/:organization_id/feedback_requests/:id to organizations/feedback_requests#update" do
      expect(patch: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}").to route_to(
        controller: "organizations/feedback_requests",
        action: "update",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "routes PUT /organizations/:organization_id/feedback_requests/:id to organizations/feedback_requests#update" do
      expect(put: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}").to route_to(
        controller: "organizations/feedback_requests",
        action: "update",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "routes DELETE /organizations/:organization_id/feedback_requests/:id to organizations/feedback_requests#destroy" do
      expect(delete: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}").to route_to(
        controller: "organizations/feedback_requests",
        action: "destroy",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "routes GET /organizations/:organization_id/feedback_requests/:id/select_focus to organizations/feedback_requests#select_focus" do
      expect(get: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/select_focus").to route_to(
        controller: "organizations/feedback_requests",
        action: "select_focus",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "generates the correct select_focus path helper" do
      expect(select_focus_organization_feedback_request_path(organization_id, feedback_request_id)).to eq("/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/select_focus")
    end

    it "routes PATCH /organizations/:organization_id/feedback_requests/:id/update_focus to organizations/feedback_requests#update_focus" do
      expect(patch: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/update_focus").to route_to(
        controller: "organizations/feedback_requests",
        action: "update_focus",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "routes GET /organizations/:organization_id/feedback_requests/:id/feedback_prompt to organizations/feedback_requests#feedback_prompt" do
      expect(get: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/feedback_prompt").to route_to(
        controller: "organizations/feedback_requests",
        action: "feedback_prompt",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "generates the correct feedback_prompt path helper" do
      expect(feedback_prompt_organization_feedback_request_path(organization_id, feedback_request_id)).to eq("/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/feedback_prompt")
    end

    it "routes PATCH /organizations/:organization_id/feedback_requests/:id/update_questions to organizations/feedback_requests#update_questions" do
      expect(patch: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/update_questions").to route_to(
        controller: "organizations/feedback_requests",
        action: "update_questions",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "routes GET /organizations/:organization_id/feedback_requests/:id/select_respondents to organizations/feedback_requests#select_respondents" do
      expect(get: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/select_respondents").to route_to(
        controller: "organizations/feedback_requests",
        action: "select_respondents",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "generates the correct select_respondents path helper" do
      expect(select_respondents_organization_feedback_request_path(organization_id, feedback_request_id)).to eq("/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/select_respondents")
    end

    it "routes PATCH /organizations/:organization_id/feedback_requests/:id/update_respondents to organizations/feedback_requests#update_respondents" do
      expect(patch: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/update_respondents").to route_to(
        controller: "organizations/feedback_requests",
        action: "update_respondents",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "routes POST /organizations/:organization_id/feedback_requests/:id/add_respondent to organizations/feedback_requests#add_respondent" do
      expect(post: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/add_respondent").to route_to(
        controller: "organizations/feedback_requests",
        action: "add_respondent",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "routes DELETE /organizations/:organization_id/feedback_requests/:id/remove_respondent to organizations/feedback_requests#remove_respondent" do
      expect(delete: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/remove_respondent").to route_to(
        controller: "organizations/feedback_requests",
        action: "remove_respondent",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "routes GET /organizations/:organization_id/feedback_requests/:id/answer to organizations/feedback_requests#answer" do
      expect(get: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/answer").to route_to(
        controller: "organizations/feedback_requests",
        action: "answer",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "generates the correct answer path helper" do
      expect(answer_organization_feedback_request_path(organization_id, feedback_request_id)).to eq("/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/answer")
    end

    it "routes POST /organizations/:organization_id/feedback_requests/:id/submit_answers to organizations/feedback_requests#submit_answers" do
      expect(post: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/submit_answers").to route_to(
        controller: "organizations/feedback_requests",
        action: "submit_answers",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "generates the correct submit_answers path helper" do
      expect(submit_answers_organization_feedback_request_path(organization_id, feedback_request_id)).to eq("/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/submit_answers")
    end

    it "routes POST /organizations/:organization_id/feedback_requests/:id/archive to organizations/feedback_requests#archive" do
      expect(post: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/archive").to route_to(
        controller: "organizations/feedback_requests",
        action: "archive",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "generates the correct archive path helper" do
      expect(archive_organization_feedback_request_path(organization_id, feedback_request_id)).to eq("/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/archive")
    end

    it "routes POST /organizations/:organization_id/feedback_requests/:id/restore to organizations/feedback_requests#restore" do
      expect(post: "/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/restore").to route_to(
        controller: "organizations/feedback_requests",
        action: "restore",
        organization_id: organization_id,
        id: feedback_request_id
      )
    end

    it "generates the correct restore path helper" do
      expect(restore_organization_feedback_request_path(organization_id, feedback_request_id)).to eq("/organizations/#{organization_id}/feedback_requests/#{feedback_request_id}/restore")
    end
  end
end
