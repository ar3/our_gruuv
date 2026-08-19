# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::TalentDensity", type: :request do
  let(:company) { create(:organization, :company) }
  let(:vp_person) { create(:person, first_name: "Pat", last_name: "Vance") }
  let(:manager_person) { create(:person, first_name: "Morgan", last_name: "Lee") }
  let(:ic_person) { create(:person, first_name: "Ivy", last_name: "Chen") }
  let(:outsider_person) { create(:person, first_name: "Omar", last_name: "Diaz") }

  let(:vp) do
    create(:company_teammate, :assigned_employee, person: vp_person, organization: company)
  end
  let(:manager) do
    create(:company_teammate, :assigned_employee, person: manager_person, organization: company)
  end
  let(:ic) do
    create(:company_teammate, :assigned_employee, person: ic_person, organization: company)
  end
  let(:outsider) do
    create(:company_teammate, :assigned_employee, person: outsider_person, organization: company)
  end

  before do
    vp
    manager
    ic
    outsider
    create(:employment_tenure, company_teammate: manager, company: company, manager_teammate: vp)
    create(:employment_tenure, company_teammate: ic, company: company, manager_teammate: manager)
    create(:employment_tenure, company_teammate: outsider, company: company, manager_teammate: outsider)
  end

  describe "GET /organizations/:organization_id/talent_density" do
    it "renders the working page for a manager and omits their own row" do
      sign_in_as_teammate_for_request(vp_person, company)

      get organization_talent_density_path(company)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Talent Density")
      expect(response.body).to include("Beta")
      expect(response.body).not_to include("/beta")
      expect(CGI.unescapeHTML(response.body)).to include("I'd take the swap")
      expect(CGI.unescapeHTML(response.body)).to include("I'd work to avoid the swap")
      expect(CGI.unescapeHTML(response.body)).to include("I'd do nothing")
      expect(response.body).to include("someone else/new in magically ramped")
      expect(response.body).to include("border-warning")
      expect(response.body).to include("border-info")
      expect(response.body).to include("border-success")
      expect(response.body).to include("Whose directs")
      expect(response.body).to include("Morgan")
      expect(response.body).to include(review_most_recent_organization_company_teammate_check_ins_path(company, manager))
      expect(CGI.unescapeHTML(response.body)).to include("Notes (these notes and the values are only visible to")
      expect(response.body).to include(vp_person.casual_name)
      expect(response.body).to include("with the title/position")
    end

    it "lets a skip-level manager open a descendant manager's directs and hides the viewer if present" do
      sign_in_as_teammate_for_request(vp_person, company)

      get organization_talent_density_path(company, manager_id: "CompanyTeammate_#{manager.id}")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Ivy")
      expect(response.body).to include("Direct reports of")
      expect(response.body).to include("Morgan")
    end

    it "shows last finalized position rating and open manager rating" do
      tenure = ic.employment_tenures.find_by!(ended_at: nil)
      create(
        :position_check_in,
        :closed,
        teammate: ic,
        employment_tenure: tenure,
        official_rating: 3,
        official_check_in_completed_at: Time.zone.parse("2026-06-15")
      )
      create(
        :position_check_in,
        :manager_completed,
        teammate: ic,
        employment_tenure: tenure,
        manager_rating: 2
      )
      sign_in_as_teammate_for_request(vp_person, company)

      get organization_talent_density_path(company, manager_id: "CompanyTeammate_#{manager.id}")

      body = CGI.unescapeHTML(response.body)
      expect(body).to include("Exceptional")
      expect(body).to include("open manager rating")
      expect(body).to include("Accomplished")
    end

    it "does not show another team's people to a manager without manage-employment" do
      sign_in_as_teammate_for_request(vp_person, company)

      get organization_talent_density_path(company, manager_id: "CompanyTeammate_#{outsider.id}")

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Omar")
    end

    it "shows only the explainer to an employed teammate who is not a manager" do
      sign_in_as_teammate_for_request(ic_person, company)

      get organization_talent_density_path(company)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("You will never see yours")
      expect(CGI.unescapeHTML(response.body)).to include("I'd take the swap")
      expect(response.body).not_to include("Whose directs")
      expect(response.body).not_to include("Save stances")
      expect(response.body).not_to include("Omar")
    end
  end

  describe "PATCH /organizations/:organization_id/talent_density" do
    it "saves overwrite stance and notes for a direct report" do
      sign_in_as_teammate_for_request(manager_person, company)

      patch organization_talent_density_path(company), params: {
        manager_id: "CompanyTeammate_#{manager.id}",
        stances: {
          ic.id.to_s => { stance: "fine_either_way", notes: "Solid contributor" }
        }
      }

      expect(response).to redirect_to(organization_talent_density_path(company, manager_id: "CompanyTeammate_#{manager.id}"))
      stance = TalentDensityStance.find_by!(company_teammate: ic)
      expect(stance.stance).to eq("fine_either_way")
      expect(stance.notes).to eq("Solid contributor")
    end

    it "ignores submitted rows for people outside the selected manager's directs" do
      sign_in_as_teammate_for_request(manager_person, company)

      patch organization_talent_density_path(company), params: {
        manager_id: "CompanyTeammate_#{manager.id}",
        stances: {
          outsider.id.to_s => { stance: "take_the_swap", notes: "should not save" }
        }
      }

      expect(TalentDensityStance.find_by(company_teammate: outsider)).to be_nil
    end

    it "lets a skip-level manager save a descendant's direct report" do
      sign_in_as_teammate_for_request(vp_person, company)

      patch organization_talent_density_path(company), params: {
        manager_id: "CompanyTeammate_#{manager.id}",
        stances: {
          ic.id.to_s => { stance: "try_to_avoid_the_swap", notes: "Uniquely right" }
        }
      }

      expect(TalentDensityStance.find_by!(company_teammate: ic).stance).to eq("try_to_avoid_the_swap")
    end
  end

  describe "PaperTrail history" do
    it "lets a manager read history and never lets the employee read their own" do
      PaperTrail.enabled = true
      sign_in_as_teammate_for_request(manager_person, company)
      stance = create(:talent_density_stance, company_teammate: ic, company: company, notes: "first")
      stance.update!(notes: "second")

      get organization_paper_trail_path(company, item_type: "TalentDensityStance", item_id: stance.id)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Change history")
      expect(response.body).to include("Notes")

      sign_in_as_teammate_for_request(ic_person, company)
      get organization_paper_trail_path(company, item_type: "TalentDensityStance", item_id: stance.id)
      expect(response).to redirect_to(root_path)
    end
  end
end
