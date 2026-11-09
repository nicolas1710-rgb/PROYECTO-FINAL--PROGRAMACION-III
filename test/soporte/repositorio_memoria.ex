defmodule Emergencias.Soporte.RepositorioMemoria do
  @moduledoc """
  Doble de prueba en memoria para persistencia sin tocar el sistema de archivos.
  Utiliza Agent para almacenar el estado durante las pruebas unitarias de casos de uso.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Salida.Repositorio

  use Agent

  @doc """
  Iniciar el almacén en memoria para pruebas.
  """
  @spec iniciar() :: {:ok, pid()} | {:error, any()}
  def iniciar do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Detener el almacén en memoria.
  """
  @spec detener() :: :ok
  def detener do
    if Process.whereis(__MODULE__) != nil do
      Agent.stop(__MODULE__)
    else
      :ok
    end
  end

  @doc """
  Limpiar el estado de todas las entidades en el almacén en memoria.
  """
  @spec limpiar() :: :ok
  def limpiar do
    if Process.whereis(__MODULE__) != nil and Process.alive?(Process.whereis(__MODULE__)) do
      Agent.update(__MODULE__, fn _ -> %{} end)
    else
      :ok
    end
  end

  @impl true
  def guardar(entidad, registros) when is_list(registros) do
    Agent.update(__MODULE__, fn estado ->
      Map.put(estado, entidad, registros)
    end)
    :ok
  end

  def guardar(entidad, registro) do
    Agent.update(__MODULE__, fn estado ->
      existentes = Map.get(estado, entidad, [])
      nuevos = [registro | Enum.reject(existentes, &(&1.id == registro.id))]
      Map.put(estado, entidad, nuevos)
    end)
    :ok
  end

  @impl true
  def cargar(entidad) do
    lista = Agent.get(__MODULE__, fn estado -> Map.get(estado, entidad, []) end)
    {:ok, Enum.reverse(lista)}
  end

  @impl true
  def listar(entidad), do: cargar(entidad)
end
