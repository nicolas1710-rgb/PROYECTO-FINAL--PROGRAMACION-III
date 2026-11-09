defmodule Emergencias.Infraestructura.Procesos.AdaptadorAlbergues do
  @moduledoc """
  Adaptador de infraestructura que implementa PuertoSalidaAlbergues.
  Orquesta el DynamicSupervisor (SupervisorAlbergues), Registry y persistencia de albergues.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaAlbergues

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.Albergue
  alias Emergencias.Dominio.Reglas.Validaciones
  alias Emergencias.Infraestructura.Procesos.Albergue, as: ProcesoAlbergue
  alias Emergencias.Infraestructura.Procesos.SupervisorAlbergues
  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @impl true
  @doc "Registrar un nuevo albergue en el supervisor y persistencia."
  @spec registrar(map(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}
  def registrar(params, _usuario) do
    with {:ok, validados} <- Validaciones.validar_entrada_albergue(params) do
      {:ok, albergues} = MotorPersistencia.cargar(:albergues)
      nuevo_id = Map.get(params, :id) || GeneradorId.formatear_id(:albergue, length(albergues) + 1)
      fecha = Reloj.obtener_fecha_actual()

      {:ok, nuevo_alb} =
        Albergue.construir(%{
          id: nuevo_id,
          nombre: validados.nombre,
          codigo_zona: validados.codigo_zona,
          capacidad_maxima: validados.capacidad_maxima,
          fecha_registro: fecha,
          personas_alojadas: MapSet.new(),
          recursos_asignados: %{},
          necesidades_asociadas: []
        })

      MotorPersistencia.guardar(:albergues, nuevo_alb)
      SupervisorAlbergues.iniciar_albergue(nuevo_alb)
      {:ok, nuevo_alb}
    end
  end

  @impl true
  @doc "Consultar un albergue por su identificador único."
  @spec consultar(String.t()) :: {:ok, Albergue.t()} | {:error, atom()}
  def consultar(id) do
    case ProcesoAlbergue.consultar(id) do
      {:ok, alb} ->
        {:ok, alb}

      {:error, :proceso_no_encontrado} ->
        # Consultar en persistencia como respaldo
        {:ok, albergues} = MotorPersistencia.cargar(:albergues)

        case Enum.find(albergues, fn a -> String.upcase(a.id) == String.upcase(id) end) do
          nil -> {:error, :albergue_no_encontrado}
          alb -> {:ok, alb}
        end

      error ->
        error
    end
  end

  @impl true
  @doc "Registrar el ingreso de una persona al albergue."
  @spec ingresar(String.t(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}
  def ingresar(id, documento) do
    ProcesoAlbergue.ingresar_persona(id, documento)
  end

  @impl true
  @doc "Registrar la salida de una persona del albergue."
  @spec salir(String.t(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}
  def salir(id, documento) do
    ProcesoAlbergue.retirar_persona(id, documento)
  end

  @impl true
  @doc "Listar todos los albergues registrados."
  @spec listar() :: {:ok, list(Albergue.t())}
  def listar do
    {:ok, albergues} = MotorPersistencia.cargar(:albergues)

    albergues_actualizados =
      Enum.map(albergues, fn a ->
        case ProcesoAlbergue.consultar(a.id) do
          {:ok, en_vivo} -> en_vivo
          _ -> a
        end
      end)

    {:ok, albergues_actualizados}
  end

  @impl true
  @doc "Asociar recursos a un albergue."
  @spec asociar_recurso(String.t(), String.t(), pos_integer()) :: {:ok, Albergue.t()} | {:error, atom()}
  def asociar_recurso(id, id_recurso, cantidad) do
    ProcesoAlbergue.asociar_recurso(id, id_recurso, cantidad)
  end

  @impl true
  @doc "Asociar una necesidad a un albergue."
  @spec asociar_necesidad(String.t(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}
  def asociar_necesidad(id, id_necesidad) do
    ProcesoAlbergue.asociar_necesidad(id, id_necesidad)
  end
end
