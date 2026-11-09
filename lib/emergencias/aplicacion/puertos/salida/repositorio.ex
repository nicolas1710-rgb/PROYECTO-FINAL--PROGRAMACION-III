defmodule Emergencias.Aplicacion.Puertos.Salida.Repositorio do
  @moduledoc """
  Puerto de salida que abstrae la persistencia y recuperación de entidades del sistema.
  """

  @callback guardar(atom(), list(struct()) | struct()) :: :ok | {:error, atom()}
  @callback cargar(atom()) :: {:ok, list(struct())} | {:error, atom()}
  @callback listar(atom()) :: {:ok, list(struct())} | {:error, atom()}
end
