defmodule EmergenciasWeb.ConnCase do
  @moduledoc "Plantilla ExUnit para pruebas de controladores y LiveViews."
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint EmergenciasWeb.Endpoint
      use EmergenciasWeb, :verified_routes
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import EmergenciasWeb.ConnCase
    end
  end

  setup _tags do
    dir = Path.join(System.tmp_dir!(), "emergencias_web_#{System.unique_integer([:positive])}")
    Application.put_env(:emergencias, :directorio_datos, dir)
    File.mkdir_p!(dir)

    if pid = :erlang.whereis(Emergencias.SupervisorRaiz) do
      try do
        Supervisor.stop(pid)
        Process.sleep(40)
      catch
        :exit, _ -> :ok
      end
    end

    case Emergencias.Application.iniciar_supervision() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    on_exit(fn -> File.rm_rf(dir) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Iniciar sesion inyectando el usuario en la sesion de prueba."
  def iniciar_sesion(conn, usuario) do
    Plug.Test.init_test_session(conn, %{"usuario" => usuario})
  end
end
