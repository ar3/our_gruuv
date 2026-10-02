# frozen_string_literal: true

module MaapProposals
  class UploadSeatMarkdown
    def self.call(seat:, proposer:, markdown:)
      new(seat: seat, proposer: proposer, markdown: markdown).call
    end

    def initialize(seat:, proposer:, markdown:)
      @seat = seat
      @proposer = proposer
      @markdown = markdown
    end

    def call
      result = SeatMarkdownDeserializer.call(
        markdown: @markdown,
        organization: @seat.company,
        seat: @seat
      )
      return result unless result.ok?

      if result.value[:kind] == "create"
        return Result.err("This markdown is a create proposal; upload it from Proposed Seat creates")
      end

      CreateSeatEditDraft.call(
        seat: @seat,
        proposer: @proposer,
        source: "markdown",
        payload: result.value[:payload],
        source_markdown: @markdown
      )
    end
  end
end
