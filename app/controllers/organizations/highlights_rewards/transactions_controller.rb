class Organizations::HighlightsRewards::TransactionsController < Organizations::HighlightsRewards::BaseController
  def index
    authorize :highlights, :view_transactions?

    @ledger = current_company_teammate.highlights_ledger
    transactions_scope = current_company_teammate.highlights_transactions.recent
    total_count = transactions_scope.count
    @pagy = Pagy.new(count: total_count, page: params[:page] || 1, items: 25)
    @transactions = transactions_scope.limit(@pagy.items).offset(@pagy.offset)
  end
end
