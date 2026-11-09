defmodule Emergencias.Infraestructura.Procesos.Bitacora do
  @moduledoc "Proceso puro con bucle receive para auditar actividades por usuario."
  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoBitacora

  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :iniciar, [opts]}, type: :worker}
  end

  def iniciar(_opts \\ []) do
    pid = spawn_link(fn ->
      Process.register(self(), __MODULE__)
      bucle([])
    end)
    {:ok, pid}
  end

  def start_link(opts \\ []), do: iniciar(opts)

  @impl true
  def registrar_actividad(u, accion, detalles, fecha) do
    if pid = :erlang.whereis(__MODULE__) do
      send(pid, {:registrar, {u, accion, detalles, fecha}})
    end
    :ok
  end

  @impl true
  def consultar_por_usuario(u) do
    if pid = :erlang.whereis(__MODULE__) do
      send(pid, {:consultar, u, self()})
      receive do {:actividades, lista} -> lista after 1000 -> [] end
    else
      []
    end
  end

  def bucle(actividades) do
    receive do
      {:registrar, item} ->
        bucle([item | actividades])

      {:consultar, u, from} ->
        filtrados = Enum.filter(actividades, fn {usr, _, _, _} -> usr == u end)
        send(from, {:actividades, filtrados})
        bucle(actividades)
    end
  end
end
