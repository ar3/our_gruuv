# frozen_string_literal: true

module Organizations::OgAcademyHelper
  def og_academy_home_options(_organization, company_teammate, casual)
    [
      ["og_academy", "OG Academy", "bi-mortarboard", "Stay oriented here while you build habits."],
      ["start_here", "Start Here dashboard", "bi-house-door", "Fully configurable widgets for power users."],
      ["one_on_one_hub", "#{casual}'s One Thing", "bi-link-45deg", "Focused on you and your weekly rhythm."],
      (company_teammate.has_direct_reports? ? ["protect_flow", "Protect Flow / employees", "bi-people-fill", "Lead with employee health in view."] : nil),
      ["goals", "My goals", "bi-bullseye", "Jump into goals and confidence checks."],
      ["about_me", "About #{casual}", "bi-person", "Full About Me health dashboard."]
    ].compact
  end
end
