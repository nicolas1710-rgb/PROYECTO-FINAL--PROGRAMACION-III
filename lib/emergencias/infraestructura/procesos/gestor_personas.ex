defmodule Emergencias.Infraestructura.Procesos.GestorPersonas do
  @moduledoc """
  GenServer para la administración de personas damnificadas y mensajería familiar en memoria.
  """

  use GenServer

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{Mensaje, Persona}
  alias Emergencias.Dominio.Reglas.{TransicionesEstado, Validaciones}
  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @doc """
  Iniciar el GenServer de personas y mensajería.
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
  Definir la especificación de supervisión para el gestor de personas.
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
  Registrar reporte de persona.
  """
  @spec reportar_persona(map(), String.t()) :: {:ok, Persona.t()} | {:error, atom()}
  def reportar_persona(params, usuario) do
    GenServer.call(__MODULE__, {:reportar, params, usuario})
  end

  @doc """
  Buscar persona por documento de identidad.
  """
  @spec buscar_persona(String.t()) :: {:ok, Persona.t()} | {:error, :persona_no_encontrada}
  def buscar_persona(documento) do
    GenServer.call(__MODULE__, {:buscar, documento})
  end

  @doc """
  Enviar mensaje familiar.
  """
  @spec enviar_mensaje(String.t(), String.t(), String.t()) :: {:ok, Mensaje.t()} | {:error, atom()}
  def enviar_mensaje(documento, contenido, remitente) do
    GenServer.call(__MODULE__, {:enviar_mensaje, documento, contenido, remitente})
  end

  @doc """
  Listar mensajes recibidos para una persona.
  """
  @spec listar_mensajes(String.t()) :: {:ok, list(Mensaje.t())}
  def listar_mensajes(documento) do
    GenServer.call(__MODULE__, {:listar_mensajes, documento})
  end

  @doc """
  Actualizar estado y ubicación de una persona.
  """
  @spec actualizar_persona(String.t(), atom(), map(), String.t()) ::
          {:ok, Persona.t()} | {:error, atom()}
  def actualizar_persona(documento, nuevo_estado, extras, usuario) do
    GenServer.call(__MODULE__, {:actualizar, documento, nuevo_estado, extras, usuario})
  end

  @doc """
  Listar todas las personas registradas en memoria.
  """
  @spec listar_personas() :: {:ok, list(Persona.t())}
  def listar_personas do
    GenServer.call(__MODULE__, :listar_personas)
  end

  @doc """
  Listar todos los mensajes registrados en memoria.
  """
  @spec listar_todos_mensajes() :: {:ok, list(Mensaje.t())}
  def listar_todos_mensajes do
    GenServer.call(__MODULE__, :listar_todos_mensajes)
  end

  @doc """
  Recargar personas y mensajes desde disco.
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
  def handle_call(:listar_personas, _from, estado) do
    {:reply, {:ok, Map.values(estado.personas)}, estado}
  end

  @impl true
  def handle_call(:listar_todos_mensajes, _from, estado) do
    {:reply, {:ok, Enum.reverse(estado.mensajes)}, estado}
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
  def handle_call({:buscar, documento}, _from, estado) do
    ejecutar_busqueda(documento, estado)
  end

  @impl true
  def handle_call({:enviar_mensaje, documento, contenido, remitente}, _from, estado) do
    ejecutar_envio_mensaje(documento, contenido, remitente, estado)
  end

  @impl true
  def handle_call({:listar_mensajes, documento}, _from, estado) do
    ejecutar_listado_mensajes(documento, estado)
  end

  @impl true
  def handle_call({:actualizar, doc, nuevo_est, extras, u}, _from, estado) do
    ejecutar_actualizacion(doc, nuevo_est, extras, u, estado)
  end

  # Funciones con verbos en infinitivo
  @doc """
  Inicializar el estado cargando personas y mensajes desde persistencia.
  """
  @spec inicializar_gestor(keyword()) :: {:ok, map()}
  def inicializar_gestor(_opciones) do
    {:ok, personas} = MotorPersistencia.cargar(:personas)
    {:ok, mensajes} = MotorPersistencia.cargar(:mensajes)

    mapa = Map.new(personas, fn p -> {String.trim(p.documento), p} end)
    {:ok, %{personas: mapa, mensajes: mensajes}}
  end

  @doc """
  Ejecutar el reporte de una persona en memoria y persistencia.
  """
  @spec ejecutar_reporte(map(), String.t(), map()) ::
          {:reply, {:ok, Persona.t()} | {:error, atom()}, map()}
  def ejecutar_reporte(params, _usuario, estado) do
    with {:ok, validados} <- Validaciones.validar_entrada_persona(params) do
      nuevo_id = GeneradorId.formatear_id(:persona, map_size(estado.personas) + 1)
      fecha = Reloj.obtener_fecha_actual()

      {:ok, nueva_p} =
        Persona.construir(%{
          id: nuevo_id,
          documento: validados.documento,
          nombre_completo: validados.nombre_completo,
          estado: :reportada,
          fecha_reporte: fecha,
          ubicacion_actual: Map.get(params, :ubicacion_actual, "desconocida"),
          codigo_albergue: Map.get(params, :codigo_albergue, nil)
        })

      MotorPersistencia.guardar(:personas, nueva_p)
      nuevas = Map.put(estado.personas, String.trim(validados.documento), nueva_p)
      {:reply, {:ok, nueva_p}, %{estado | personas: nuevas}}
    else
      error -> {:reply, error, estado}
    end
  end

  @doc """
  Ejecutar la búsqueda de una persona por documento.
  """
  @spec ejecutar_busqueda(String.t(), map()) ::
          {:reply, {:ok, Persona.t()} | {:error, :persona_no_encontrada}, map()}
  def ejecutar_busqueda(documento, estado) do
    case Map.get(estado.personas, String.trim(documento)) do
      %Persona{} = p -> {:reply, {:ok, p}, estado}
      nil -> {:reply, {:error, :persona_no_encontrada}, estado}
    end
  end

  @doc """
  Ejecutar el envío de un mensaje familiar.
  """
  @spec ejecutar_envio_mensaje(String.t(), String.t(), String.t(), map()) ::
          {:reply, {:ok, Mensaje.t()} | {:error, atom()}, map()}
  def ejecutar_envio_mensaje(documento, contenido, remitente, estado) do
    with {:ok, doc_valido} <- Validaciones.validar_documento(documento),
         {:ok, cont_valido} <- Validaciones.validar_texto_no_vacio(contenido) do
      nuevo_id = GeneradorId.formatear_id(:mensaje, length(estado.mensajes) + 1)
      fecha = Reloj.obtener_fecha_actual()

      {:ok, nuevo_m} =
        Mensaje.construir(%{
          id: nuevo_id,
          documento_persona: doc_valido,
          remitente: remitente,
          contenido: cont_valido,
          fecha_envio: fecha
        })

      MotorPersistencia.anexar(:mensajes, nuevo_m)
      {:reply, {:ok, nuevo_m}, %{estado | mensajes: [nuevo_m | estado.mensajes]}}
    else
      error -> {:reply, error, estado}
    end
  end

  @doc """
  Ejecutar el listado de mensajes asociados a un documento.
  """
  @spec ejecutar_listado_mensajes(String.t(), map()) :: {:reply, {:ok, list(Mensaje.t())}, map()}
  def ejecutar_listado_mensajes(documento, estado) do
    doc_limpio = String.trim(documento)
    filtrados = Enum.filter(estado.mensajes, fn m -> String.trim(m.documento_persona) == doc_limpio end)
    {:reply, {:ok, Enum.reverse(filtrados)}, estado}
  end

  @doc """
  Ejecutar la actualización de estado de una persona.
  """
  @spec ejecutar_actualizacion(String.t(), atom(), map(), String.t(), map()) ::
          {:reply, {:ok, Persona.t()} | {:error, atom()}, map()}
  def ejecutar_actualizacion(documento, nuevo_estado, extras, usuario, estado) do
    doc_limpio = String.trim(documento)

    case Map.get(estado.personas, doc_limpio) do
      nil ->
        {:reply, {:error, :persona_no_encontrada}, estado}

      %Persona{} = actual ->
        fecha = Reloj.obtener_fecha_actual()

        case TransicionesEstado.transitar_persona(actual, nuevo_estado, extras, usuario, fecha) do
          {:ok, transitada} ->
            MotorPersistencia.guardar(:personas, transitada)
            nuevas = Map.put(estado.personas, doc_limpio, transitada)
            {:reply, {:ok, transitada}, %{estado | personas: nuevas}}

          {:error, razon} ->
            {:reply, {:error, razon}, estado}
        end
    end
  end
end
