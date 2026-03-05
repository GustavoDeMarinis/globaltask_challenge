defmodule Globaltask.BankProvider.IT do
  @moduledoc """
  Bank provider adapter for Italy (IT).

  Simulates a financial stability assessment API.

  ## Response shape

      %{
        financial_stability: "stable" | "moderate" | "at_risk",
        employer_verified: boolean()
      }
  """

  use Globaltask.BankProvider

  @stability_levels ~w(stable moderate at_risk)

  @impl true
  @spec fetch_client_data(%Globaltask.CreditApplications.CreditApplication{}) ::
          Globaltask.BankProvider.provider_result()
  def fetch_client_data(%{document_number: doc_number}) do
    simulate_latency()

    hash = :erlang.phash2(doc_number)

    {:ok,
     %{
       financial_stability: Enum.at(@stability_levels, rem(hash, 3)),
       employer_verified: rem(hash, 2) == 0
     }}
  end
end
