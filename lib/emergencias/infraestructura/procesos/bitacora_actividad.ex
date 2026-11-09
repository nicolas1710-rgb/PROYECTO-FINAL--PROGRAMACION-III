defmodule Emergencias.Infraestructura.Procesos.BitacoraActividad do
  @moduledoc """
  Proceso concurrente puro (sin GenServer) con bucle recursivo `receive`.
  Registra eventos de auditoría y permite su consulta histórica.
  """

  alias Emergencias.Aplicacion.Puertos.Salida.GeneradorId
  alias Emergencias.Dominio.Modelos.RegistroActividad
  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @nombre_proceso __MODULE__

  @doc """
  Iniciar el proceso de bitácora mediante spawn_link y bucle recursivo.
  """
  @spec iniciar(keyword()) :: {:ok, pid()}
  def iniciar(_opciones \\ []) do
    pid = spawn_link(fn -> ejecutar_bucle_actividad([]) end)
    Process.register(pid, @nombre_proceso)
    {:ok, pid}
  end

  @doc """
  Especificación de hijo para el supervisor OTP.
  """
  def child_spec(opciones) do
    definir_especificacion(opciones)
  end

  @doc """
  Definir la especificación de supervisión para el proceso.
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
  Registrar un evento de actividad de manera asíncrona.
  """
  @spec registrar_actividad(String.t(), String.t(), String.t(), String.t()) :: :ok
  def registrar_actividad(usuario, accion, detalles, fecha) do
    if Process.whereis(@nombre_proceso) != nil do
      send(@nombre_proceso, {:registrar, usuario, accion, detalles, fecha})
    end

    :ok
  end

  @doc """
  Consultar todo el historial de auditoría acumulado.
  """
  @spec consultar_actividad(timeout()) :: list(RegistroActividad.t())
  def consultar_actividad(tiempo_espera \\ 5000) do
    send(@nombre_proceso, {:consultar, self()})

    receive do
      {:respuesta_actividad, historial} -> historial
    after
      tiempo_espera -> []
    end
  end

  @doc """
  Bucle recursivo con función de cola para recepción de mensajes.
  """
  @spec ejecutar_bucle_actividad(list(RegistroActividad.t())) :: no_return()
  def ejecutar_bucle_actividad(historial) do
    receive do
      {:registrar, usuario, accion, detalles, fecha} ->
        nuevo_historial = procesar_registro(usuario, accion, detalles, fecha, historial)
        ejecutar_bucle_actividad(nuevo_historial)

      {:consultar, pid_origen} ->
        enviar_respuesta(pid_origen, historial)
        ejecutar_bucle_actividad(historial)

      _mensaje_ignorado ->
        ejecutar_bucle_actividad(historial)
    end
  end

  defp procesar_registro(usuario, accion, detalles, fecha, historial) do
    id = GeneradorId.formatear_id(:actividad, length(historial) + 1)

    {:ok, registro} =
      RegistroActividad.construir(%{
        id: id,
        usuario: usuario,
        accion: accion,
        detalles: detalles,
        fecha: fecha
      })

    if Process.whereis(MotorPersistencia) != nil do
      MotorPersistencia.anexar(:actividad, registro)
    end

    [registro | historial]
  end

  defp enviar_respuesta(pid, historial) do
    send(pid, {:respuesta_actividad, Enum.reverse(historial)})
  end
end
