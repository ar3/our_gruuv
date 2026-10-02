# frozen_string_literal: true

module Seats
  # Related-title peers + org-chart payloads for seat show.
  class ShowPageData
    RelatedGroup = Data.define(:title, :seats)
    FilledRow = Data.define(:seat, :person, :teammate)

    def initialize(seat:, organization:)
      @seat = seat
      @organization = organization
    end

    def primary_title_peers
      return RelatedGroup.new(title: nil, seats: []) if @seat.title_id.blank?

      RelatedGroup.new(
        title: @seat.title,
        seats: seat_rows(
          org_seats.select { |s| s.title_id == @seat.title_id && s.id != @seat.id }
        )
      )
    end

    def other_title_peer_groups
      primary_peer_ids = primary_title_peers.seats.map { |row| row.seat.id }.to_set
      primary_peer_ids << @seat.id

      other_titles.filter_map do |title|
        peers = org_seats.select do |s|
          next false if primary_peer_ids.include?(s.id)

          s.includes_title_id?(title.id)
        end
        next if peers.empty?

        RelatedGroup.new(title: title, seats: seat_rows(peers))
      end
    end

    def hierarchy_roots
      @hierarchy_roots ||= begin
        full = SeatHierarchyQuery.new(organization: @organization).call
        prune_forest(full, relevant_seat_ids)
      end
    end

    def highcharts_organization_data
      seats = relevant_seats
      nodes = seats.map do |seat|
        person = filler_person(seat)
        node = {
          id: node_id(seat.id),
          name: person&.casual_name.presence || seat.state.titleize,
          title: seat.display_name.to_s.truncate(40),
          url: seat_url(seat)
        }
        if seat.id == @seat.id
          node[:color] = "#0d6efd"
          node[:borderColor] = "#084298"
        end
        node
      end

      links = seats.filter_map do |seat|
        next if seat.reports_to_seat_id.blank?
        next unless relevant_seat_ids.include?(seat.reports_to_seat_id)

        { from: node_id(seat.reports_to_seat_id), to: node_id(seat.id) }
      end

      { nodes: nodes, links: links }
    end

    def highcharts_treegraph_data
      seats = relevant_seats
      nodes = seats.map do |seat|
        person = filler_person(seat)
        parent = if seat.reports_to_seat_id.present? && relevant_seat_ids.include?(seat.reports_to_seat_id)
          node_id(seat.reports_to_seat_id)
        end
        node = {
          id: node_id(seat.id),
          name: person&.casual_name.presence || seat.state.titleize,
          subtitle: seat.display_name.to_s.truncate(50),
          url: seat_url(seat),
          parent: parent
        }
        if seat.id == @seat.id
          node[:color] = "#0d6efd"
        end
        node
      end

      { nodes: nodes }
    end

    def cytoscape_elements
      seats = relevant_seats
      nodes = seats.map do |seat|
        person = filler_person(seat)
        label = if person
          "#{person.casual_name}\n#{seat.display_name}"
        else
          "#{seat.state.titleize}\n#{seat.display_name}"
        end
        {
          group: "nodes",
          data: {
            id: node_id(seat.id),
            label: label.truncate(80),
            url: seat_url(seat),
            isCurrent: seat.id == @seat.id
          }
        }
      end

      edges = seats.filter_map do |seat|
        next if seat.reports_to_seat_id.blank?
        next unless relevant_seat_ids.include?(seat.reports_to_seat_id)

        {
          group: "edges",
          data: {
            id: "e#{seat.reports_to_seat_id}-#{seat.id}",
            source: node_id(seat.reports_to_seat_id),
            target: node_id(seat.id)
          }
        }
      end

      nodes + edges
    end

    def cytoscape_root_node_ids
      seats = relevant_seats
      child_ids = seats.filter_map do |seat|
        next unless relevant_seat_ids.include?(seat.reports_to_seat_id)

        seat.id
      end.to_set

      roots = seats.map(&:id).to_set - child_ids
      roots = seats.map(&:id).to_set if roots.empty?
      roots.map { |id| node_id(id) }
    end

    private

    def other_titles
      ids = @seat.associated_title_ids - Array(@seat.title_id)
      return [] if ids.empty?

      Title.where(id: ids).order(:external_title).to_a
    end

    def org_seats
      @org_seats ||= Seat.for_organization(@organization)
                        .includes(:title, :titles, :seat_titles, employment_tenures: { company_teammate: :person })
                        .order("titles.external_title ASC, seats.seat_needed_by ASC")
                        .to_a
    end

    def relevant_seat_ids
      @relevant_seat_ids ||= begin
        ids = Set.new([@seat.id])
        current = @seat
        while current.reports_to_seat_id.present?
          ids << current.reports_to_seat_id
          current = org_seats_by_id[current.reports_to_seat_id] || current.reports_to_seat
          break if current.nil? || ids.size > 200
        end

        queue = [@seat.id]
        while queue.any?
          parent_id = queue.shift
          org_seats.each do |candidate|
            next unless candidate.reports_to_seat_id == parent_id
            next if ids.include?(candidate.id)

            ids << candidate.id
            queue << candidate.id
          end
        end
        ids
      end
    end

    def relevant_seats
      @relevant_seats ||= org_seats.select { |s| relevant_seat_ids.include?(s.id) }
    end

    def org_seats_by_id
      @org_seats_by_id ||= org_seats.index_by(&:id)
    end

    def seat_rows(seats)
      seats.map do |seat|
        FilledRow.new(
          seat: seat,
          person: filler_person(seat),
          teammate: filler_teammate(seat)
        )
      end
    end

    def filler_person(seat)
      filler_teammate(seat)&.person
    end

    def filler_teammate(seat)
      seat.employment_tenures.find { |tenure| tenure.ended_at.nil? }&.teammate
    end

    def prune_forest(nodes, keep_ids)
      nodes.filter_map { |node| prune_node(node, keep_ids) }
    end

    def prune_node(node, keep_ids)
      children = prune_forest(node[:children] || [], keep_ids)
      keep = keep_ids.include?(node[:seat].id) || children.any?
      return nil unless keep

      {
        seat: node[:seat],
        children: children,
        direct_reports_count: children.length,
        total_reports_count: children.length + children.sum { |child| child[:total_reports_count] || 0 }
      }
    end

    def node_id(seat_id)
      "seat_#{seat_id}"
    end

    def seat_url(seat)
      Rails.application.routes.url_helpers.organization_seat_path(@organization, seat)
    end
  end
end
