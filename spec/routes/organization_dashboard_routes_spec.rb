require 'rails_helper'

RSpec.describe "Organization Dashboard Routes", type: :routing do
  describe "GET /organizations/:id/dashboard" do
    it "routes to organizations#dashboard" do
      expect(get: "/organizations/1/dashboard").to route_to(
        controller: "organizations",
        action: "dashboard",
        id: "1"
      )
    end
    
    it "generates the correct path" do
      expect(dashboard_organization_path(1)).to eq("/organizations/1/dashboard")
    end
  end
end
