class Organizations::KudosRewards::TransactionsController < Organizations::KudosRewards::BaseController
  def index
    authorize :kudos, :view_transactions?

    @ledger = current_company_teammate.kudos_ledger
    transactions_scope = current_company_teammate.kudos_transactions.recent
    total_count = transactions_scope.count
    @pagy = Pagy.new(count: total_count, page: params[:page] || 1, items: 25)
    @transactions = transactions_scope.limit(@pagy.items).offset(@pagy.offset)
  end
end
