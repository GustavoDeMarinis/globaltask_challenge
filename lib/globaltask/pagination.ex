defmodule Globaltask.Pagination do
  @moduledoc """
  Generic pagination helper for Ecto queries.

  Extracts page/page_size parsing, offset calculation, and result wrapping
  so that contexts only deal with domain logic.
  """

  import Ecto.Query

  alias Globaltask.Repo

  @default_page_size 20
  @max_page_size 100

  @doc """
  Paginates an Ecto query and returns a standardized result map.

  ## Options (from `params` map)

  - `"page"` — page number (default 1, must be > 0)
  - `"page_size"` — records per page (default 20, capped at 100)

  ## Returns

      %{data: [%Schema{}, ...], page: 1, page_size: 20, total: 42}
  """
  def paginate(query, params \\ %{}) do
    page = parse_positive_integer(params["page"], 1)
    page_size = params["page_size"] |> parse_positive_integer(@default_page_size) |> min(@max_page_size)
    offset = (page - 1) * page_size

    total = Repo.aggregate(query, :count)
    data = query |> limit(^page_size) |> offset(^offset) |> Repo.all()

    %{data: data, page: page, page_size: page_size, total: total}
  end

  defp parse_positive_integer(nil, default), do: default

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp parse_positive_integer(_value, default), do: default
end
