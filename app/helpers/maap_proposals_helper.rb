# frozen_string_literal: true

module MaapProposalsHelper
  def render_maap_proposal_field_diff(field_diff)
    return if field_diff.blank?

    tag.div(class: "maap-proposal-diff mb-4") do
      safe_join(
        [
          tag.h6(field_diff.label, class: "text-muted"),
          tag.div(field_diff.html.html_safe, class: "maap-proposal-diff__body border rounded p-2 bg-light")
        ]
      )
    end
  end
end
