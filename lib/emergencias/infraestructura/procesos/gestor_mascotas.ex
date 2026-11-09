defmodule Emergencias.Infraestructura.Procesos.GestorMascotas do
  @moduledoc """
  GenServer para la administración concurrente de reportes de mascotas y su emparejamiento.
  Impide el doble cierre y serializa resoluciones.
  Implementa el puerto de salida PuertoSalidaMascotas.
  """

  use GenServer

  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaMascotas

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.ReporteMascota
  alias Emergencias.Dominio.Reglas.{SimilitudMascotas, TransicionesEstado, Validaciones}
  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @doc """
  Iniciar el GenServer de mascotas.
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
  Definir la especificación de supervisión para el gestor de mascotas.
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
  Registrar reporte de mascota.
  """
  @spec reportar_mascota(map(), String.t()) :: {:ok, ReporteMascota.t()} | {:error, atom()}
  def reportar_mascota(params, usuario) do
    GenServer.call(__MODULE__, {:reportar, params, usuario})
  end

  @impl true
  @doc "Implementación del puerto: reportar mascota."
  @spec reportar(map(), String.t()) :: {:ok, ReporteMascota.t()} | {:error, atom()}
  def reportar(params, usuario), do: reportar_mascota(params, usuario)

  @doc """
  Emparejar mascotas activas calculando similitud ponderada.
  """
  @spec emparejar_mascotas(non_neg_integer()) ::
          {:ok, list({ReporteMascota.t(), ReporteMascota.t(), non_neg_integer()})}
  def emparejar_mascotas(umbral \\ 60) do
    GenServer.call(__MODULE__, {:emparejar, umbral})
  end

  @impl true
  @doc "Implementación del puerto: emparejar mascotas."
  @spec emparejar(non_neg_integer()) ::
          {:ok, list({ReporteMascota.t(), ReporteMascota.t(), non_neg_integer()})}
  def emparejar(umbral), do: emparejar_mascotas(umbral)

  @doc """
  Resolver reporte de mascota impidiendo el doble cierre.
  """
  @spec resolver_mascota(String.t(), String.t()) :: {:ok, ReporteMascota.t()} | {:error, atom()}
  def resolver_mascota(id_mascota, usuario) do
    GenServer.call(__MODULE__, {:resolver, id_mascota, usuario})
  end

  @impl true
  @doc "Implementación del puerto: resolver caso de mascota."
  @spec resolver(String.t(), String.t()) :: {:ok, ReporteMascota.t()} | {:error, atom()}
  def resolver(id_mascota, usuario), do: resolver_mascota(id_mascota, usuario)

  @doc """
  Listar todos los reportes de mascotas en memoria.
  """
  @spec listar_mascotas() :: {:ok, list(ReporteMascota.t())}
  def listar_mascotas do
    GenServer.call(__MODULE__, :listar)
  end

  @impl true
  @doc "Implementación del puerto: listar reportes de mascotas."
  @spec listar() :: {:ok, list(ReporteMascota.t())}
  def listar, do: listar_mascotas()

  @doc """
  Recargar reportes de mascotas desde persistencia en disco.
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
  def handle_call({:reportar, params, usuario}, _from, estado) do
    ejecutar_reporte(params, usuario, estado)
  end

  @impl true
  def handle_call({:emparejar, umbral}, _from, estado) do
    ejecutar_emparejamiento(umbral, estado)
  end

  @impl true
  def handle_call({:resolver, id_mascota, usuario}, _from, estado) do
    ejecutar_resolucion(id_mascota, usuario, estado)
  end

  @impl true
  def handle_call(:listar, _from, estado) do
    responder_listado(estado)
  end

  # Funciones con verbos en infinitivo
  @doc """
  Inicializar el estado cargando reportes desde persistencia.
  """
  @spec inicializar_gestor(keyword()) :: {:ok, map()}
  def inicializar_gestor(_opciones) do
    {:ok, mascotas} = MotorPersistencia.cargar(:mascotas)
    mapa = Map.new(mascotas, fn m -> {String.upcase(m.id), m} end)
    {:ok, %{mascotas: mapa}}
  end

  @doc """
  Ejecutar el registro seguro de un reporte de mascota.
  """
  @spec ejecutar_reporte(map(), String.t(), map()) ::
          {:reply, {:ok, ReporteMascota.t()} | {:error, atom()}, map()}
  def ejecutar_reporte(params, usuario, estado) do
    with {:ok, validados} <- Validaciones.validar_entrada_mascota(params) do
      nuevo_id = GeneradorId.formatear_id(:mascota, map_size(estado.mascotas) + 1)
      fecha = Reloj.obtener_fecha_actual()

      {:ok, nuevo_rep} =
        ReporteMascota.construir(%{
          id: nuevo_id,
          tipo_reporte: validados.tipo_reporte,
          especie: validados.especie,
          nombre: validados.nombre,
          color: validados.color,
          tamano: validados.tamano,
          codigo_zona: validados.codigo_zona,
          caracteristicas: validados.caracteristicas,
          estado: :activa,
          usuario_reporta: usuario,
          fecha_registro: fecha
        })

      MotorPersistencia.guardar(:mascotas, nuevo_rep)
      nuevas = Map.put(estado.mascotas, String.upcase(nuevo_id), nuevo_rep)
      {:reply, {:ok, nuevo_rep}, %{estado | mascotas: nuevas}}
    else
      error -> {:reply, error, estado}
    end
  end

  @doc """
  Ejecutar el emparejamiento ponderado entre perdidas y encontradas activas.
  """
  @spec ejecutar_emparejamiento(non_neg_integer(), map()) ::
          {:reply, {:ok, list({ReporteMascota.t(), ReporteMascota.t(), non_neg_integer()})}, map()}
  def ejecutar_emparejamiento(umbral, estado) do
    lista = Map.values(estado.mascotas)
    perdidas = Enum.filter(lista, fn m -> m.tipo_reporte == :perdida and m.estado == :activa end)
    encontradas = Enum.filter(lista, fn m -> m.tipo_reporte == :encontrada and m.estado == :activa end)

    coincidencias = SimilitudMascotas.emparejar_reportes(perdidas, encontradas, umbral)
    {:reply, {:ok, coincidencias}, estado}
  end

  @doc """
  Ejecutar la resolución del reporte impidiendo doble cierre.
  """
  @spec ejecutar_resolucion(String.t(), String.t(), map()) ::
          {:reply, {:ok, ReporteMascota.t()} | {:error, atom()}, map()}
  def ejecutar_resolucion(id_mascota, usuario, estado) do
    clave = String.upcase(id_mascota)

    case Map.get(estado.mascotas, clave) do
      nil ->
        {:reply, {:error, :mascota_no_encontrada}, estado}

      %ReporteMascota{} = mascota ->
        fecha = Reloj.obtener_fecha_actual()

        case TransicionesEstado.transitar_mascota(mascota, :resuelta, usuario, fecha) do
          {:ok, transitada} ->
            MotorPersistencia.guardar(:mascotas, transitada)
            nuevas = Map.put(estado.mascotas, clave, transitada)
            {:reply, {:ok, transitada}, %{estado | mascotas: nuevas}}

          {:error, razon} ->
            {:reply, {:error, razon}, estado}
        end
    end
  end

  @doc """
  Responder la lista de todas las mascotas registradas.
  """
  @spec responder_listado(map()) :: {:reply, {:ok, list(ReporteMascota.t())}, map()}
  def responder_listado(estado) do
    {:reply, {:ok, Map.values(estado.mascotas)}, estado}
  end
end
