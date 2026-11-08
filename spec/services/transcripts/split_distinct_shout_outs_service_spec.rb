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

  it "splits bare First/Second/And finally ordinals into one cue per person" do
    text = <<~TEXT.squish
      And I lied, sorry, I have three. First, I think Luis is on the call. Just wanted to give a shout out and, for keep
      growing in his position, and he's been doing such a great job with getting interviews, getting demos and meetings
      booked for our team. You can tell that he is working extremely hard, so thank you for that, Luis, and keep crushing
      it, man. Second, Steve, I mean, I think everyone on this call can, has, or will give you flowers at some point, in
      your career, but just amazing job with everything that you've done. You're a great person to work alongside, you're
      a great person to look up to, and it's very, very well deserved of your promotion. And finally, James. Man, I can't
      believe it's been 2 years already. But thank you, for all the hard work. Thank you for your patience, thank you for
      being a sounding board for me when we're going through things. Thank you for the ideas that you bring and the hustle
      that you have for the team. I really appreciate everything you do, and here's to many more.
    TEXT

    segments = described_class.split_text(text)
    expect(segments.size).to eq(3)
    expect(segments[0]).to include("First, I think Luis")
    expect(segments[0]).to include("keep crushing it, man")
    expect(segments[0]).not_to include("Second, Steve")
    expect(segments[1]).to include("Second, Steve")
    expect(segments[1]).to include("well deserved of your promotion")
    expect(segments[1]).not_to include("And finally, James")
    expect(segments[2]).to include("And finally, James")
    expect(segments[2]).to include("here's to many more")
  end

  it "splits Steve congratulations from Polly after My next two / First, I will go with" do
    text = <<~TEXT.squish
      Alright, I got 3 of them. First, the one and only, the homie, the GOAT, Steve. Man, I don't know if you even remember
      this, but, I think it was your first couple months, and we were at Summit. In Austin, it was super hot. I wasn't
      thinking, and I was wearing jeans walking out, and you saw me in the hallway. You're like, hey man, it's hot out
      there, you should go put on some shorts. Turned around, went back to my room, put on some shorts. Fast forward a few
      years later, we're at IFA, and you're hitting us with… what… the strategy that I think is gonna change everything.
      We'll just… we'll just leave it at that, right? And that came from you. Steve is so well deserved. Congratulations.
      My next two, I'm gonna start together. Because there's a shared… commonality between these two, and that is
      unrelenting determination, right? In pursuit of what's right. And I'm gonna get a little physical for a second. When
      you're trying to lift something heavy and move it down the road, right? You first have to lift it up, you know? Brad,
      he understands. First, you gotta lift it up, and then you gotta push. Lift and push, and that's what I think of when
      I think of these two people. First, I will go with Lyft, right? Last week, I missed your Workiversary, Polly. But the
      thing about Polly is she lifts up the entire team. And if you ever talk to her, she'll be like, no, I don't. I do
      nothing. But then you talk to her team around her, and they're like, oh my god, Polly is the reason why this is going
      smooth. Polly lifts up every team she's around. So, Polly, happy Workiversary. I'm sorry I was late from last week.
    TEXT

    segments = described_class.split_text(text)
    expect(segments.size).to be >= 2
    expect(segments[0]).to include("the GOAT, Steve")
    expect(segments[0]).to include("Congratulations")
    expect(segments[0]).not_to include("My next two")
    expect(segments[0]).not_to include("Polly")
    polly = segments.find { |segment| segment.include?("Polly") && segment.include?("Workiversary") }
    expect(polly).to be_present
    expect(polly).to include("First, I will go with Lyft")
    expect(polly).not_to include("the GOAT, Steve")
    # Metaphor "First, you gotta lift" must not become its own cue.
    expect(segments.none? { |segment| segment.start_with?("First, you gotta lift") }).to be(true)
  end

  it "splits a soft-pivot kudos monologue into one cue per person or group" do
    text = <<~TEXT.squish
      Sorry, my Siri heard my name called and was like, yes, what do you need? And that was kind of creepy. Okay, I have a few.
      The Work Together, Win Together effort that, Nicolle Gatlin Andrew Hall showed on jumping on the chat duty for our Indeed
      webinar, which was wildly, active, was amazing help. And then Natalie, you can stick Natalie in front of any audience and
      ask her to moderate, and she's just stellar. So I felt like that was really supportive. Work Together, Win Together. Also,
      for the marketing team and Missy, I think you guys have about 100 spinning plates in the air, between helping promote
      webinars and follow-ups, and then everything the sales team has needed. You guys probably should win the Q4 Work Together,
      Win Together award as a team. So thanks for that. Sydney Kidd. You have impressed me so much lately, so this is keep
      growing for you, with how you think about leading your team, and how you think about the mindset they need to hear, and
      exact words that you know will drive the why, and help them really connect dots. I've been very impressed, with how you're
      approaching your leadership lately. 2 more. Seref, has been so kind in some gnarly escalations that he's, handled, and I
      think, you know, I ask you for a lot of data, Seref, you're very thorough. I'm very impressed with how you're handling
      your work, as well. And then… I'm wrapping with Ina. Ina, keep growing. Your chops are stellar. I think you're more
      motivated to earn money than even Brad Pilot, it feels like, which is saying a lot. I love the drive you have to, like,
      just push for the business and experiment, and… A-B test, and your brain is exactly where we need it to be right now, and
      I can feel it, so thank you. That's it.
    TEXT

    segments = described_class.split_text(text)
    expect(segments.size).to eq(6)
    expect(segments[0]).to include("Nicolle Gatlin Andrew Hall")
    expect(segments[0]).not_to include("And then Natalie")
    expect(segments[1]).to include("And then Natalie")
    expect(segments[1]).not_to include("Also, for the marketing team")
    expect(segments[2]).to include("Also, for the marketing team and Missy")
    expect(segments[2]).not_to include("Sydney Kidd")
    expect(segments[3]).to include("Sydney Kidd. You have impressed")
    expect(segments[3]).not_to include("2 more")
    expect(segments[4]).to include("2 more")
    expect(segments[4]).to include("Seref")
    expect(segments[4]).not_to include("wrapping with Ina")
    expect(segments[5]).to include("I'm wrapping with Ina")
    expect(segments[5]).to include("Your chops are stellar")
  end

  it "does not split same-person Workiversary paragraph beats" do
    text = <<~TEXT.squish
      It's been really great to have a front row seat to all of the progress that you've driven over the past two years.
      I can't believe you've been here for two already. You bring so much energy and dedication to everything that you do,
      and the impact that you've made on the team is beyond amazing. And besides being a great senior product manager, you
      also bring so much kindness to the way that you work and the care for your teammates. So, we're so lucky to have you
      on the team, and I can't wait to see what you do in the coming year. So happy Workiversary.
    TEXT

    expect(described_class.split_text(text).size).to eq(1)
  end

  it "splits a thank-you pivot monologue into one cue per new observee" do
    text = <<~TEXT.squish
      Oh, I did, because I've got so many, oh my gosh. There's so much to be thankful for this past week. But to start,
      I'm gonna start with the… there's a lot of people, there's a lot of folks I'm gonna go through. PGMs, PSMs, partner
      services, and especially Nicole, Kayla, and Bella. Why am I thanking that group? They have worked for… quarters, I'd
      say, for partner services for two quarters, and PGM's close to that as well, compiling data on our existing partners
      to know who they use and who they recommend, who they prefer, or if they don't recommend anyone for payroll services,
      operations, LMSs, you name it. And they've gotten a ton of data from that, which has been extremely helpful, and it's
      also going to be useful For some conversations that Clint's having next week as well, so can't thank you guys enough.
      I know it wasn't easy to be able to gather all that information and compile it in one spot, so special thanks to
      Nicolle and Bella, who spent a lot of time on the spreadsheet making that perfect today as well, so thank you guys.
      Also, I want to thank Josh. and Clint for their FBR conference efforts last week. I don't know if it was talked about
      last week or not, but they got 15 leads, 6 book demos, multiple deals in the pipeline that they've helped move forward.
      So, FBR was a huge success, even though it's a really small event. It looks like it's going to be more successful for
      us, potentially, than IFA, which is our really big event that we have in February. So, awesome job, Josh, and all of
      your efforts there, and of course, Clint. Then everyone involved in end-of-year specials to improve our new MRR for Q4.
      We want to make sure we're hitting numbers right, so we all can get our bonuses. And that list of folks that is helping
      is growing. First and foremost, Celene, for having to create a million email campaigns over the past week, which is no
      small feat, and we've put a lot of pressure on her to create a lot of different campaigns. And she does it with a smile,
      she does a great job, she takes all the feedback, she creates stuff. Sending us stuff late night, too, I know she's,
      West Coast, can't thank you enough, Celene. Really appreciate all the efforts. there. Of course, not just Celene, but
      we needed Julie's help for creating new plans in the system, which she jumped on. Sydney Petchel for making the changes
      to account classes that were running the plans for… she did that before she went on PTO last night and jumped in and
      knocked that out. Can't thank her enough for it. And then, of course, everyone that's involved, from the PGMs, reviewing
      scripts, figuring out the best ways to push out the specials. I'm very excited for what we're gonna launch, and we have
      3 really big promotions. Walter knows of one of them, because we did it back in the day, but for State Farm, there's gonna
      be a special we're rolling out that's 15 months at the price of 12. We're also taking some partners that we know have
      very low hiring needs, like, Wild Birds Unlimited, for example, purposes, where they tend to have under 5 employees, and
      over the years, we keep raising our rates, right? But we've identified there's certain brands where they have such low
      hiring needs, we're offering, Hire and Grow Lite, which is at a discounted rate, so $4.95 for the year for hire, $6.95
      for the year for Grow. And we're pushing out two specials, well, specials that are in a two-part through the end of the
      year. One is like a… a… false end that's right before Thanksgiving to try to really drive as much adoption as possible
      from now until Thanksgiving. And then because of popular demand, and of course, such a great response, we're gonna extend
      it again right before Christmas so we can get another burst. Then we also have another group that is… Grow for the price
      of higher. And so those are the three different groups that we're doing. There's a lot of efforts going behind the scenes,
      and I know even AR3 and Products jumping in to help. Natalie's offered to do some webinars for groups to drive some
      additional opportunities there, so it is a company effort to be able to drive our sales in Q4, and I can't thank everyone
      enough for all of your efforts in prioritizing that as well. Of course, I have to say, Steve, he's amazing. promotion so
      well deserved, like, my gosh, everyone that works with Steve has wonderful experiences, including our partners, so well
      deserved, Steve. Can't thank you enough for being on the team.
    TEXT

    segments = described_class.split_text(text)
    expect(segments.size).to eq(6)
    expect(segments[0]).to include("Nicole, Kayla, and Bella")
    expect(segments[0]).not_to include("Also, I want to thank Josh")
    expect(segments[1]).to include("Also, I want to thank Josh")
    expect(segments[1]).to include("Clint")
    expect(segments[1]).not_to include("First and foremost, Celene")
    expect(segments[2]).to include("First and foremost, Celene")
    expect(segments[2]).not_to include("but we needed Julie's help")
    expect(segments[3]).to include("but we needed Julie's help")
    expect(segments[3]).not_to include("Sydney Petchel for making")
    expect(segments[4]).to include("Sydney Petchel for making")
    expect(segments[4]).not_to include("Of course, I have to say, Steve")
    expect(segments[5]).to include("Of course, I have to say, Steve")
    # Promo digression stays with Sydney — not its own person cue.
    expect(segments[4]).to include("State Farm")
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
