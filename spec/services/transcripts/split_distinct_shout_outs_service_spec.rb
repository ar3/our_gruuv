# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcripts::SplitDistinctShoutOutsService do
  let(:kayla_amy_text) do
    "Alright, a few. First, for, Kayla and Nicole. been meeting with them, we try once a week, but schedules, you know. " \
      "And what I've learned from them over these past couple months is a different take on collaboration. " \
      "So, Kayla and Nicole, I appreciate you. Let's go. Couple more… Well, let me just go to the one, which is Amy. " \
      "Y'all, I work with Amy pretty closely, these days, and the thing that I wanted to shout out Amy for… " \
      "Outside of just work anniversary, right, is the fact that she cares so freaking much about each and every one of you. Appreciator."
  end

  it "splits Kayla/Nicole then Amy into two verbatim moments" do
    cues = [
      {
        "id" => "cue-1",
        "speaker_label" => "Andrew",
        "kind" => "speech",
        "text" => kayla_amy_text,
        "source_block_count" => 14,
        "merged" => true
      }
    ]

    split = described_class.call(cues: cues)
    expect(split.size).to eq(2)
    expect(split.first["text"]).to include("Kayla and Nicole")
    expect(split.first["text"]).not_to include("which is Amy")
    expect(split.last["text"]).to include("Amy")
    expect(split.last["text"]).to include("Appreciator")
    expect(kayla_amy_text).to include(split.first["text"])
    expect(kayla_amy_text).to include(split.last["text"])
  end

  it "does not split audio-share cues" do
    cues = [
      {
        "id" => "cue-1",
        "speaker_label" => "Audio shared by Natalie",
        "kind" => "audio_share",
        "text" => "lyrics lyrics Couple more lyrics which is Amy lyrics"
      }
    ]

    expect(described_class.call(cues: cues).size).to eq(1)
  end

  it "splits ordinal shout-out transitions into separate moments" do
    text = <<~TEXT.squish
      Okay, first one is for Kay. This past week, we promoted Kay to a Level 2 PGM, so Kay has been with us for 16 months,
      and her and Ryan have been working really hard on how we can grow insurance adoption. So, congratulations to Kay on that.
      Second shout-out was for Christina. Christina has been managing a lot of our new launches, and some of our partners are
      not always easy to work with, but Christina has been reaching out and collaborating a lot with myself and the PGMs of
      what we can do to keep deals on track and moving through implementation. And, working extra more than she has to to make
      things happen to help us out, so shout out to Christina for that. And then, last shout out for the Evaluate team, Hannah,
      Michelle, Mick, and Brendan. One of the pieces of feedback that Partnerships has been giving for a while is we really
      wanted one-way audio fast-tracked for us to see value, and so they launched that a couple of weeks ago and promised that
      it would be iterated on and delivered on that this week, so really shout out to that team for doing that.
    TEXT

    segments = described_class.split_text(text)
    expect(segments.size).to eq(3)
    expect(segments[0]).to include("first one is for Kay")
    expect(segments[0]).to include("congratulations to Kay")
    expect(segments[0]).not_to include("Christina")
    expect(segments[1]).to include("Second shout-out was for Christina")
    expect(segments[1]).not_to include("Evaluate team")
    expect(segments[2]).to include("last shout out for the Evaluate team")
    expect(segments[2]).to include("Hannah, Michelle, Mick, and Brendan")
  end

  it "splits award, read-aloud shout-outs, and floor reopen into separate cues" do
    text = <<~TEXT.squish
      Kay Shockey! I thought Kayla was gonna win for the third month in a row, and I'm like, maybe I should take you off the
      wheel, Kayla, but Kay Shockey won this time. Congratulations, Kay! And thank you for everyone for, participating and kind
      of building this muscle of feedback and kudos. So, kudos to everyone for that, but Kay, we will follow up with you and get
      you your prize. Cool! Okay, I think those were the tasks I had to do today. I do want to remind anyone who wants to play a
      game of werewolves, I'm gonna host a game after this meeting. Otherwise, I think we can roll into shoutouts and gratitude
      to end the week, and I'll start with the mic, because I have a few I'm going to read for folks here. I have one… for, from
      Gabe, who is on a partner call that's running late, wanted to give a shout out to Jesus for his Hand in Stone conference
      attendance. He blew our goals out of the water. So, nice job. Well done! And then I also have one on behalf of Clint, who
      is flying today, but he had one for Christina Merida. He had the entire Massage Lux FBC team come up to him and tell him
      how much they loved working with Christina. And some nice work, Christina! All right, if you have a shoutout, let me know,
      I think. Let's see, Kayla, you were up first. Go ahead.
    TEXT

    segments = described_class.split_text(text)
    expect(segments.size).to eq(5)
    expect(segments[0]).to include("Kay Shockey won this time")
    expect(segments[0]).not_to include("werewolves")
    expect(segments[1]).to include("werewolves")
    expect(segments[1]).not_to include("shout out to Jesus")
    expect(segments[2]).to include("shout out to Jesus")
    expect(segments[2]).to include("from Gabe")
    expect(segments[3]).to include("Christina Merida")
    expect(segments[3]).to include("on behalf of Clint")
    expect(segments[4]).to include("if you have a shoutout, let me know")
  end
end
