require 'rails_helper'

RSpec.describe Feelings, type: :concern do
  describe '.hydrate' do
    it 'returns the feeling hash for a valid discrete feeling' do
      result = Feelings.hydrate(:happy)
      
      expect(result).to eq({
        display: '😀 (Happy)',
        discrete_feeling: :happy,
        base_feeling: :happy,
        display_grouping: :happy,
        positive_negative_or_neutral: :positive
      })
    end

    it 'returns nil for an invalid discrete feeling' do
      result = Feelings.hydrate(:invalid_feeling)
      expect(result).to be_nil
    end

    it 'works with string input' do
      result = Feelings.hydrate('happy')
      expect(result[:discrete_feeling]).to eq(:happy)
    end

    it 'returns nil for nil input' do
      result = Feelings.hydrate(nil)
      expect(result).to be_nil
    end
  end

  describe '.hydrate_and_sentencify' do
    it 'handles a single primary feeling' do
      result = Feelings.hydrate_and_sentencify(:happy)
      expect(result).to eq('😀 (Happy)')
    end

    it 'handles primary and secondary feelings' do
      result = Feelings.hydrate_and_sentencify(:happy, :inspired)
      expect(result).to eq('😀 (Happy) and 🤩 (Inspired)')
    end

    it 'handles duplicate feelings with "extra" prefix' do
      result = Feelings.hydrate_and_sentencify([:happy, :happy], :happy)
      expect(result).to eq('extra extra 😀 (Happy)')
    end

    it 'handles array input' do
      result = Feelings.hydrate_and_sentencify([:happy, :inspired])
      expect(result).to eq('😀 (Happy) and 🤩 (Inspired)')
    end

    it 'handles nil secondary feeling' do
      result = Feelings.hydrate_and_sentencify(:happy, nil)
      expect(result).to eq('😀 (Happy)')
    end

    it 'handles nil primary feeling' do
      result = Feelings.hydrate_and_sentencify(nil)
      expect(result).to eq('')
    end

    it 'handles nil primary and secondary feelings' do
      result = Feelings.hydrate_and_sentencify(nil, nil)
      expect(result).to eq('')
    end

    it 'returns empty string for invalid feelings' do
      result = Feelings.hydrate_and_sentencify(:invalid_feeling)
      expect(result).to eq('')
    end
  end

  describe '.grouped' do
    it 'groups feelings by display_grouping' do
      grouped = Feelings.grouped
      
      expect(grouped.keys).to include(:happy, :meh, :surprised, :bad, :fearful, :angry)
      expect(grouped[:happy]).to be_an(Array)
      expect(grouped[:happy].size).to be > 0
    end

    it 'includes all feelings in the grouping' do
      grouped = Feelings.grouped
      total_grouped = grouped.values.flatten.size
      expect(total_grouped).to eq(Feelings::FEELINGS.size)
    end
  end

  describe '.positive_feelings' do
    it 'returns only positive feelings' do
      positive = Feelings.positive_feelings
      
      expect(positive).to be_an(Array)
      expect(positive.all? { |f| f[:positive_negative_or_neutral] == :positive }).to be true
      expect(positive.any? { |f| f[:discrete_feeling] == :happy }).to be true
    end
  end

  describe '.negative_feelings' do
    it 'returns only negative feelings' do
      negative = Feelings.negative_feelings
      
      expect(negative).to be_an(Array)
      expect(negative.all? { |f| f[:positive_negative_or_neutral] == :negative }).to be true
      expect(negative.any? { |f| f[:discrete_feeling] == :angry }).to be true
    end
  end

  describe '.neutral_feelings' do
    it 'returns only neutral feelings' do
      neutral = Feelings.neutral_feelings
      
      expect(neutral).to be_an(Array)
      expect(neutral.all? { |f| f[:positive_negative_or_neutral] == :neutral }).to be true
      expect(neutral.any? { |f| f[:discrete_feeling] == :meh }).to be true
    end
  end

  describe '.by_grouping' do
    it 'returns feelings for a specific grouping' do
      happy_feelings = Feelings.by_grouping(:happy)
      
      expect(happy_feelings).to be_an(Array)
      expect(happy_feelings.all? { |f| f[:display_grouping] == :happy }).to be true
      expect(happy_feelings.any? { |f| f[:discrete_feeling] == :happy }).to be true
    end

    it 'returns empty array for invalid grouping' do
      result = Feelings.by_grouping(:invalid_grouping)
      expect(result).to eq([])
    end
  end

  describe 'FEELINGS constant' do
    it 'contains exactly 47 feelings' do
      expect(Feelings::FEELINGS.size).to eq(47)
    end

    it 'has all required keys for each feeling' do
      required_keys = [:display, :discrete_feeling, :base_feeling, :display_grouping, :positive_negative_or_neutral]
      
      Feelings::FEELINGS.each do |feeling|
        required_keys.each do |key|
          expect(feeling).to have_key(key), "Feeling #{feeling[:discrete_feeling]} missing key: #{key}"
        end
      end
    end

    it 'has unique discrete_feeling values' do
      discrete_feelings = Feelings::FEELINGS.map { |f| f[:discrete_feeling] }
      expect(discrete_feelings.uniq.size).to eq(discrete_feelings.size)
    end

    it 'has valid positive_negative_or_neutral values' do
      valid_values = [:positive, :negative, :neutral]
      
      Feelings::FEELINGS.each do |feeling|
        expect(valid_values).to include(feeling[:positive_negative_or_neutral]),
          "Invalid positive_negative_or_neutral for #{feeling[:discrete_feeling]}: #{feeling[:positive_negative_or_neutral]}"
      end
    end
  end
end




