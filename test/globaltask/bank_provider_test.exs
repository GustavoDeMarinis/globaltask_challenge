defmodule Globaltask.BankProviderTest do
  use Globaltask.DataCase, async: true

  alias Globaltask.BankProvider
  alias Globaltask.CreditApplications.CreditApplication

  describe "resolve/1" do
    test "returns ok and module for supported countries" do
      assert {:ok, BankProvider.ES} = BankProvider.resolve("ES")
      assert {:ok, BankProvider.PT} = BankProvider.resolve("PT")
      assert {:ok, BankProvider.IT} = BankProvider.resolve("IT")
      assert {:ok, BankProvider.MX} = BankProvider.resolve("MX")
      assert {:ok, BankProvider.CO} = BankProvider.resolve("CO")
      assert {:ok, BankProvider.BR} = BankProvider.resolve("BR")
    end

    test "returns error for unsupported country" do
      assert {:error, :unsupported_country} = BankProvider.resolve("XX")
      assert {:error, :unsupported_country} = BankProvider.resolve("AR")
    end
  end

  describe "fetch/1" do
    test "fetches data for a valid application using the correct adapter" do
      app = %CreditApplication{country: "ES", document_number: "12345678Z"}

      assert {:ok, payload} = BankProvider.fetch(app)
      assert is_integer(payload.credit_score)
      assert is_boolean(payload.annual_income_verified)
    end

    test "returns error if country is unsupported" do
      app = %CreditApplication{country: "US", document_number: "123"}
      assert {:error, :unsupported_country} = BankProvider.fetch(app)
    end
  end
end
