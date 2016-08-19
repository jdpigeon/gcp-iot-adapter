defmodule GoogleApi.Spec.CodeGenSpec do
  use ESpec

  defmodule FakeHttpExecutor do
    def do_request(pid, method, url, body, headers, options) do
      {:ok, %{pid: pid, method: method, url: url, body: body, headers: headers, options: options}}
    end
  end

  context "CodeGen" do
    describe "create_method returns versioned_module atom" do
      it do
        {versioned_module, _code} = GoogleApi.CodeGen.create_method({"publish", shared.api["resources"]["projects"]["resources"]["topics"]["methods"]["publish"]}, shared.api)
        expect versioned_module |> to(eq GoogleApi.V1.Pubsub.Projects.Topics)
      end
    end

    # describe "create_method returns quoted function for discovery method" do
    #   before do: allow GoogleApi.Http |> to(accept :do_request, fn(method, url, body, headers, options) -> nil end)
    #
    #   it do
    #     {versioned_module, code} = GoogleApi.CodeGen.create_method({"publish", shared.api["resources"]["projects"]["resources"]["topics"]["methods"]["publish"]}, shared.api)
    #     IO.puts "#{inspect code}"
    #     IO.puts "..........."
    #     IO.puts Macro.to_string(Macro.expand(code, __ENV__))
    #
    #     Module.create(versioned_module, code, Macro.Env.location(__ENV__))
    #
    #     GoogleApi.V1.Pubsub.Projects.Topics.publish(topic: "projects/testproject/sometopic", body: %{"a" => 42})
    #
    #     method = :meck.capture(:first, GoogleApi.Http, :do_request, 5, 1)
    #     url = :meck.capture(:first, GoogleApi.Http, :do_request, 5, 2)
    #     body = :meck.capture(:first, GoogleApi.Http, :do_request, 5, 3)
    #     headers = :meck.capture(:first, GoogleApi.Http, :do_request, 5, 4)
    #     options = :meck.capture(:first, GoogleApi.Http, :do_request, 5, 5)
    #
    #     IO.puts "\n\n\n=========\nmethod is #{inspect method}"
    #     IO.puts "url is #{inspect url}"
    #
    #     expect method |> to(eq :post)
    #     expect url |> to(eq "https://pubsub.googleapis.com/v1/projects/testproject/sometopic:publish")
    #     expect JSX.decode!(body) |> to(eq %{"a" => 42})
    #     expect headers |> to(eq [])
    #     expect options |> to(eq [recv_timeout: 5_000])
    #   end
    # end

    describe "create_method creates make_request_context method that returns correct request Map" do
      it do
        {versioned_module, code} = GoogleApi.CodeGen.create_method({"publish", shared.api["resources"]["projects"]["resources"]["topics"]["methods"]["publish"]}, shared.api)
        IO.puts "#{inspect code}"
        IO.puts "..........."
        IO.puts Macro.to_string(Macro.expand(code, __ENV__))

        Module.create(versioned_module, code, Macro.Env.location(__ENV__))

        context = GoogleApi.V1.Pubsub.Projects.Topics.make_request_context(:publish, topic: "projects/testproject/sometopic", body: %{"a" => 42})

        IO.puts "\n\n\n=========\context is #{inspect context}"

        expect context.httpMethod |> to(eq :post)
        expect context.url |> to(eq "https://pubsub.googleapis.com/v1/projects/testproject/sometopic:publish")
        expect JSX.decode!(context.body) |> to(eq %{"a" => 42})
        expect context.options |> to(eq [recv_timeout: 5_000])
      end
    end

    describe "generated code accepts http executor and pid and makes request" do
      it do
        {versioned_module, code} = GoogleApi.CodeGen.create_method({"publish", shared.api["resources"]["projects"]["resources"]["topics"]["methods"]["publish"]}, shared.api)
        Module.create(versioned_module, code, Macro.Env.location(__ENV__))
        {:ok, response} = GoogleApi.V1.Pubsub.Projects.Topics.publish(FakeHttpExecutor, nil, topic: "projects/testproject/sometopic", body: %{"a" => 42})
        IO.inspect response
        expected_response = %{body: "{\"a\":42}", headers: [], method: :post, options: [recv_timeout: 5000], pid: nil, url: "https://pubsub.googleapis.com/v1/projects/testproject/sometopic:publish"}
        expect response |> to(eq expected_response)
      end
    end

    describe "get_versioned_module returns correct module" do
      it do
        versioned_module = GoogleApi.CodeGen.get_versioned_module("publish", "pubsub.projects.topics.publish", shared.api)
        expect versioned_module |> to(eq GoogleApi.V1.Pubsub.Projects.Topics)
      end
    end

    describe "generate param doc from Discovery document", docgen: true do
      it do
        doc_string = GoogleApi.CodeGen.generate_param_doc({"project",
        shared.api["resources"]["projects"]["resources"]["topics"]["methods"]["list"]["parameters"]["project"]}, shared.api)
        IO.puts doc_string
      end
    end
  end

end
