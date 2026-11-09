defmodule Emergencias.Infraestructura.Procesos.Albergue do
  @moduledoc """
  Proceso concurrente puro (sin GenServer) para cada albergue con bucle `receive` recursivo.
  Rastrea en memoria y sincroniza la ocupación de personas mediante MapSet.
  """

  alias Emergencias.Dominio.Modelos.Albergue
  alias Emergencias.Dominio.Reglas.Ocupacion
  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @registro Emergencias.RegistroAlbergues

  @doc """
  Especificación de hijo para el DynamicSupervisor OTP.
  """
  def child_spec(albergue) do
    definir_especificacion(albergue)
  end

  @doc """
  Definir la especificación del proceso para el DynamicSupervisor.
  """
  @spec definir_especificacion(Albergue.t()) :: map()
  def definir_especificacion(%Albergue{} = albergue) do
    %{
      id: {:albergue, albergue.id},
      start: {__MODULE__, :iniciar, [albergue]},
      restart: :transient,
      type: :worker
    }
  end

  @doc """
  Iniciar el proceso concurrente del albergue vinculándolo sincronizadamente al Registry.
  """
  @spec iniciar(Albergue.t()) :: {:ok, pid()}
  def iniciar(%Albergue{} = albergue) do
    padre = self()

    pid =
      spawn_link(fn ->
        Registry.register(@registro, albergue.id, albergue)
        send(padre, {:albergue_registrado, self()})
        ejecutar_bucle(albergue)
      end)

    receive do
      {:albergue_registrado, ^pid} -> {:ok, pid}
    after
      2000 -> {:ok, pid}
    end
  end

  @doc """
  Bucle recursivo puro que atiende mensajes de ocupación.
  """
  @spec ejecutar_bucle(Albergue.t()) :: no_return()
  def ejecutar_bucle(%Albergue{} = albergue) do
    receive do
      {:ingresar, documento, remitente} ->
        nuevo_albergue = procesar_ingreso(albergue, documento, remitente)
        ejecutar_bucle(nuevo_albergue)

      {:salir, documento, remitente} ->
        nuevo_albergue = procesar_salida(albergue, documento, remitente)
        ejecutar_bucle(nuevo_albergue)

      {:consultar, remitente} ->
        send(remitente, {:respuesta_albergue, {:ok, albergue}})
        ejecutar_bucle(albergue)

      {:asociar_recurso, id_recurso, cantidad, remitente} ->
        nuevo_mapa = Map.update(albergue.recursos_asignados, id_recurso, cantidad, &(&1 + cantidad))
        albergue_actualizado = %{albergue | recursos_asignados: nuevo_mapa}
        sincronizar_persistencia(albergue_actualizado)
        send(remitente, {:respuesta_albergue, {:ok, albergue_actualizado}})
        ejecutar_bucle(albergue_actualizado)

      {:asociar_necesidad, id_necesidad, remitente} ->
        nuevas_nec =
          if id_necesidad in albergue.necesidades_asociadas do
            albergue.necesidades_asociadas
          else
            [id_necesidad | albergue.necesidades_asociadas]
          end

        albergue_actualizado = %{albergue | necesidades_asociadas: nuevas_nec}
        sincronizar_persistencia(albergue_actualizado)
        send(remitente, {:respuesta_albergue, {:ok, albergue_actualizado}})
        ejecutar_bucle(albergue_actualizado)

      _mensaje_ignorado ->
        ejecutar_bucle(albergue)
    end
  end

  @doc """
  Ingresar una persona enviando mensaje sincrónico al proceso del albergue.
  """
  @spec ingresar_persona(String.t(), String.t(), timeout()) :: {:ok, Albergue.t()} | {:error, atom()}
  def ingresar_persona(codigo_albergue, documento, tiempo_espera \\ 5000) do
    case localizar_proceso(codigo_albergue) do
      {:ok, pid} ->
        send(pid, {:ingresar, documento, self()})
        esperar_respuesta(tiempo_espera)

      error ->
        error
    end
  end

  @doc """
  Retirar una persona enviando mensaje al proceso del albergue.
  """
  @spec retirar_persona(String.t(), String.t(), timeout()) :: {:ok, Albergue.t()} | {:error, atom()}
  def retirar_persona(codigo_albergue, documento, tiempo_espera \\ 5000) do
    case localizar_proceso(codigo_albergue) do
      {:ok, pid} ->
        send(pid, {:salir, documento, self()})
        esperar_respuesta(tiempo_espera)

      error ->
        error
    end
  end

  @doc """
  Consultar el estado del albergue directamente desde su proceso en memoria.
  """
  @spec consultar(String.t(), timeout()) :: {:ok, Albergue.t()} | {:error, atom()}
  def consultar(codigo_albergue, tiempo_espera \\ 5000) do
    case localizar_proceso(codigo_albergue) do
      {:ok, pid} ->
        send(pid, {:consultar, self()})
        esperar_respuesta(tiempo_espera)

      error ->
        error
    end
  end

  @doc """
  Asociar una cantidad de recurso al albergue.
  """
  @spec asociar_recurso(String.t(), String.t(), pos_integer(), timeout()) :: {:ok, Albergue.t()} | {:error, atom()}
  def asociar_recurso(codigo_albergue, id_recurso, cantidad, tiempo_espera \\ 5000) do
    case localizar_proceso(codigo_albergue) do
      {:ok, pid} ->
        send(pid, {:asociar_recurso, id_recurso, cantidad, self()})
        esperar_respuesta(tiempo_espera)

      error ->
        error
    end
  end

  @doc """
  Asociar una necesidad humanitaria al albergue.
  """
  @spec asociar_necesidad(String.t(), String.t(), timeout()) :: {:ok, Albergue.t()} | {:error, atom()}
  def asociar_necesidad(codigo_albergue, id_necesidad, tiempo_espera \\ 5000) do
    case localizar_proceso(codigo_albergue) do
      {:ok, pid} ->
        send(pid, {:asociar_necesidad, id_necesidad, self()})
        esperar_respuesta(tiempo_espera)

      error ->
        error
    end
  end

  defp procesar_ingreso(albergue, documento, remitente) do
    case Ocupacion.ingresar_persona(albergue, documento) do
      {:ok, albergue_actualizado} ->
        sincronizar_persistencia(albergue_actualizado)
        send(remitente, {:respuesta_albergue, {:ok, albergue_actualizado}})
        albergue_actualizado

      {:error, razon} ->
        send(remitente, {:respuesta_albergue, {:error, razon}})
        albergue
    end
  end

  defp procesar_salida(albergue, documento, remitente) do
    case Ocupacion.retirar_persona(albergue, documento) do
      {:ok, albergue_actualizado} ->
        sincronizar_persistencia(albergue_actualizado)
        send(remitente, {:respuesta_albergue, {:ok, albergue_actualizado}})
        albergue_actualizado

      {:error, razon} ->
        send(remitente, {:respuesta_albergue, {:error, razon}})
        albergue
    end
  end

  defp sincronizar_persistencia(albergue) do
    if Process.whereis(MotorPersistencia) != nil do
      MotorPersistencia.guardar(:albergues, albergue)
    end
  end

  defp localizar_proceso(codigo) do
    case Registry.lookup(@registro, codigo) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :proceso_no_encontrado}
    end
  end

  defp esperar_respuesta(tiempo_espera) do
    receive do
      {:respuesta_albergue, respuesta} -> respuesta
    after
      tiempo_espera -> {:error, :tiempo_agotado}
    end
  end
end
