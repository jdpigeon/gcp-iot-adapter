ESpec.configure fn(config) ->
  config.before fn ->
    api = GoogleApi.CodeGen.read_api_file()
    {:shared, api: api}
  end

  config.finally fn(_shared) ->
    :ok
  end
end
