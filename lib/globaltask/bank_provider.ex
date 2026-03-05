defmodule Globaltask.BankProvider do
  @moduledoc """
  Behaviour and dispatcher for per-country bank provider integrations.

  Each country module (e.g. `Globaltask.BankProvider.ES`) implements the
  `fetch_client_data/1` callback, returning structured financial data that
  feeds into the risk evaluation pipeline.

  ## Pattern

  Mirrors the `Globaltask.CountryRules` strategy pattern:

  - `resolve/1` maps a country code string to its provider module
  - `fetch/1` is a convenience that resolves the adapter and calls it
  - Country modules `use Globaltask.BankProvider` for the behaviour annotation

  ## Mock implementation

  Current adapters return deterministic mock data derived from
  `:erlang.phash2(document_number)`. In production, each adapter would
  make HTTP calls to the corresponding bank API. Swapping is transparent
  because callers depend only on the `{:ok, map()} | {:error, term()}`
  contract.

  Simulated latency can be disabled in tests via the
  `:skip_provider_latency` application env flag.
  """

  alias Globaltask.CreditApplications.CreditApplication

  @type provider_result :: {:ok, map()} | {:error, term()}

  @doc """
  Fetches client financial data from the country's bank provider.

  Receives a full `%CreditApplication{}` struct so the adapter has access
  to `document_number`, `country`, `monthly_income`, and any other fields
  it needs to build the request.

  Returns `{:ok, payload}` with a map of provider-specific data, or
  `{:error, reason}` on failure.
  """
  @callback fetch_client_data(app :: %CreditApplication{}) :: provider_result()

  defmacro __using__(_opts) do
    quote do
      @behaviour Globaltask.BankProvider

      @doc false
      defp simulate_latency do
        unless Application.get_env(:globaltask, :skip_provider_latency, false) do
          Process.sleep(Enum.random(100..500))
        end
      end
    end
  end

  @provider_modules %{
    "ES" => Globaltask.BankProvider.ES,
    "PT" => Globaltask.BankProvider.PT,
    "IT" => Globaltask.BankProvider.IT,
    "MX" => Globaltask.BankProvider.MX,
    "CO" => Globaltask.BankProvider.CO,
    "BR" => Globaltask.BankProvider.BR
  }

  @doc """
  Resolves a country code string to its bank provider module.

  ## Examples

      iex> Globaltask.BankProvider.resolve("ES")
      {:ok, Globaltask.BankProvider.ES}

      iex> Globaltask.BankProvider.resolve("XX")
      {:error, :unsupported_country}
  """
  @spec resolve(String.t()) :: {:ok, module()} | {:error, :unsupported_country}
  def resolve(country) when is_binary(country) do
    case Map.fetch(@provider_modules, country) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :unsupported_country}
    end
  end

  @doc """
  Convenience function: resolves the provider from the application's country
  and calls `fetch_client_data/1`.

  ## Examples

      iex> Globaltask.BankProvider.fetch(app)
      {:ok, %{credit_score: 720, annual_income_verified: true}}

      iex> Globaltask.BankProvider.fetch(%{country: "XX"})
      {:error, :unsupported_country}
  """
  @spec fetch(%CreditApplication{}) :: provider_result()
  def fetch(%CreditApplication{country: country} = app) do
    case resolve(country) do
      {:ok, module} -> module.fetch_client_data(app)
      {:error, _} = error -> error
    end
  end
end
