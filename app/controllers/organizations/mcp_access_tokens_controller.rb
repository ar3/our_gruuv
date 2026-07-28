# frozen_string_literal: true

module Organizations
  # Create/revoke personal MCP access tokens for Claude Desktop (etc.).
  # Tokens bind to the current company teammate; MCP tools run as that identity.
  class McpAccessTokensController < OrganizationNamespaceBaseController
    before_action :authenticate_person!
    after_action :verify_authorized

    def index
      authorize McpAccessToken
      @tokens = current_person.mcp_access_tokens
        .where(company_teammate: current_company_teammate)
        .order(created_at: :desc)
      @new_token = McpAccessToken.new(name: "Claude Desktop")
      @raw_token = flash[:mcp_raw_token]
    end

    def create
      authorize McpAccessToken
      record, raw = McpAccessToken.issue!(
        person: current_person,
        company_teammate: current_company_teammate,
        name: token_params[:name]
      )
      flash[:mcp_raw_token] = raw
      redirect_to organization_mcp_access_tokens_path(@organization),
                  notice: "MCP token “#{record.name}” created. Copy it now — it won’t be shown again."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to organization_mcp_access_tokens_path(@organization),
                  alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      token = current_person.mcp_access_tokens
        .where(company_teammate: current_company_teammate)
        .find(params[:id])
      authorize token
      token.revoke!
      redirect_to organization_mcp_access_tokens_path(@organization), notice: "Token revoked."
    end

    private

    def token_params
      params.require(:mcp_access_token).permit(:name)
    end
  end
end
