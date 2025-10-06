module Feelings
  FEELINGS = [
    { display: '😀 (Happy)', discrete_feeling: :happy, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🙂 (Content)', discrete_feeling: :content, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🧐 (Inquisitive)', discrete_feeling: :inquisitive, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🤔 (Curious)', discrete_feeling: :curious, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😁 (Confident)', discrete_feeling: :confident, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😎 (Proud)', discrete_feeling: :proud, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🤗 (Valued)', discrete_feeling: :valued, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🤨 (Courageous)', discrete_feeling: :courageous, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🤪 (Playful)', discrete_feeling: :playful, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😌 (Thankful)', discrete_feeling: :peaceful, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🥰 (Accepted)', discrete_feeling: :accepted, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🤩 (Inspired)', discrete_feeling: :inspired, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😂 (Joyful)', discrete_feeling: :joyful, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😉 (Optimistic)', discrete_feeling: :optimistic, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😅 (Relieved)', discrete_feeling: :relieved, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🥳 (Excited)', discrete_feeling: :excited, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😆 (Eager)', discrete_feeling: :eager, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😊 (Satisfied)', discrete_feeling: :satisfied, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😇 (Blessed)', discrete_feeling: :blessed, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🤓 (Focused)', discrete_feeling: :focused, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😋 (Enthusiastic)', discrete_feeling: :enthusiastic, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '🤭 (Amused)', discrete_feeling: :amused, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😏 (Smug)', discrete_feeling: :smug, base_feeling: :happy, display_grouping: :happy, positive_negative_or_neutral: :positive },
    { display: '😐 (Meh)', discrete_feeling: :meh, base_feeling: :meh, display_grouping: :meh, positive_negative_or_neutral: :neutral },
    { display: '😳 (Shocked)', discrete_feeling: :shocked, base_feeling: :surprised, display_grouping: :surprised, positive_negative_or_neutral: :neutral },
    { display: '🤯 (Astonished)', discrete_feeling: :astonished, base_feeling: :surprised, display_grouping: :surprised, positive_negative_or_neutral: :neutral },
    { display: '😲 (Awed)', discrete_feeling: :awed, base_feeling: :surprised, display_grouping: :surprised, positive_negative_or_neutral: :neutral },
    { display: '😶 (Perplexed)', discrete_feeling: :perplexed, base_feeling: :surprised, display_grouping: :surprised, positive_negative_or_neutral: :neutral },
    { display: '😕 (Confused)', discrete_feeling: :confused, base_feeling: :surprised, display_grouping: :surprised, positive_negative_or_neutral: :neutral },
    { display: '😓 (Stressed)', discrete_feeling: :stressed, base_feeling: :bad, display_grouping: :bad, positive_negative_or_neutral: :negative },
    { display: '😴 (Sleepy)', discrete_feeling: :sleepy, base_feeling: :bad, display_grouping: :bad, positive_negative_or_neutral: :negative },
    { display: '😣 (Pressured)', discrete_feeling: :pressured, base_feeling: :bad, display_grouping: :bad, positive_negative_or_neutral: :negative },
    { display: '😫 (Overwhelmed)', discrete_feeling: :overwhelmed, base_feeling: :bad, display_grouping: :bad, positive_negative_or_neutral: :negative },
    { display: '😞 (Lonely)', discrete_feeling: :lonely, base_feeling: :sad, display_grouping: :bad, positive_negative_or_neutral: :negative },
    { display: '😬 (Nervous)', discrete_feeling: :nervous, base_feeling: :fearful, display_grouping: :fearful, positive_negative_or_neutral: :negative },
    { display: '😥 (Fearful)', discrete_feeling: :fearful, base_feeling: :fearful, display_grouping: :fearful, positive_negative_or_neutral: :negative },
    { display: '😨 (Anxious)', discrete_feeling: :anxious, base_feeling: :fearful, display_grouping: :fearful, positive_negative_or_neutral: :negative },
    { display: '😰 (Worried)', discrete_feeling: :worried, base_feeling: :fearful, display_grouping: :fearful, positive_negative_or_neutral: :negative },
    { display: '😱 (Scared)', discrete_feeling: :scared, base_feeling: :fearful, display_grouping: :fearful, positive_negative_or_neutral: :negative },
    { display: '😤 (Annoyed)', discrete_feeling: :annoyed, base_feeling: :angry, display_grouping: :angry, positive_negative_or_neutral: :negative },
    { display: '😖 (Frustrated)', discrete_feeling: :frustrated, base_feeling: :angry, display_grouping: :angry, positive_negative_or_neutral: :negative },
    { display: '😠 (Angry)', discrete_feeling: :angry, base_feeling: :angry, display_grouping: :angry, positive_negative_or_neutral: :negative },
    { display: '😡 (Mad)', discrete_feeling: :mad, base_feeling: :angry, display_grouping: :angry, positive_negative_or_neutral: :negative },
    { display: '🤬 (Furious)', discrete_feeling: :furious, base_feeling: :angry, display_grouping: :angry, positive_negative_or_neutral: :negative },
    { display: '😒 (Disapproving)', discrete_feeling: :disapproving, base_feeling: :disgusted, display_grouping: :bad, positive_negative_or_neutral: :negative },
    { display: '😔 (Disappointed)', discrete_feeling: :disappointed, base_feeling: :disgusted, display_grouping: :bad, positive_negative_or_neutral: :negative },
    { display: '😮 (Surprised)', discrete_feeling: :surprised, base_feeling: :surprised, display_grouping: :surprised, positive_negative_or_neutral: :neutral },
  ].freeze

  def self.hydrate(discrete_feeling)
    FEELINGS.find { |feeling| feeling[:discrete_feeling] == discrete_feeling.to_sym }
  end

  def self.hydrate_and_sentencify(primary_discrete_feeling_or_array, secondary_discrete_feeling = nil)
    raw_feelings = primary_discrete_feeling_or_array.is_a?(Array) ? primary_discrete_feeling_or_array : [primary_discrete_feeling_or_array]
    raw_feelings << secondary_discrete_feeling if secondary_discrete_feeling.present?

    feelings_grouped = raw_feelings.map { |feeling| hydrate(feeling).try(:[], :display).presence }.compact.group_by { |s| s }
    
    feelings = feelings_grouped.keys.map do |feeling|
      extras = feelings_grouped[feeling].size - 1
      "#{extras.times.map { 'extra' }.join(' ')} #{feeling}".strip
    end.flatten

    feelings.to_sentence
  end

  def self.grouped
    FEELINGS.group_by { |feeling| feeling[:display_grouping] }
  end

  def self.positive_feelings
    FEELINGS.select { |feeling| feeling[:positive_negative_or_neutral] == :positive }
  end

  def self.negative_feelings
    FEELINGS.select { |feeling| feeling[:positive_negative_or_neutral] == :negative }
  end

  def self.neutral_feelings
    FEELINGS.select { |feeling| feeling[:positive_negative_or_neutral] == :neutral }
  end

  def self.by_grouping(grouping)
    FEELINGS.select { |feeling| feeling[:display_grouping] == grouping.to_sym }
  end
end