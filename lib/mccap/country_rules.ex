defmodule Mccap.CountryRules do
  @moduledoc """
  Behaviour and dispatcher for country-specific validation rules.

  Each country module (e.g. `Mccap.CountryRules.ES`) implements three
  callbacks that plug into the changeset validation pipeline:

  - `required_document_type/0` — the document type string expected for that country
  - `validate_document/1` — format + checksum validation on `:document_number`
  - `validate_business_rules/1` — country-specific business logic (income ratios,
    thresholds, etc.)

  ## `__using__/1` macro

  Country modules should `use Mccap.CountryRules` to get the behaviour
  annotation and a default no-op `on_status_change/2` that can be overridden:

      defmodule Mccap.CountryRules.XX do
        use Mccap.CountryRules

        @impl true
        def required_document_type, do: "XID"

        @impl true
        def validate_document(changeset), do: changeset

        @impl true
        def validate_business_rules(changeset), do: changeset
      end

  ## Status override pattern (ES)

  The ES module uses `Ecto.Changeset.force_change/3` to set `:status` to
  `"pending_review"` when `requested_amount > 50_000`. This is a conscious
  design choice: `create_changeset/2` excludes `:status` from cast fields
  to prevent arbitrary status injection, but `force_change` bypasses that
  guard intentionally for this flag-for-review case. The trade-off is
  acceptable because it's scoped to a single country rule and covered by
  a dedicated test.
  """

  import Ecto.Changeset

  @type changeset :: Ecto.Changeset.t()

  @doc "Returns the expected document type string for this country (e.g. `\"DNI\"`)."
  @callback required_document_type() :: String.t()

  @doc "Validates the `:document_number` field format. Returns the changeset with errors if invalid."
  @callback validate_document(changeset()) :: changeset()

  @doc "Applies country-specific business rules. Returns the changeset with errors or flags."
  @callback validate_business_rules(changeset()) :: changeset()

  @doc """
  Hook called during status transitions. Override in country modules
  to add logic on state changes (e.g. re-validate before approval).

  Default implementation is a no-op returning `:ok`.
  """
  @callback on_status_change(app :: map(), new_status :: String.t()) :: :ok | {:error, term()}

  @doc """
  Evaluates risk based on bank provider data stored in `provider_payload`.

  Called by `RiskEvaluationWorker` after provider data is fetched.
  Returns an atom instructing the worker what status transition to apply.

  Default implementation returns `:skip` (no provider-based rules).
  Override in country modules to add threshold-based decisions.
  """
  @callback evaluate_risk(app :: %Mccap.CreditApplications.CreditApplication{}) ::
              :approve | :reject | :review | :skip

  defmacro __using__(_opts) do
    quote do
      @behaviour Mccap.CountryRules

      @impl Mccap.CountryRules
      def on_status_change(_app, _new_status), do: :ok

      @impl Mccap.CountryRules
      def evaluate_risk(_app), do: :skip

      defoverridable on_status_change: 2, evaluate_risk: 1
    end
  end

  @country_modules %{
    "ES" => Mccap.CountryRules.ES,
    "PT" => Mccap.CountryRules.PT,
    "IT" => Mccap.CountryRules.IT,
    "MX" => Mccap.CountryRules.MX,
    "CO" => Mccap.CountryRules.CO,
    "BR" => Mccap.CountryRules.BR
  }

  @doc """
  Resolves a country code string to its rules module.

  ## Examples

      iex> Mccap.CountryRules.resolve("ES")
      {:ok, Mccap.CountryRules.ES}

      iex> Mccap.CountryRules.resolve("XX")
      {:error, :unsupported_country}
  """
  @spec resolve(String.t()) :: {:ok, module()} | {:error, :unsupported_country}
  def resolve(country) when is_binary(country) do
    case Map.fetch(@country_modules, country) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :unsupported_country}
    end
  end

  @doc """
  Convenience function that resolves the country from the changeset and runs
  all validations in order:

  1. Verifies `document_type` matches the country's `required_document_type()`
  2. Calls `validate_document/1`
  3. Calls `validate_business_rules/1`

  Resolves country via `get_change(changeset, :country)` (create flow) or
  `changeset.data.country` (update flow, where country is immutable).

  If the country is unsupported, adds an error on `:country`.
  """
  @spec validate(changeset()) :: changeset()
  def validate(%Ecto.Changeset{} = changeset) do
    country = get_change(changeset, :country) || changeset.data.country

    case country do
      nil ->
        add_error(changeset, :country, "country is required")

      country ->
        case resolve(country) do
          {:ok, module} ->
            changeset
            |> validate_document_type(module)
            |> module.validate_document()
            |> module.validate_business_rules()

          {:error, :unsupported_country} ->
            add_error(changeset, :country, "unsupported country: %{country}", country: country)
        end
    end
  end

  @doc false
  @spec validate_document_type(changeset(), module()) :: changeset()
  defp validate_document_type(changeset, module) do
    expected = module.required_document_type()
    actual = get_field(changeset, :document_type)

    if actual == expected do
      changeset
    else
      add_error(changeset, :document_type, "must be %{expected} for this country",
        expected: expected,
        actual: to_string(actual || "nil")
      )
    end
  end
end
