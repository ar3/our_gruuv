# frozen_string_literal: true

module HealthNudges
  # Per-page copy and routing for health nudge sends.
  module Registry
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
        importance: "Fresh Goal Confidence check-ins keep goals honest: they surface when priorities " \
                    "shift so the team can course-correct before work drifts.",
        healthy_closing: "Nice work keeping Goal Confidence current — that habit makes the harder conversations easier.",
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
        importance: "Current clarity check-ins keep assignments understandable and possible — " \
                    "when they slip, people lose alignment on what matters most.",
        healthy_closing: "Nice work keeping clarity check-ins current — that rhythm protects flow for your team.",
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
        importance: "Required milestones are how we calibrate challenge — staying current helps people grow " \
                    "without drifting too easy or too hard.",
        healthy_closing: "Nice work keeping milestone coverage current — that balance keeps challenge healthy.",
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
        importance: "Steady observation rhythm keeps feedback continuous — when OGOs slip, people miss " \
                    "the clarity and recognition that fuel growth.",
        healthy_closing: "Nice work keeping OGO cadence healthy — that habit keeps feedback flowing.",
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
        importance: "Protecting flow means staying on top of clarity, challenge, and feedback together — " \
                    "small weekly attention beats big quarterly surprises.",
        healthy_closing: "Nice work keeping Overall Health on track this week — that focus protects flow.",
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
