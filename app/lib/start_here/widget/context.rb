# frozen_string_literal: true

module StartHere
  module Widget
    # Passed into each widget instance; matches the `c` argument in path/label procs.
    Context = Struct.new(:view, :organization, :company_teammate, :person, keyword_init: true) do
      def company
        organization&.root_company || organization
      end

      def casual_name
        company_teammate&.person&.casual_name.presence || "Me"
      end

      def org_display_name
        organization&.name.presence || "Organization"
      end

      def policy(record)
        view.policy(record)
      end
    end
  end
end
