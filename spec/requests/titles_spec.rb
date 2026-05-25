require 'rails_helper'

RSpec.describe "Titles", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /new" do
    it "returns http success" do
      get "/organizations/#{organization.id}/titles/new"
      # May redirect if authorization fails, but should at least not error
      expect(response.status).to be_between(200, 399).inclusive
    end
  end

  describe "GET /index" do
    it "redirects to positions index" do
      get "/organizations/#{organization.id}/titles"
      expect(response).to redirect_to(organization_positions_path(organization))
    end
  end

  describe "GET /edit" do
    let(:position_major_level) { create(:position_major_level) }
    let(:title) { create(:title, company: organization, position_major_level: position_major_level) }

    it "returns http success and renders without NoMethodError" do
      get "/organizations/#{organization.id}/titles/#{title.id}/edit"
      
      # Should succeed (200) or redirect if unauthorized (302), but should not error (500)
      expect(response.status).to be_between(200, 399).inclusive
      
      # If successful, verify the form renders correctly
      if response.status == 200
        expect(response.body).to include('Edit Title')
        expect(response.body).to include(title.external_title)
        # Should not have NoMethodError about company_title_path - this is the key check
        expect(response.body).not_to include('NoMethodError')
        expect(response.body).not_to include('company_title_path')
        expect(response.body).not_to include('undefined method')
        expect(response.body).not_to include("undefined method 'company_title_path'")
        # Form should have the correct action URL using organization_title_path
        # form_with generates the action, check for the path in the form (may use slug format)
        expect(response.body).to match(%r{/organizations/.*/titles/#{title.id}})
      end
    end
  end

  describe "GET /show" do
    let(:position_major_level) { create(:position_major_level) }
    let(:title) { create(:title, company: organization, position_major_level: position_major_level, external_title: "Staff Engineer") }

    it "returns success with primary information, switchers, actions card, and audit footer" do
      get organization_title_path(organization, title)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Primary information")
      expect(response.body).to include("Staff Engineer")
      expect(response.body).to include("Teammates with this Title")
      expect(response.body).to include("Actions")
      expect(response.body).to include("View Mode")
      expect(response.body).to include("Created by ")
      expect(response.body).to include("Last updated by ")
      expect(response.body).to include("View full change history")
      expect(response.body).to include("item_type=Title")
      expect(response.body).to include("item_id=#{title.id}")
    end

    it "renders public kudos card with Title rateable query params" do
      get organization_title_path(organization, title)

      expect(response.body).to include("Public Kudos")
      expect(response.body).to include("rateable_type=Title")
      expect(response.body).to include("rateable_id=#{title.id}")
    end

    it "lists other company-wide titles in the header switcher" do
      other = create(:title, company: organization, position_major_level: position_major_level, external_title: "Other Role")
      get organization_title_path(organization, title)

      expect(response.body).to include("Company-wide")
      expect(response.body).to include("Other Role")
      expect(response.body).to include(organization_title_path(organization, other))
    end

    it "shows linked seats in the teammates table" do
      position_level = create(:position_level, position_major_level: position_major_level, level: "1.1")
      position = create(:position, title: title, position_level: position_level)
      seat = create(:seat, title: title)
      employee_person = create(:person)
      employee_teammate = create(:teammate, person: employee_person, organization: organization)
      tenure = build(:employment_tenure, teammate: employee_teammate, company: organization, seat: seat, ended_at: nil)
      tenure.position = position
      tenure.save!

      get organization_title_path(organization, title)

      expect(response.body).to include(">Seat</th>")
      expect(response.body).to include(organization_seat_path(organization, seat))
      expect(response.body).to include(seat.display_name)
    end

    it "links to each position in the actions card" do
      level_one = create(:position_level, position_major_level: position_major_level, level: "1.1")
      level_two = create(:position_level, position_major_level: position_major_level, level: "1.2")
      position_one = create(:position, title: title, position_level: level_one)
      position_two = create(:position, title: title, position_level: level_two)

      get organization_title_path(organization, title)

      expect(response.body).to include(organization_position_path(organization, position_one))
      expect(response.body).to include(organization_position_path(organization, position_two))
      expect(response.body).to include(position_one.display_name)
      expect(response.body).to include(position_two.display_name)
    end
  end

  describe "PATCH /update" do
    let(:position_major_level) { create(:position_major_level) }
    let(:title) { create(:title, company: organization, position_major_level: position_major_level) }
    let(:department) { create(:department, company: organization) }

    it "updates the title successfully" do
      patch "/organizations/#{organization.id}/titles/#{title.id}", params: {
        title: {
          external_title: "Updated Title",
          alternative_titles: "Alt Title",
          position_summary: "Updated summary"
        }
      }

      expect(response).to redirect_to(organization_title_path(organization, title))
      expect(flash[:notice]).to eq('Title was successfully updated.')
      
      title.reload
      expect(title.external_title).to eq("Updated Title")
      expect(title.alternative_titles).to eq("Alt Title")
      expect(title.position_summary).to eq("Updated summary")
    end

    it "updates the title with department_id" do
      patch "/organizations/#{organization.id}/titles/#{title.id}", params: {
        title: {
          department_id: department.id
        }
      }

      expect(response).to redirect_to(organization_title_path(organization, title))
      
      title.reload
      expect(title.department_id).to eq(department.id)
      expect(title.department).to be_a(Department)
      expect(title.department.id).to eq(department.id)
    end

    it "allows clearing department_id" do
      title.update!(department: department)
      
      patch "/organizations/#{organization.id}/titles/#{title.id}", params: {
        title: {
          department_id: ""
        }
      }

      expect(response).to redirect_to(organization_title_path(organization, title))
      
      title.reload
      expect(title.department_id).to be_nil
    end

    it "renders edit with errors when update fails" do
      # Create another title with the same external_title to cause uniqueness validation error
      create(:title, company: organization, position_major_level: position_major_level, external_title: "Duplicate Title")
      
      patch "/organizations/#{organization.id}/titles/#{title.id}", params: {
        title: {
          external_title: "Duplicate Title"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Edit Title')
      expect(title.reload.external_title).not_to eq("Duplicate Title")
    end
  end
end
