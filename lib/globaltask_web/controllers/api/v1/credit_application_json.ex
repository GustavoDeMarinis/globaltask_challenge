defmodule GlobaltaskWeb.API.V1.CreditApplicationJSON do
  @moduledoc """
  JSON serialization for credit applications.

  `provider_payload` is intentionally excluded from responses
  to avoid exposing potentially sensitive bank data (§4.2).
  """

  alias Globaltask.CreditApplications.CreditApplication

  def index(%{result: %{data: data, page: page, page_size: page_size, total: total}}) do
    %{
      data: Enum.map(data, &data/1),
      meta: %{
        page: page,
        page_size: page_size,
        total: total
      }
    }
  end

  def show(%{credit_application: app}) do
    %{data: data(app)}
  end

  def data(%CreditApplication{} = app) do
    %{
      id: app.id,
      country: app.country,
      full_name: app.full_name,
      document_type: app.document_type,
      document_number: app.document_number,
      requested_amount: app.requested_amount,
      monthly_income: app.monthly_income,
      application_date: app.application_date,
      status: app.status,
      inserted_at: app.inserted_at,
      updated_at: app.updated_at
    }
  end
end
