# frozen_string_literal: true

module HealthNudges
  # Per-page copy and routing for health nudge sends.
  module Registry
    FLOW_TED_URL = "https://www.ted.com/talks/mihaly_csikszentmihalyi_flow_the_secret_to_happiness"

    # Shared "why" for Clarity Check-Ins (Check-ins Health + Overall Health).
    CLARITY_CHECK_INS_WHY = [
      "We do Clarity check-ins for 3 reasons: continuously more clear expectations, " \
      "employees know where they stand against these expectations, and managers able to coach " \
      "with specificity and therefore actionability.",
      "",
      "Why this matters? <#{FLOW_TED_URL}|Mihaly Csikszentmihalyi>, the creator of the concept of Flow State, " \
      "theorizes happiness and maximum productivity come from continually getting into Flow State. " \
      "Clarity Check-Ins encourage flow state by enabling Challenge (what are the expectations), " \
      "Clarity, and Continuous Feedback (where I stand)."
    ].join("\n").freeze

    HEALTH_OBJECTS = {
      "goals_health" => {
        label: "Goals Health",
        notice: "Goals Health nudge sent.",
        nudge_path_name: :organization_goals_health_nudge_path,
        dashboard_url_name: :organization_goals_health_url,
        dashboard_link_label: "Open Goals Health for your team",
        title: "Goals Health check-in",
        greeting: "a quick look at Goal Confidence for your direct reports",
        metric_label: "Goal Confidence",
        importance: "Fresh Goal Confidence check-ins keep goals honest: they surface and encourage " \
                    "the most important aspect of goals... they encourage deliberate and continuous learning. " \
                    "By reflecting on goals and why your confidence in hitting the goal changes week over week, " \
                    "you can't help but learn along the way. This will help you adjust, better communicate, " \
                    "and ultimately it will help the entire team grow.",
        healthy_closing: "Nice work keeping Goal Confidence current ... that habit makes the harder conversations easier.",
        empty_closing: "When folks join your team, this view will help you keep Goal Confidence on track."
      },
      "check_ins_health" => {
        label: "Check-ins Health",
        notice: "Check-ins Health nudge sent.",
        nudge_path_name: :organization_check_ins_health_nudge_path,
        dashboard_url_name: :organization_check_ins_health_url,
        dashboard_link_label: "Open Check-ins Health for your team",
        title: "Check-ins Health check-in",
        greeting: "a quick look at Required Clarity check-ins for your direct reports",
        metric_label: "Required Clarity",
        importance: CLARITY_CHECK_INS_WHY,
        healthy_closing: "Nice work keeping clarity check-ins current ... that rhythm protects flow for your team.",
        empty_closing: "When folks join your team, this view will help you keep clarity check-ins on track."
      },
      "milestones_health" => {
        label: "Milestones Health",
        notice: "Milestones Health nudge sent.",
        nudge_path_name: :organization_milestones_health_nudge_path,
        dashboard_url_name: :organization_milestones_health_url,
        dashboard_link_label: "Open Milestones Health for your team",
        title: "Milestones Health check-in",
        greeting: "a quick look at required ability milestones for your direct reports",
        metric_label: "Required Milestones",
        importance: "Required milestones are how we calibrate challenge... Continuous Growth requires " \
                    "specificity in challenge. Ability Milestones lay out clear next steps that end in " \
                    "recognition that means something... that teammates can carry with them throughout " \
                    "their careers. Growth is not the big moments like position changes/promotions... " \
                    "true growth happens continuously, and Milestones bring that continuous growth to light!",
        healthy_closing: "Nice work keeping milestone coverage current ... that balance keeps challenge healthy.",
        empty_closing: "When folks join your team, this view will help you keep milestone coverage on track."
      },
      "observations_health" => {
        label: "Observations Health",
        notice: "Observations Health nudge sent.",
        nudge_path_name: :organization_observations_health_nudge_path,
        dashboard_url_name: :organization_observations_health_url,
        dashboard_link_label: "Open Observations Health for your team",
        title: "Observations Health check-in",
        greeting: "a quick look at OGO cadence for your direct reports",
        metric_label: "OGO health",
        importance: "Steady observation rhythm keeps feedback continuous ... when OGOs slip, people miss " \
                    "the clarity and recognition that fuel growth.",
        healthy_closing: "Nice work keeping OGO cadence healthy ... that habit keeps feedback flowing.",
        empty_closing: "When folks join your team, this view will help you keep OGO cadence on track."
      },
      "protect_flow" => {
        label: "Overall Health",
        notice: "Overall Health nudge sent.",
        nudge_path_name: :nudge_organization_protect_flow_path,
        dashboard_url_name: :organization_protect_flow_url,
        dashboard_link_label: "Open Overall Health for your team",
        title: "Overall Health check-in",
        greeting: "a quick look at Overall Health for your direct reports",
        metric_label: "Overall Health",
        importance: [
          CLARITY_CHECK_INS_WHY,
          "",
          "Overall Health keeps clarity, challenge, and feedback visible together ... " \
          "small weekly attention beats big quarterly surprises."
        ].join("\n"),
        healthy_closing: "Nice work keeping Overall Health on track this week ... that focus protects flow.",
        empty_closing: "When folks join your team, Overall Health will help you stay ahead of stale clarity.",
        summary_style: :protect_flow
      }
    }.freeze

    module_function

    def fetch(health_object)
      HEALTH_OBJECTS.fetch(health_object.to_s)
    end

    def valid?(health_object)
      HEALTH_OBJECTS.key?(health_object.to_s)
    end
  end
end
