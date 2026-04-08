defmodule MccapWeb.ChangesetJSON do
  @moduledoc """
  Renders changeset errors as JSON.

  Produces a consistent `%{errors: %{field => [messages]}}` format
  used by the FallbackController for 422 responses.
  """

  def error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
