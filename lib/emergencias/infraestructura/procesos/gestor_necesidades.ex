defmodule Emergencias.Infraestructura.Procesos.GestorNecesidades do
  @moduledoc """
  GenServer para la administración de necesidades humanitarias y control de transiciones de estado.
  Evita doble cierre y serializa modificaciones de necesidades.
  """

  use GenServer

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.Necesidad
  alias Emergencias.Dominio.Reglas.{TransicionesEstado, Validaciones}
  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @doc """
  Iniciar el GenServer de necesidades.
  """
  @spec iniciar(keyword()) :: {:ok, pid()} | {:error, any()}
  def iniciar(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
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
  Definir la especificación de supervisión para el gestor de necesidades.
  """
  @spec definir_especificacion(keyword()) :: map()
  def definir_especificacion(opciones) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :iniciar, [opciones]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Registrar una nueva necesidad.
  """
  @spec registrar_necesidad(map(), String.t()) :: {:ok, Necesidad.t()} | {:error, atom()}
  def registrar_necesidad(params, usuario) do
    GenServer.call(__MODULE__, {:registrar, params, usuario})
  end

  @doc """
  Actualizar el estado de una necesidad previa validación de grafo y cierre.
  """
  @spec actualizar_estado(String.t(), atom(), String.t()) ::
          {:ok, Necesidad.t()} | {:error, atom()}
  def actualizar_estado(id_necesidad, nuevo_estado, usuario) do
    GenServer.call(__MODULE__, {:actualizar, id_necesidad, nuevo_estado, usuario})
  end

  @doc """
  Listar necesidades aplicando filtros.
  """
  @spec listar_necesidades(keyword()) :: {:ok, list(Necesidad.t())}
  def listar_necesidades(filtros \\ []) do
    GenServer.call(__MODULE__, {:listar, filtros})
  end

  @doc """
  Recargar necesidades desde persistencia en disco.
  """
  @spec recargar_datos() :: :ok
  def recargar_datos do
    GenServer.call(__MODULE__, :recargar)
  end

  # Callbacks OTP
  @impl true
  def init(opciones) do
    inicializar_gestor(opciones)
  end

  @impl true
  def handle_call(:recargar, _from, _estado) do
    {:ok, nuevo_estado} = inicializar_gestor([])
    {:reply, :ok, nuevo_estado}
  end

  @impl true
  def handle_call({:registrar, params, usuario}, _from, estado) do
    ejecutar_registro(params, usuario, estado)
  end

  @impl true
  def handle_call({:actualizar, id_necesidad, nuevo_estado, usuario}, _from, estado) do
    ejecutar_actualizacion(id_necesidad, nuevo_estado, usuario, estado)
  end

  @impl true
  def handle_call({:listar, filtros}, _from, estado) do
    ejecutar_listado(filtros, estado)
  end

  # Funciones con verbos en infinitivo
  @doc """
  Inicializar el estado cargando necesidades desde disco a memoria.
  """
  @spec inicializar_gestor(keyword()) :: {:ok, map()}
  def inicializar_gestor(_opciones) do
    {:ok, necesidades} = MotorPersistencia.cargar(:necesidades)
    mapa = Map.new(necesidades, fn n -> {String.upcase(n.id), n} end)
    {:ok, %{necesidades: mapa}}
  end

  @doc """
  Ejecutar el registro seguro de una necesidad con id secuencial.
  """
  @spec ejecutar_registro(map(), String.t(), map()) ::
          {:reply, {:ok, Necesidad.t()} | {:error, atom()}, map()}
  def ejecutar_registro(params, usuario, estado) do
    with {:ok, validados} <- Validaciones.validar_entrada_necesidad(params) do
      nuevo_id = GeneradorId.formatear_id(:necesidad, map_size(estado.necesidades) + 1)
      fecha = Reloj.obtener_fecha_actual()

      {:ok, nueva_nec} =
        Necesidad.construir(%{
          id: nuevo_id,
          codigo_zona: validados.codigo_zona,
          tipo_recurso: validados.tipo_recurso,
          cantidad_solicitada: validados.cantidad_solicitada,
          prioridad: validados.prioridad,
          estado: :pendiente,
          fecha_registro: fecha,
          usuario_reporta: usuario
        })

      MotorPersistencia.guardar(:necesidades, nueva_nec)
      nuevas = Map.put(estado.necesidades, String.upcase(nuevo_id), nueva_nec)
      {:reply, {:ok, nueva_nec}, %{estado | necesidades: nuevas}}
    else
      error -> {:reply, error, estado}
    end
  end

  @doc """
  Ejecutar la transición de estado garantizando que no se cierre dos veces.
  """
  @spec ejecutar_actualizacion(String.t(), atom(), String.t(), map()) ::
          {:reply, {:ok, Necesidad.t()} | {:error, atom()}, map()}
  def ejecutar_actualizacion(id_necesidad, nuevo_estado, usuario, estado) do
    clave = String.upcase(id_necesidad)

    case Map.get(estado.necesidades, clave) do
      nil ->
        {:reply, {:error, :necesidad_no_encontrada}, estado}

      %Necesidad{} = nec ->
        fecha = Reloj.obtener_fecha_actual()

        case TransicionesEstado.transitar_necesidad(nec, nuevo_estado, usuario, fecha) do
          {:ok, transitada} ->
            MotorPersistencia.guardar(:necesidades, transitada)
            nuevas = Map.put(estado.necesidades, clave, transitada)
            {:reply, {:ok, transitada}, %{estado | necesidades: nuevas}}

          {:error, razon} ->
            {:reply, {:error, razon}, estado}
        end
    end
  end

  @doc """
  Ejecutar el filtrado y listado de necesidades en memoria.
  """
  @spec ejecutar_listado(keyword(), map()) :: {:reply, {:ok, list(Necesidad.t())}, map()}
  def ejecutar_listado(filtros, estado) do
    lista = Map.values(estado.necesidades)
    resultado = filtrar_lista(lista, filtros)
    {:reply, {:ok, resultado}, estado}
  end

  defp filtrar_lista(lista, []), do: lista

  defp filtrar_lista(lista, [{:zona, z} | resto]) do
    lista
    |> Enum.filter(fn n -> String.downcase(n.codigo_zona) == String.downcase(to_string(z)) end)
    |> filtrar_lista(resto)
  end

  defp filtrar_lista(lista, [{:prioridad, p} | resto]) do
    lista
    |> Enum.filter(fn n -> to_string(n.prioridad) == to_string(p) end)
    |> filtrar_lista(resto)
  end

  defp filtrar_lista(lista, [{:estado, e} | resto]) do
    lista
    |> Enum.filter(fn n -> to_string(n.estado) == to_string(e) end)
    |> filtrar_lista(resto)
  end

  defp filtrar_lista(lista, [_ | resto]), do: filtrar_lista(lista, resto)
end
