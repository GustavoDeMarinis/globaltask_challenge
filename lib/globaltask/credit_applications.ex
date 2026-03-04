defmodule Globaltask.CreditApplications do
  @moduledoc """
  Context for managing credit applications.

  Provides CRUD operations with pagination, filtering, and status transitions.
  """

  import Ecto.Query

  alias Globaltask.Repo
  alias Globaltask.CreditApplications.CreditApplication

  @doc """
  Creates a new credit application.

  Status always defaults to `"created"` regardless of input.

  ## Examples

      iex> create_application(%{country: "ES", full_name: "Juan", ...})
      {:ok, %CreditApplication{status: "created"}}

      iex> create_application(%{country: "INVALID"})
      {:error, %Ecto.Changeset{}}
  """
  @spec create_application(map()) :: {:ok, %CreditApplication{}} | {:error, Ecto.Changeset.t()}
  def create_application(attrs) do
    %CreditApplication{}
    |> CreditApplication.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Fetches a credit application by ID.

  Returns `{:error, :not_found}` for invalid UUIDs or missing records.

  ## Examples

      iex> get_application("valid-uuid")
      {:ok, %CreditApplication{}}

      iex> get_application("not-a-uuid")
      {:error, :not_found}
  """
  @spec get_application(String.t()) :: {:ok, %CreditApplication{}} | {:error, :not_found}
  def get_application(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        case Repo.get(CreditApplication, uuid) do
          nil -> {:error, :not_found}
          app -> {:ok, app}
        end

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Lists credit applications with pagination and optional filters.

  ## Supported filters

  - `"country"` — filter by country code (e.g. `"ES"`)
  - `"status"` — filter by status (e.g. `"created"`)
  - `"date_from"` — filter `inserted_at >= date` (ISO 8601 date string)
  - `"date_to"` — filter `inserted_at <= date` (ISO 8601 date string, end of day)
  - `"page"` — page number (default 1)
  - `"page_size"` — records per page (default 20, max 100)

  ## Returns

      %{data: [%CreditApplication{}, ...], page: 1, page_size: 20, total: 42}
  """
  @spec list_applications(map()) :: %{
          data: [%CreditApplication{}],
          page: pos_integer(),
          page_size: pos_integer(),
          total: non_neg_integer()
        }
  def list_applications(filters \\ %{}) do
    CreditApplication
    |> filter_by_country(filters)
    |> filter_by_status(filters)
    |> filter_by_date_range(filters)
    |> order_by([c], desc: c.inserted_at)
    |> Globaltask.Pagination.paginate(Repo, filters)
  end

  @doc """
  Updates an existing credit application's fields.

  Does NOT allow changing `status` or `country`. Uses optimistic locking.

  ## Examples

      iex> update_application(app, %{"requested_amount" => "20000"})
      {:ok, %CreditApplication{requested_amount: #Decimal<20000>}}

      iex> update_application(app, %{"requested_amount" => "-1"})
      {:error, %Ecto.Changeset{}}
  """
  @spec update_application(%CreditApplication{}, map()) ::
          {:ok, %CreditApplication{}} | {:error, Ecto.Changeset.t() | :stale}
  def update_application(%CreditApplication{} = app, attrs) do
    app
    |> CreditApplication.update_changeset(attrs)
    |> Repo.update()
  rescue
    Ecto.StaleEntryError ->
      {:error, :stale}
  end

  @doc """
  Updates the status of a credit application.

  Validates that the transition is allowed by the state machine.
  Uses optimistic locking to prevent race conditions.

  After a successful update, calls `on_status_change/2` on the country's
  rules module, allowing country-specific side-effects on transitions
  (e.g. re-validation before approval, audit logging).

  ## Examples

      iex> update_status(app, "pending_review")  # from "created"
      {:ok, %CreditApplication{status: "pending_review"}}

      iex> update_status(app, "approved")  # from "created" — invalid
      {:error, %Ecto.Changeset{}}
  """
  @spec update_status(%CreditApplication{}, String.t()) ::
          {:ok, %CreditApplication{}} | {:error, Ecto.Changeset.t() | :stale | term()}
  def update_status(%CreditApplication{} = app, new_status) do
    with {:ok, updated_app} <- do_update_status(app, new_status),
         :ok <- notify_country_hook(updated_app, new_status) do
      {:ok, updated_app}
    end
  rescue
    Ecto.StaleEntryError ->
      {:error, :stale}
  end

  defp do_update_status(app, new_status) do
    app
    |> CreditApplication.update_status_changeset(%{status: new_status})
    |> Repo.update()
  end

  defp notify_country_hook(app, new_status) do
    case Globaltask.CountryRules.resolve(app.country) do
      {:ok, module} -> module.on_status_change(app, new_status)
      {:error, _} -> :ok
    end
  end

  # -- Private filters --

  defp filter_by_country(query, %{"country" => country}) when is_binary(country) do
    where(query, [c], c.country == ^country)
  end

  defp filter_by_country(query, _filters), do: query

  defp filter_by_status(query, %{"status" => status}) when is_binary(status) do
    where(query, [c], c.status == ^status)
  end

  defp filter_by_status(query, _filters), do: query

  defp filter_by_date_range(query, filters) do
    query
    |> maybe_filter_date_from(filters["date_from"])
    |> maybe_filter_date_to(filters["date_to"])
  end

  defp maybe_filter_date_from(query, nil), do: query

  defp maybe_filter_date_from(query, date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        where(query, [c], c.inserted_at >= ^datetime)

      {:error, _reason} ->
        query
    end
  end

  defp maybe_filter_date_to(query, nil), do: query

  defp maybe_filter_date_to(query, date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        datetime = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
        where(query, [c], c.inserted_at <= ^datetime)

      {:error, _reason} ->
        query
    end
  end
end
