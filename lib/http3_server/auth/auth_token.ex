defmodule Http3Server.AuthToken do
  use Joken.Config

  def generate_token(params, private_key) do
    {:ok, claims} =
      generate_claims(params)

    encode_and_sign(claims, private_signer(private_key))
    |> case do
      {:ok, jwt, _claims} ->
        {:ok, jwt}

      error ->
        error
    end
  end

  def verify_token(jwt, public_key) do
    verify_and_validate(jwt, public_signer(public_key))
  end

  defp private_signer(private_key) do
    Joken.Signer.create("RS256", %{
      "pem" => private_key
    })
  end

  defp public_signer(public_key) when is_binary(public_key) do
    Joken.Signer.create("RS256", %{
      "pem" => public_key
    })
  end
end
