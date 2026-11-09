defmodule Emergencias.Infraestructura.Procesos.SupervisorAlbergues do
  @moduledoc """
  DynamicSupervisor para orquestar los procesos concurrentes de albergues.
  """

  use DynamicSupervisor

  alias Emergencias.Dominio.Modelos.Albergue
  alias Emergencias.Infraestructura.Procesos.Albergue, as: ProcesoAlbergue

  @doc """
  Iniciar el supervisor dinámico de albergues.
  """
  @spec iniciar(keyword()) :: {:ok, pid()} | {:error, any()}
  def iniciar(opciones \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  @doc """
  Callback exigido por OTP; delega a iniciar/1.
  """
  def start_link(opciones \\ []), do: iniciar(opciones)

  @doc """
  Especificación de supervisión OTP; delega a definir_especificacion/1.
  """
  def child_spec(opciones), do: definir_especificacion(opciones)

  @doc """
  Definir la especificación de supervisión para el supervisor dinámico de albergues.
  """
  @spec definir_especificacion(keyword()) :: map()
  def definir_especificacion(opciones) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :iniciar, [opciones]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Lanzar un proceso concurrente para un albergue bajo la supervisión dinámica.
  """
  @spec iniciar_albergue(Albergue.t()) :: {:ok, pid()} | {:error, any()}
  def iniciar_albergue(%Albergue{} = albergue) do
    especificacion = {ProcesoAlbergue, albergue}
    DynamicSupervisor.start_child(__MODULE__, especificacion)
  end

  @impl true
  def init(opciones) do
    inicializar_supervisor(opciones)
  end

  @doc """
  Inicializar la estrategia de supervisión dinámica :one_for_one.
  """
  @spec inicializar_supervisor(keyword()) :: {:ok, map()}
  def inicializar_supervisor(_opciones) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
