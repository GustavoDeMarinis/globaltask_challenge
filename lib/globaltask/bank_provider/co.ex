defmodule Globaltask.BankProvider.CO do
  @moduledoc """
  Bank provider adapter for Colombia (CO).

  Simulates a centrales de riesgo API returning debt and obligation data.
  The `total_debt` and `monthly_obligations` values are used by
  `CountryRules.CO.evaluate_risk/1` to calculate debt-to-income ratios.

  ## Response shape

      %{
        total_debt: Decimal.t(),
        monthly_obligations: Decimal.t(),
        credit_history_months: non_neg_integer()
      }
  """

  use Globaltask.BankProvider

  @impl true
  @spec fetch_client_data(%Globaltask.CreditApplications.CreditApplication{}) ::
          Globaltask.BankProvider.provider_result()
  def fetch_client_data(%{document_number: doc_number, monthly_income: income}) do
    simulate_latency()

    hash = :erlang.phash2(doc_number)

    # Derive total_debt as a fraction of monthly_income (0.1x to 0.6x)
    debt_multiplier = Decimal.div(Decimal.new(rem(hash, 50) + 10), Decimal.new(100))

    total_debt =
      income
      |> Decimal.mult(debt_multiplier)
      |> Decimal.round(2)

    monthly_obligations =
      total_debt
      |> Decimal.div(Decimal.new(12))
      |> Decimal.round(2)

    {:ok,
     %{
       total_debt: total_debt,
       monthly_obligations: monthly_obligations,
       credit_history_months: rem(hash, 120) + 6
     }}
  end
end
