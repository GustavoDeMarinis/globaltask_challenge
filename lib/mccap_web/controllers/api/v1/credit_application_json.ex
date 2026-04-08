defmodule MccapWeb.API.V1.CreditApplicationJSON do
  @moduledoc """
  JSON serialization for credit applications.

  `provider_payload` is intentionally excluded from responses
  to avoid exposing potentially sensitive bank data (§4.2).
  """

  alias Mccap.CreditApplications.CreditApplication

  def index(%{result: %{data: data, page: page, page_size: page_size, total: total}, role: role}) do
    %{
      data: Enum.map(data, &data(&1, role)),
      meta: %{
        page: page,
        page_size: page_size,
        total: total
      }
    }
  end

  def show(%{credit_application: app, role: role}) do
    %{data: data(app, role)}
  end

  def data(%CreditApplication{} = app, role) do
    base = %{
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

    if role == "admin" do
      Map.put(base, :provider_payload, app.provider_payload)
    else
      base
    end
  end
end
