defmodule GoogleApi.CodeGen do

  @api_file "pubsub-api.json"
  @http_executor OauthJwt.Client

  def read_api_file() do
    Path.join(:code.priv_dir(:google_api), @api_file) |> read_api_file
  end

  def read_api_file(path) do
    path |> File.read! |> JSX.decode!
  end

  def generate_code(api) do
    walk_resources(api, api) |> List.flatten
  end

  def create_modules(generated_code) do
    for %{module: module, code: code} <- generated_code do
      IO.puts "Creating code for #{inspect module}"
      Module.create(module, code, Macro.Env.location(__ENV__))
    end
  end

  @doc """
  Handle case where resource has both sub-resources and methods.
  """
  def walk_resources(%{"resources" => resources, "methods" => methods}, api) do
    [walk_resources(%{"methods" => methods}, api), walk_resources(%{"resources" => resources}, api)]
  end

  @doc """
  Handle case where only sub-resources are present.
  """
  def walk_resources(%{"resources" => resources}, api) do
    for r = {_name, resource} <- resources do
      walk_resources(resource, api)
    end
  end

  @doc """
  Handle case where only methods are present.
  """
  def walk_resources(%{"methods" => methods}, api) do
    codes = for method <- methods do
      create_method(method, api)
    end

    codes_by_namespace = Enum.group_by(codes, fn({namespace, _}) -> namespace end)

    for {namespace, code} <- codes_by_namespace do
      contents = for {_, quoted_code} <- code do
        quoted_code
      end
      #IO.puts Macro.to_string(Macro.expand(contents, __ENV__))
      %{module: namespace, code: contents}
    end

  end

  @doc """
  Get versioned Module namespace.
  """
  def get_versioned_module(name, id, api) do
    namespace = id |> String.slice(0..-(String.length(name)+2)) |> String.split(".") |> Enum.map(&String.capitalize/1)
    module = Module.concat(namespace)
    version = api["version"] |> String.capitalize
    module_list = [GoogleApi, version, module]

    Module.concat(module_list)
  end

  @doc """
  Create generated code to support HTTP method from Discovery document.
  """
  def create_method({name, method = %{"id" => id, "path" => path, "httpMethod" => httpMethod, "description" => description}}, api) do
    versioned_module = get_versioned_module(name, id, api)
    method_atom = String.to_atom(name)

    parameters = Map.get(method, "parameters", %{})
    path_keys = Enum.filter_map(parameters, fn {_k, v} -> v["location"] == "path" end, fn {k, _v} -> String.to_atom(k) end)

    required_parameters_keys = Enum.filter_map(parameters,
      fn({_k,v}) -> Map.get(v, "required", false) end,
      fn({k, _v}) -> k end
    )

    {required_parameters, optional_parameters} = Map.split(parameters, required_parameters_keys)

    url = api["rootUrl"] <> api["servicePath"] <> path

    httpMethod_atom = httpMethod |> String.downcase |> String.to_atom

    doc_template = ~s"""
<%= description %>

Required parameters:

<%= for param_doc <- required_param_doc do %><%= param_doc %><% end %>

Optional parameters:

<%= for param_doc <- optional_param_doc do %><%= param_doc %><% end %>

Request body:
<%= request_doc %>

Response body:

HTTP Method: <%= httpMethod %>

URL: <%= url %>
"""
    required_param_doc = Enum.map(required_parameters, &(format_parameter(&1, api, 0)))
    optional_param_doc = Enum.map(optional_parameters, &(format_parameter(&1, api, 0)))
    request_doc = case Map.get(method, "request") do
      %{"$ref" => ref} ->
        schema = get_schema_ref(api, ref)
        {ref, schema} |> format_parameter(api, 0)
      nil -> ""
    end

    doc_string = EEx.eval_string doc_template, description: description, required_param_doc: required_param_doc, optional_param_doc: optional_param_doc, httpMethod: httpMethod, url: url, request_doc: request_doc

    IO.puts doc_string

    code = quote do
      @doc unquote(doc_string)
      def unquote(method_atom)(http_executor_module, pid, parameters \\ []) do
        %{httpMethod: httpMethod, url: url, body: body, options: options} = make_request_context(unquote(method_atom), parameters)
        http_executor_module.do_request(pid, httpMethod, url, body, [], options)
      end

      def make_request_context(method = unquote(method_atom)) do
        make_request_context(method, [])
      end

      def make_request_context(unquote(method_atom), parameters) do
        {recv_timeout, parameters2} = Keyword.pop(parameters, :recv_timeout, 5_000)
        {body, parameters_url} = Keyword.pop(parameters2, :body, [])
        {parameters_path, parameters_query} = Keyword.split(parameters_url, unquote(path_keys))

        # note: no validation of parameters
        expanded_url = UriTemplate.expand(unquote(url), parameters_path)
        final_url = case parameters_query do
          [] -> expanded_url
          params -> expanded_url <> "?" <> URI.encode_query(parameters_query)
        end

        body_json = GoogleApi.Helpers.parse_as_json(body)

        %{httpMethod: unquote(httpMethod_atom), url: final_url, body: body_json, options: [recv_timeout: recv_timeout]}
        #GoogleApi.Http.do_request(unquote(httpMethod_atom), final_url, body_json, [], [recv_timeout: recv_timeout])
      end


    end

    IO.puts Macro.to_string(code)

    {versioned_module, code}
  end

  def format_parameter(param, api, indent) do
    format_parameter(param, api, indent, [])
  end

  def format_parameter(%{"$ref" => ref}, api, indent, options) do
    schema = get_schema_ref(api, ref)
    s1 = {ref, schema} |> format_parameter(api, indent+1)
    "\n" <> s1
  end

  def format_parameter(params = %{}, api, indent, options) do
    newline_lead = if Keyword.get(options, :newline_lead, false) == true, do: "\n", else: ""
    indent_bullet = String.duplicate(" ", indent * 2) <> "-"
    s1 = for {k, v} <- params do
      "\n#{indent_bullet} #{k}: #{format_parameter(v, api, indent + 1, newline_lead: false)}"
    end |> Enum.join("")
    s2 = newline_lead <> s1
    #String.rstrip(s2)
  end

  def format_parameter({name, spec = %{}}, api, indent, options) do
    indent_bullet = String.duplicate(" ", indent * 2) <> "-"
    s1 = "#{indent_bullet} #{name}"
    s2 = for {k, v} <- spec do
      "\n  #{indent_bullet} #{k}: #{format_parameter(v, api, indent + 2, newline_lead: false)}"
    end
    s3 = s1 <> Enum.join(s2, "")
    #String.rstrip(s3)
  end

  def format_parameter(val, api, indent, options), do: val

  @doc """
  Generate documentation for parameter.
  """
  def generate_param_doc(param = {name, spec = %{}}, api) do
    template = ~s"""
- <%= name %>
<%= for {key, value} <- spec do %>  - <%= key %>: <%= value %>
<% end %>
  """
  IO.puts "spec is: #{inspect spec}"

    EEx.eval_string template, name: name, spec: spec
  end

  def xgenerate_param_doc(param = {name, spec = %{}}, api) do
    "boo!"
  end

  def test() do
    api = read_api_file()
    blah = generate_code(api)
    blah
  end

  def get_schema_ref(api, ref) do
    api["schemas"][ref]
  end

end

defmodule GoogleApi.CodeGen.Generate do
  GoogleApi.CodeGen.test |> GoogleApi.CodeGen.create_modules
end

defmodule GoogleApi.Helpers do
  def parse_as_json([]), do: ""
  def parse_as_json(params) do
    JSX.encode!(params)
  end

end
