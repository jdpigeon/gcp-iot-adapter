defmodule OauthJwt.Spec.CommonSpec do
  use ESpec

  context "Check if on GCE instance via metadata server" do
    describe "returns true if correct headers returned" do
      before do: allow HTTPoison |> to(accept :get, fn(_url, _headers) -> {:ok, %HTTPoison.Response{status_code: 200, headers: [{"Metadata-Flavor", "Google"}]}} end)

      it do: expect OauthJwt.Common.on_gce? |> to(be_true)
    end

    describe "returns false if metadata server return wrong headers" do
      before do: allow HTTPoison |> to(accept :get, fn(_url, _headers) -> {:ok, %HTTPoison.Response{status_code: 200}} end)

      it do: expect OauthJwt.Common.on_gce? |> to(be_false)
    end

    describe "returns false if metadata server unreachable" do
      before do: allow HTTPoison |> to(accept :get, fn(_url, _headers) -> {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}} end)
      it do: expect OauthJwt.Common.on_gce? |> to(be_false)
    end

  end

  context "get secrets filepath" do
    describe "returns contents from file defined in GOOGLE_APPLICATION_CREDENTIALS if available" do
    before do: allow OauthJwt.Common |> to(accept :get_env, fn("GOOGLE_APPLICATION_CREDENTIALS") -> {:ok, "test_client_secrets.json"} end)

    it do: expect OauthJwt.Common.get_secrets_filepath |> to(eq "test_client_secrets.json")
    end

    describe "returns contents from file specified in configuration if GOOGLE_APPLICATION_CREDENTIALS undefined" do
    before do: allow OauthJwt.Common |> to(accept :get_env, fn("GOOGLE_APPLICATION_CREDENTIALS") -> {:error, nil} end)

    it do: expect OauthJwt.Common.get_secrets_filepath |> to(eq "client_secrets.json")
    end
  end

  context "secrets configuration" do
    describe "is loaded file from environment variable if possible" do
      before do: allow OauthJwt.Common |> to(accept :get_env, fn("GOOGLE_APPLICATION_CREDENTIALS") -> {:ok, "test_client_secrets.json"} end)
      before do: allow OauthJwt.Common |> to(accept :load_secrets, fn("test_client_secrets.json") -> {:ok, :google_application_credentials} end)

      it do: expect OauthJwt.Common.try_load_secrets() |> to(eq {:ok, :google_application_credentials})
    end

    describe "is loaded file from application config variable otherwise" do
      before do: allow OauthJwt.Common |> to(accept :get_env, fn("GOOGLE_APPLICATION_CREDENTIALS") -> {:error, nil} end)
      before do: allow OauthJwt.Common |> to(accept :load_secrets, fn("client_secrets.json") -> {:ok, :default_secrets_file} end)

      it do: expect OauthJwt.Common.try_load_secrets() |> to(eq {:ok, :default_secrets_file})
    end

  end

  context "secrets file loader" do
    describe "loads file correctly" do
      let :secrets, do:  OauthJwt.Common.load_secrets("spec/test_client_secrets.json")
      it do
         {:ok, secret} = secrets
         expect secret["private_key"] |> to(eq "private-key-here")
      end
    end

    describe "returns error if file does not exist" do
      let :secrets, do:  OauthJwt.Common.load_secrets("spec/non-existent-file.json")
      it do
         expect secrets |> to(eq {:error, :enoent})
      end
    end

    describe "returns error if client secrets file is malformed" do
      let :secrets, do:  OauthJwt.Common.load_secrets("spec/test_client_secrets_malformed.json")
      it do
         {status, _} = secrets
         expect status |> to(eq :error)
      end
    end
  end

  context "get_env System.get_env wrapper" do
    describe "returns {:ok, value} if var is defined" do
      before do: allow System |> to(accept :get_env, fn("GOOGLE_APPLICATION_CREDENTIALS") -> "test_client_secrets.json" end)
      it do: expect OauthJwt.Common.get_env("GOOGLE_APPLICATION_CREDENTIALS") |> to(eq {:ok, "test_client_secrets.json"})
    end

    describe "returns {:error, nil} if var is not defined" do
      before do: allow System |> to(accept :get_env, fn("GOOGLE_APPLICATION_CREDENTIALS") -> nil end)
      it do: expect OauthJwt.Common.get_env("GOOGLE_APPLICATION_CREDENTIALS") |> to(eq {:error, nil})
    end
  end

end
