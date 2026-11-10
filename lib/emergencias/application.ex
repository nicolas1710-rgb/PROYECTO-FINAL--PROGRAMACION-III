defmodule Emergencias.Application do
  @moduledoc "Arbol de supervision raiz de la aplicacion Emergencias."
  use Application

  alias Emergencias.Infraestructura.Procesos.{
    Albergue,
    Bitacora,
    GestorLogistica,
    GestorMascotas,
    GestorPersonas,
    GestorUsuarios,
    GestorZonas,
    SupervisorAlbergues
  }
  alias Emergencias.Infraestructura.Salida.AlmacenArchivo

  @impl true
  def start(_type, _args) do
    iniciar_supervision()
  end

  @doc "Iniciar la supervision con estrategia :one_for_one y limites de reinicio 3 en 5s."
  def iniciar_supervision do
    hijos = [
      {Registry, keys: :unique, name: Emergencias.RegistroAlbergues},
      {Bitacora, []},
      {GestorUsuarios, []},
      {GestorZonas, []},
      {GestorLogistica, []},
      {GestorPersonas, []},
      {GestorMascotas, []},
      {SupervisorAlbergues, []},
      {Task.Supervisor, name: Emergencias.TaskSupervisor},
      {Phoenix.PubSub, name: Emergencias.PubSub},
      EmergenciasWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, max_restarts: 3, max_seconds: 5, name: Emergencias.SupervisorRaiz]

    case Supervisor.start_link(hijos, opts) do
      {:ok, pid} ->
        cargar_albergues_activos()
        {:ok, pid}
      error -> error
    end
  end

  defp cargar_albergues_activos do
    Enum.each(AlmacenArchivo.cargar(:albergues), fn alb ->
      DynamicSupervisor.start_child(SupervisorAlbergues, {Albergue, alb})
    end)
  end
end
