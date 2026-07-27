# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyEmployeesLink do
  describe ".path_params" do
    it "targets managers view with Employee Health Overview spotlight" do
      expect(described_class.path_params(manager_teammate_id: 42)).to eq(
        manager_teammate_id: 42,
        view: "managers_view",
        spotlight: "employee_health_overview"
      )
    end
  end
end
