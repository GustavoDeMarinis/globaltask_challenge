defmodule Mccap.BankProvider.MX do
  @moduledoc """
  Bank provider adapter for Mexico (MX).

  Simulates a Buró de Crédito API returning a score and active credit count.

  ## Response shape

      %{
        buro_score: 400..800,
        active_credits: 0..5
      }
  """

  use Mccap.BankProvider

  @impl true
  @spec fetch_client_data(%Mccap.CreditApplications.CreditApplication{}) ::
          Mccap.BankProvider.provider_result()
  def fetch_client_data(%{document_number: doc_number}) do
    simulate_latency()

    hash = :erlang.phash2(doc_number)

    {:ok,
     %{
       buro_score: rem(hash, 401) + 400,
       active_credits: rem(hash, 6)
     }}
  end
end
