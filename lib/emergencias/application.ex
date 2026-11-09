defmodule Emergencias.Application do
  @moduledoc """
  Árbol de supervisión raíz de la aplicación OTP Emergencias.
  Supervisa procesos de persistencia, bitácora recursiva, gestores concurrentes y albergues dinámicos.
  """

  use Application

  alias Emergencias.Infraestructura.Procesos.{
    BitacoraActividad,
    GestorMascotas,
    GestorNecesidades,
    GestorPersonas,
    GestorRecursos,
    GestorUsuarios,
    GestorZonas,
    SupervisorAlbergues
  }

  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @impl true
  def start(_type, _args) do
    iniciar_supervision()
  end

  @doc """
  Iniciar el árbol de supervisión raíz con estrategia :one_for_one.
  """
  @spec iniciar_supervision() :: {:ok, pid()} | {:error, any()}
  def iniciar_supervision do
    hijos = [
      {Registry, keys: :unique, name: Emergencias.RegistroAlbergues},
      {MotorPersistencia, []},
      {BitacoraActividad, []},
      {GestorUsuarios, []},
      {GestorZonas, []},
      {GestorNecesidades, []},
      {GestorRecursos, []},
      {GestorPersonas, []},
      {GestorMascotas, []},
      {SupervisorAlbergues, []},
      {Task.Supervisor, name: Emergencias.TaskSupervisor}
    ]

    opciones = [strategy: :one_for_one, max_restarts: 100, max_seconds: 5, name: Emergencias.SupervisorRaiz]

    case Supervisor.start_link(hijos, opciones) do
      {:ok, pid} ->
        cargar_albergues_existentes()
        {:ok, pid}

      error ->
        error
    end
  end

  defp cargar_albergues_existentes do
    {:ok, albergues} = MotorPersistencia.cargar(:albergues)
    Enum.each(albergues, &SupervisorAlbergues.iniciar_albergue/1)
  end
end
