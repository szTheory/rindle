defmodule Rindle.InstallSmoke.PlugCryptoPrivacyTest do
  use ExUnit.Case, async: true

  test "malformed token API arguments never expose the secret in formatted errors" do
    secret = String.duplicate("synthetic-crypto-secret/", 4)

    for function <- [:sign, :encrypt, :verify, :decrypt],
        {key, salt, options} <- [
          {secret, :invalid_salt, []},
          {secret, "salt", :invalid_options},
          {String.to_charlist(secret), "salt", []}
        ] do
      result =
        try do
          {:returned, apply(Plug.Crypto, function, [key, salt, "payload", options])}
        rescue
          error -> {:raised, Exception.format(:error, error, __STACKTRACE__)}
        end

      assert {:raised, message} = result
      refute message =~ secret
    end
  end
end
