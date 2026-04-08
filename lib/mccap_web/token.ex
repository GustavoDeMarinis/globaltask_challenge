defmodule MccapWeb.Token do
  @moduledoc """
  Generates and verifies JWT tokens for the application.
  Uses a static default secret for the MVP to allow easy testing.
  """
  use Joken.Config

  @impl Joken.Config
  def token_config do
    default_claims(default_exp: 24 * 60 * 60) # 1 day expiration
  end

  def sign!(claims) do
    signer = Joken.Signer.create("HS256", secret())
    {:ok, token, _claims} = generate_and_sign(claims, signer)
    token
  end

  def verify!(token) do
    signer = Joken.Signer.create("HS256", secret())
    verify_and_validate(token, signer)
  end

  defp secret do
    Application.get_env(:mccap, MccapWeb.Token, [])[:secret] || "super_secret_key_for_mvp"
  end
end
