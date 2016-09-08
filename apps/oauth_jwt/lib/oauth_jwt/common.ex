defmodule OauthJwt.Common do
  require Logger

  @google_metadata_server "http://metadata"
  @google_metadata_header {"Metadata-Flavor", "Google"}
  @google_metadata_access_token_url "/computeMetadata/v1/instance/service-accounts/default/token"

  def on_gce? do
    case HTTPoison.get(@google_metadata_server, [@google_metadata_header]) do
      {:ok, %{status_code: 200, headers: headers}} -> Enum.member?(headers, @google_metadata_header)
      _ -> false
    end
  end

  @doc """
  Wraps System.get_env results with {:ok, value} if
  the environment variables exists and {:error, nil} if
  the environment variable does not exist.
  """
  def get_env(var) do
    case System.get_env(var) do
      nil -> {:error, nil}
      val -> {:ok, val}
    end
  end

  def load_secrets(filepath) do
    with {:ok, contents} <- File.read(filepath) do
      Logger.debug("Contents of secrets file is:", contents)
      Poison.decode(contents)
    end
  end

  def get_secrets_filepath() do
    case OauthJwt.Common.get_env("GOOGLE_APPLICATION_CREDENTIALS") do
      {:ok, filepath} -> filepath
      {:error, _} -> Application.get_env(:oauth_jwt, :secrets_file)
    end
  end

  def try_load_secrets() do
    get_secrets_filepath |> OauthJwt.Common.load_secrets
  end

end
