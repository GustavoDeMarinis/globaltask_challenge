defmodule Globaltask.BankProvider.AdaptersTest do
  use Globaltask.DataCase, async: true

  # Test deterministic property and shape for all adapters

  describe "ES Adapter" do
    test "returns deterministic credit_score and annual_income_verified" do
      doc = %{document_number: "12345678Z"}
      {:ok, result1} = Globaltask.BankProvider.ES.fetch_client_data(doc)
      {:ok, result2} = Globaltask.BankProvider.ES.fetch_client_data(doc)

      assert result1 == result2
      assert Map.has_key?(result1, :credit_score)
      assert Map.has_key?(result1, :annual_income_verified)
      assert result1.credit_score in 600..850
      assert is_boolean(result1.annual_income_verified)
    end
  end

  describe "PT Adapter" do
    test "returns deterministic risk_class and debt_ratio" do
      doc = %{document_number: "123456789"}
      {:ok, result1} = Globaltask.BankProvider.PT.fetch_client_data(doc)
      {:ok, result2} = Globaltask.BankProvider.PT.fetch_client_data(doc)

      assert result1 == result2
      assert result1.risk_class in ["A", "B", "C"]
      assert is_float(result1.debt_ratio)
      assert result1.debt_ratio >= 0.0 and result1.debt_ratio <= 1.0
    end
  end

  describe "IT Adapter" do
    test "returns deterministic financial_stability and employer_verified" do
      doc = %{document_number: "RSSMRA85T10A562S"}
      {:ok, result1} = Globaltask.BankProvider.IT.fetch_client_data(doc)
      {:ok, result2} = Globaltask.BankProvider.IT.fetch_client_data(doc)

      assert result1 == result2
      assert result1.financial_stability in ["stable", "moderate", "at_risk"]
      assert is_boolean(result1.employer_verified)
    end
  end

  describe "MX Adapter" do
    test "returns deterministic buro_score and active_credits" do
      doc = %{document_number: "ABCD123456HMNEF0"}
      {:ok, result1} = Globaltask.BankProvider.MX.fetch_client_data(doc)
      {:ok, result2} = Globaltask.BankProvider.MX.fetch_client_data(doc)

      assert result1 == result2
      assert result1.buro_score in 400..800
      assert is_integer(result1.active_credits)
    end
  end

  describe "CO Adapter" do
    test "returns deterministic debt properties based on income" do
      # Note: CO uses monthly_income for calculations
      doc = %{document_number: "12345678", monthly_income: Decimal.new("1000.00")}
      {:ok, result1} = Globaltask.BankProvider.CO.fetch_client_data(doc)
      {:ok, result2} = Globaltask.BankProvider.CO.fetch_client_data(doc)

      assert result1 == result2
      assert %Decimal{} = result1.total_debt
      assert %Decimal{} = result1.monthly_obligations
      assert is_integer(result1.credit_history_months)
    end
  end

  describe "BR Adapter" do
    test "returns deterministic serasa_score, cpf_status, and open_credits" do
      doc = %{document_number: "12345678909"}
      {:ok, result1} = Globaltask.BankProvider.BR.fetch_client_data(doc)
      {:ok, result2} = Globaltask.BankProvider.BR.fetch_client_data(doc)

      assert result1 == result2
      assert result1.serasa_score in 300..1000
      assert result1.cpf_status in ["regular", "irregular"]
      assert is_integer(result1.open_credits)
    end
  end
end
