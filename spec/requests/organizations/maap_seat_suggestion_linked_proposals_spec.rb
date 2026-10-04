# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Seat suggestion linked create proposals", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let!(:major_level) { create(:position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: major_level, level: "1.1") }
  let!(:person_teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }
  let!(:manager_teammate) do
    create(:teammate, :unassigned_employee, :maap_manager, person: manager, organization: organization)
  end

  before do
    PaperTrail.enabled = false
    create(:title, company: organization, position_major_level: major_level)
  end
  after { PaperTrail.enabled = true }

  def build_bundle!
    result = MaapProposals::CreateSeatSuggestionBundle.call(
      organization: organization,
      proposer: person_teammate,
      bundle: {
        "seat" => {
          "why_needed" => "We need analytics ownership.",
          "why_now" => "Pipeline is blocked.",
          "costs_risks" => "We keep guessing.",
          "job_classification" => "Salaried Exempt",
          "seat_needed_by" => (Date.current + 2.months).iso8601
        },
        "title" => {
          "mode" => "create",
          "external_title" => "Staff Data Analytics Engineer",
          "position_major_level_id" => major_level.id,
          "position_summary" => "Owns customer-facing analytics."
        },
        "team" => {
          "mode" => "create",
          "name" => "Product Insights"
        },
        "position" => {
          "position_summary" => "Level 1 analytics seat",
          "position_level_hint" => "1"
        },
        "assignments" => [
          {
            "mode" => "create",
            "title" => "Customer Analytics Owner",
            "tagline" => "Ship trusted analytics",
            "energy_percentage" => 40,
            "assignment_type" => "required",
            "outcomes" => ["Customers can answer key questions"],
            "abilities" => [
              {
                "mode" => "create",
                "name" => "Analytics Product Sense",
                "description" => "Turns ambiguous questions into insights",
                "milestone_level" => 3
              }
            ]
          }
        ]
      }
    )
    expect(result.ok?).to eq(true), -> { Array(result.error).join(", ") }
    result.value
  end

  describe "bidirectional navigation" do
    it "links from the seat create show to child proposals and back" do
      bundle = build_bundle!
      seat = bundle[:seat_proposal]
      title = seat.children_for_role("title").first
      team = seat.children_for_role("team").first
      position = seat.children_for_role("position").first
      assignment = seat.children_for_role("assignment").first
      ability = seat.children_for_role("ability").first

      sign_in_as_teammate_for_request(person, organization)

      get organization_maap_seat_create_path(organization, seat)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Linked proposals")
      expect(response.body).to include("Suggested approval order")
      expect(response.body).to include("Title → Team → Ability → Assignment → Position → Seat")
      expect(response.body).to include(organization_maap_title_create_path(organization, title))
      expect(response.body).to include(organization_maap_team_create_path(organization, team))
      expect(response.body).to include(organization_maap_position_create_path(organization, position))
      expect(response.body).to include(organization_maap_assignment_create_path(organization, assignment))
      expect(response.body).to include(organization_maap_ability_create_path(organization, ability))
      title_pos = response.body.index(organization_maap_title_create_path(organization, title))
      team_pos = response.body.index(organization_maap_team_create_path(organization, team))
      ability_pos = response.body.index(organization_maap_ability_create_path(organization, ability))
      assignment_pos = response.body.index(organization_maap_assignment_create_path(organization, assignment))
      position_pos = response.body.index(organization_maap_position_create_path(organization, position))
      expect([title_pos, team_pos, ability_pos, assignment_pos, position_pos]).to eq(
        [title_pos, team_pos, ability_pos, assignment_pos, position_pos].sort
      )
      expect(response.body).to include("bi-exclamation-triangle")
      expect(response.body).to include("The Title must be created first")
      expect(response.body).not_to include(
        "action=\"#{submit_organization_maap_seat_create_path(organization, seat)}\""
      )

      [
        [organization_maap_title_create_path(organization, title), "Title create proposal"],
        [organization_maap_team_create_path(organization, team), "Team create proposal"],
        [organization_maap_position_create_path(organization, position), "Position create proposal"],
        [organization_maap_assignment_create_path(organization, assignment), "Assignment create proposal"],
        [organization_maap_ability_create_path(organization, ability), "Ability create proposal"]
      ].each do |path, heading|
        get path
        expect(response).to have_http_status(:success), -> { "#{path} failed: #{response.status}" }
        expect(response.body).to include(heading)
        expect(response.body).to include("Part of Seat create proposal")
        expect(response.body).to include(organization_maap_seat_create_path(organization, seat))
      end
    end
  end

  describe "seat submit gate" do
    it "blocks submit until the Title exists and the Seat draft associates it" do
      bundle = build_bundle!
      seat = bundle[:seat_proposal]
      title = seat.children_for_role("title").first

      sign_in_as_teammate_for_request(person, organization)
      post submit_organization_maap_seat_create_path(organization, seat)
      expect(response).to redirect_to(organization_maap_seat_create_path(organization, seat))
      expect(flash[:alert].to_s).to include("Title must be created first")
      expect(seat.reload).to be_draft

      post submit_organization_maap_title_create_path(organization, title)
      expect(title.reload).to be_submitted

      sign_in_as_teammate_for_request(manager, organization)
      post apply_organization_maap_title_create_path(organization, title), params: { decision_note: "Ok" }
      expect(title.reload).to be_applied
      expect(title.proposable).to be_a(Title)
      expect(seat.reload.proposed_payload["title_id"]).to be_nil

      sign_in_as_teammate_for_request(person, organization)
      get organization_maap_seat_create_path(organization, seat)
      expect(response.body).to include("Edit this Seat proposal to associate")
      expect(response.body).to include("bi-exclamation-triangle")

      post submit_organization_maap_seat_create_path(organization, seat)
      expect(seat.reload).to be_draft

      patch organization_maap_seat_create_path(organization, seat), params: {
        maap_proposal: {
          title_id: title.proposable_id,
          additional_title_ids: [],
          seat_needed_by: seat.proposed_payload["seat_needed_by"],
          job_classification: seat.proposed_payload["job_classification"],
          why_needed: seat.proposed_payload["why_needed"],
          why_now: seat.proposed_payload["why_now"],
          costs_risks: seat.proposed_payload["costs_risks"]
        }
      }
      expect(seat.reload.proposed_payload["title_id"]).to eq(title.proposable_id)

      get organization_maap_seat_create_path(organization, seat)
      expect(response.body).not_to include("The Title must be created first")
      expect(response.body).not_to include("Edit this Seat proposal to associate")
      expect(response.body).to include(
        "action=\"#{submit_organization_maap_seat_create_path(organization, seat)}\""
      )

      post submit_organization_maap_seat_create_path(organization, seat)
      expect(seat.reload).to be_submitted
    end
  end
end
