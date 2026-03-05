defmodule Globaltask.BankProvider.PT do
  @moduledoc """
  Bank provider adapter for Portugal (PT).

  Simulates a risk classification API returning a risk class and debt ratio.

  ## Response shape

      %{
        risk_class: "A" | "B" | "C",
        debt_ratio: float()
      }
  """

  use Globaltask.BankProvider

  @risk_classes ~w(A B C)

  @impl true
  @spec fetch_client_data(%Globaltask.CreditApplications.CreditApplication{}) ::
          Globaltask.BankProvider.provider_result()
  def fetch_client_data(%{document_number: doc_number}) do
    simulate_latency()

    hash = :erlang.phash2(doc_number)

    {:ok,
     %{
       risk_class: Enum.at(@risk_classes, rem(hash, 3)),
       debt_ratio: Float.round(rem(hash, 70) / 100, 2)
     }}
  end
end
