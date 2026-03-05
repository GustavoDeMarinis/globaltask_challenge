defmodule Globaltask.CountryRulesTest do
  use Globaltask.DataCase, async: true

  alias Globaltask.CountryRules
  alias Globaltask.CreditApplications.CreditApplication

  # -- resolve/1 --

  describe "resolve/1" do
    test "returns {:ok, module} for each supported country" do
      assert {:ok, Globaltask.CountryRules.ES} = CountryRules.resolve("ES")
      assert {:ok, Globaltask.CountryRules.PT} = CountryRules.resolve("PT")
      assert {:ok, Globaltask.CountryRules.IT} = CountryRules.resolve("IT")
      assert {:ok, Globaltask.CountryRules.MX} = CountryRules.resolve("MX")
      assert {:ok, Globaltask.CountryRules.CO} = CountryRules.resolve("CO")
      assert {:ok, Globaltask.CountryRules.BR} = CountryRules.resolve("BR")
    end

    test "returns {:error, :unsupported_country} for unknown country code" do
      assert {:error, :unsupported_country} = CountryRules.resolve("XX")
    end

    test "returns {:error, :unsupported_country} for empty string" do
      assert {:error, :unsupported_country} = CountryRules.resolve("")
    end
  end

  # -- validate/1 --

  describe "validate/1" do
    test "adds error on :document_type when it does not match country's required type" do
      # ES expects "DNI", we send "CPF"
      changeset =
        %CreditApplication{}
        |> Ecto.Changeset.change(%{
          country: "ES",
          full_name: "Test User",
          document_type: "CPF",
          document_number: "12345678Z",
          requested_amount: Decimal.new("10000"),
          monthly_income: Decimal.new("3000"),
          application_date: ~D[2026-03-04]
        })
        |> CountryRules.validate()

      assert %{document_type: [msg]} = errors_on(changeset)
      assert msg =~ "must be DNI"
    end

    test "adds error on :country for unsupported country code" do
      # Build a changeset manually with an unsupported country that bypasses
      # the inclusion validation — simulating a future scenario
      changeset =
        %CreditApplication{}
        |> Ecto.Changeset.change(%{country: "XX"})
        |> CountryRules.validate()

      assert %{country: [msg]} = errors_on(changeset)
      assert msg =~ "unsupported country"
    end

    test "resolves country from data (update flow) when no country change present" do
      # Simulate an update changeset where country is already persisted
      app = %CreditApplication{country: "ES", document_type: "DNI"}

      changeset =
        app
        |> Ecto.Changeset.change(%{document_type: "CPF"})
        |> CountryRules.validate()

      # Should still resolve to ES and check document_type mismatch
      assert %{document_type: [msg]} = errors_on(changeset)
      assert msg =~ "must be DNI"
    end
  end
end
