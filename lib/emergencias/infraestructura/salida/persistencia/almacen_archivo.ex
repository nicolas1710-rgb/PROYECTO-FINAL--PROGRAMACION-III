defmodule Emergencias.Infraestructura.Salida.Persistencia.AlmacenArchivo do
  @moduledoc """
  Adaptador de persistencia que implementa el puerto Repositorio sobre archivos de texto.
  Delega en el proceso MotorPersistencia para evitar escrituras concurrentes conflictivas.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Salida.Repositorio

  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @impl true
  @doc """
  Guardar entidades en disco coordinado a través del Motor de Persistencia.
  """
  @spec guardar(atom(), list(struct()) | struct()) :: :ok | {:error, atom()}
  def guardar(entidad, registros) do
    if Process.whereis(MotorPersistencia) != nil do
      MotorPersistencia.guardar(entidad, registros)
    else
      dir = Application.get_env(:emergencias, :directorio_datos, "datos")
      File.mkdir_p!(dir)

      lista = if is_list(registros), do: registros, else: [registros]
      MotorPersistencia.escribir_registros_seguro(dir, entidad, lista)
    end
  end

  @impl true
  @doc """
  Cargar todos los registros almacenados para una entidad.
  """
  @spec cargar(atom()) :: {:ok, list(struct())} | {:error, atom()}
  def cargar(entidad) do
    MotorPersistencia.cargar(entidad)
  end

  @impl true
  @doc """
  Listar todos los registros de una entidad.
  """
  @spec listar(atom()) :: {:ok, list(struct())} | {:error, atom()}
  def listar(entidad), do: cargar(entidad)
end
