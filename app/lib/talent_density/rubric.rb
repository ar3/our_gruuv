# frozen_string_literal: true

module TalentDensity
  module Rubric
    HEADLINE = "Picture the next 6–12 months two ways"
    YEAR_A = "they stay in this seat"
    YEAR_B = "someone else/new in magically ramped and in this seat"
    QUESTION = "What's best for the team and for them?"

    CHOICES = [
      {
        key: "take_the_swap",
        id_do: "I'd take the swap",
        id_feel: "Relieved — they and the team would both be better off",
        it_means: "A different fit would serve both",
        tone: "warning",
        rare: true
      },
      {
        key: "fine_either_way",
        id_do: "I'd do nothing",
        id_feel: "Mixed — some things I'd miss, some I wouldn't",
        it_means: "They're a solid fit for this seat",
        tone: "info",
        most_people: true
      },
      {
        key: "try_to_avoid_the_swap",
        id_do: "I'd work to avoid the swap",
        id_feel: "Protective — this seat would lose something we wouldn't get back",
        it_means: "They're uniquely right for this seat",
        tone: "success",
        rare: true
      }
    ].freeze

    module_function

    def choice_for(key)
      CHOICES.find { |choice| choice[:key] == key.to_s }
    end

    def do_label(key)
      choice_for(key)&.fetch(:id_do)
    end
  end
end
