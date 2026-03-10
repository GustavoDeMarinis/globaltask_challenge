defmodule Globaltask.BankProvider.ES do
  @moduledoc """
  Bank provider adapter for Spain (ES).

  Simulates a credit bureau API that returns a credit score and income
  verification flag. In production this would call an external HTTP endpoint.

  ## Response shape

      %{
        credit_score: 400..850,
        annual_income_verified: boolean()
      }
  """

  use Globaltask.BankProvider

  @impl true
  @spec fetch_client_data(%Globaltask.CreditApplications.CreditApplication{}) ::
          Globaltask.BankProvider.provider_result()
  def fetch_client_data(%{document_number: doc_number}) do
    simulate_latency()

    hash = :erlang.phash2(doc_number)

    {:ok,
     %{
       credit_score: rem(hash, 451) + 400,
       annual_income_verified: rem(hash, 2) == 0
     }}
  end
end
