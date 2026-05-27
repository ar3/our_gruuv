# frozen_string_literal: true

module Insights
  # "Why it matters" copy for kudos mix and rating intensity bands (insights + observations health).
  class ObservationsRatingHealthCopy
    class << self
      def kudos_constructive_html(band:, subject_name:)
        band = band.to_sym
        case band
        when :above_seven
          h.content_tag(:div, class: "small") do
            h.safe_join([
              h.content_tag(:p, class: "mb-2") do
                "This suggests #{h.escape_once(subject_name)} may rarely document constructive feedback in OGO. " \
                  "Giving constructive feedback is hard; documenting it can feel risky. Consider whether withholding " \
                  "clarity is truly kind—and whether a healthy mix of kudos and constructive feedback helps everyone " \
                  "know where they stand."
              end,
              h.content_tag(:ul, class: "mb-0 ps-3") do
                h.safe_join([
                  h.content_tag(:li, "Does this feedback help people get better? Being kind is being clear.", class: "mb-1"),
                  h.content_tag(:li, "A healthy OG culture balances celebration with honest improvement.", class: "mb-0")
                ])
              end
            ])
          end
        when :healthy
          h.content_tag(
            :p,
            "#{subject_name} has a healthy mix of kudos-style and constructive OGOs—people likely know both what success looks like and how to improve. 🎉 Well done 🎉",
            class: "small mb-0"
          )
        when :below_three
          h.content_tag(
            :p,
            "This suggests #{subject_name} leans constructive, which can be valuable, but balance matters. Folks need to hear what success looks like—not only what to avoid.",
            class: "small mb-0"
          )
        when :no_data
          h.content_tag(:p, "Not enough published OGOs (authored by this person) to assess kudos vs constructive mix.", class: "small text-muted mb-0")
        else
          h.content_tag(:p, "Unable to assess this ratio.", class: "small text-muted mb-0")
        end
      end

      def rating_intensity_html(band:, subject_name:)
        band = band.to_sym
        case band
        when :above_five
          h.content_tag(:p, class: "small mb-0") do
            h.safe_join([
              "#{subject_name} may be under-using ",
              h.content_tag(:strong, "Exceptional"),
              " and ",
              h.content_tag(:strong, "Concerning"),
              " relative to ",
              h.content_tag(:strong, "Solid"),
              " and ",
              h.content_tag(:strong, "Misaligned"),
              ". The strongest positive and negative signals should stay rare—but not ",
              h.content_tag(:em, "this"),
              " rare, or standout work and serious gaps can get lost in the middle buckets."
            ])
          end
        when :below_one
          h.content_tag(:p, class: "small mb-0") do
            h.safe_join([
              "This may be a ",
              h.content_tag(:strong, "calibration"),
              " issue: ",
              h.content_tag(:strong, "Exceptional"),
              " or ",
              h.content_tag(:strong, "Concerning"),
              " may be used often relative to ",
              h.content_tag(:strong, "Solid"),
              " and ",
              h.content_tag(:strong, "Misaligned"),
              ", making it harder to tell strong work from stand-out work—or everyday gaps from serious issues."
            ])
          end
        when :healthy
          h.content_tag(
            :p,
            "#{subject_name} has a healthy balance between everyday ratings (Solid / Misaligned) and the most extreme buckets (Exceptional / Concerning). 🎉 Well done 🎉",
            class: "small mb-0"
          )
        when :no_data
          h.content_tag(:p, "Not enough ratings on this person's published OGOs to assess rating intensity.", class: "small text-muted mb-0")
        else
          h.content_tag(:p, "Unable to assess this ratio.", class: "small text-muted mb-0")
        end
      end

      def h
        @helpers ||= ApplicationController.helpers
      end
    end
  end
end
