defmodule Mccap.BankProvider.BR do
  @moduledoc """
  Bank provider adapter for Brazil (BR).

  Simulates a Serasa Experian API returning a credit score, CPF status,
  and open credit count. The `serasa_score` is used by
  `CountryRules.BR.evaluate_risk/1` for threshold-based risk decisions.

  ## Response shape

      %{
        serasa_score: 300..1000,
        cpf_status: "regular" | "irregular",
        open_credits: non_neg_integer()
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
       serasa_score: rem(hash, 701) + 300,
       cpf_status: if(rem(hash, 5) == 0, do: "irregular", else: "regular"),
       open_credits: rem(hash, 8)
     }}
  end
end
