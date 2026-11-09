# frozen_string_literal: true

module SlackPossibleObservationsHelper
  # Eye / eye-slash chip for shared pOGO list rows. Icon shape carries the meaning;
  # tooltip explains who can see the row on check-in and pOGO pages.
  def slack_pogo_visibility_indicator(moment, subject:, viewer:)
    return if moment.blank? || subject.blank?

    tooltip = slack_pogo_visibility_tooltip(moment, subject: subject, viewer: viewer)
    return if tooltip.blank?

    icon_class = moment.public_channel? ? "bi-eye" : "bi-eye-slash"
    aria = moment.public_channel? ? "Visible on this page for others" : "Visible only to discoverers"

    content_tag(
      :span,
      content_tag(:i, nil, class: "bi #{icon_class}", "aria-hidden" => "true"),
      class: "text-muted",
      title: tooltip,
      "aria-label" => aria,
      "data-bs-toggle" => "tooltip",
      "data-bs-placement" => "top",
      "data-bs-title" => tooltip
    )
  end

  def slack_pogo_visibility_tooltip(moment, subject:, viewer:)
    if moment.public_channel?
      slack_pogo_public_visibility_tooltip(subject)
    else
      slack_pogo_private_visibility_tooltip(moment, viewer: viewer)
    end
  end

  private

  def slack_pogo_public_visibility_tooltip(subject)
    subject_name = subject.person&.casual_name.presence || "this teammate"
    manager_name = subject.current_manager&.casual_name.presence

    who =
      if manager_name.present?
        "#{subject_name}, #{manager_name}, and their managers"
      else
        "#{subject_name} and their managers"
      end

    "Since this is in a public channel, #{who} will see this pOGO on the check-in and pOGO pages"
  end

  def slack_pogo_private_visibility_tooltip(moment, viewer:)
    names = slack_pogo_discoverer_casual_names(moment)
    who =
      if names.empty?
        "the teammates who discovered it"
      elsif viewer.present? && moment.discovered_by?(viewer) && names.size == 1
        "you"
      else
        names.to_sentence
      end

    "Since this is in a private channel or DM, only #{who} will see this pOGO on the check-in and pOGO pages"
  end

  def slack_pogo_discoverer_casual_names(moment)
    ids = moment.discoverer_ids
    return [] if ids.empty?

    CompanyTeammate.where(id: ids).includes(:person).filter_map { |tm| tm.person&.casual_name.presence }.uniq
  end
end
