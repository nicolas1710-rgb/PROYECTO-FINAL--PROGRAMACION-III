defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoLogistica do
  @moduledoc "Puerto de salida unificado para recursos, necesidades y movimientos."
  @callback registrar_recurso(map()) :: {:ok, struct()} | {:error, atom()}
  @callback registrar_necesidad(map()) :: {:ok, struct()} | {:error, atom()}
  @callback asignar(String.t(), String.t(), integer(), String.t(), String.t()) :: {:ok, tuple()} | {:error, atom()}
  @callback transferir(String.t(), String.t(), String.t(), integer(), String.t(), String.t()) :: {:ok, tuple()} | {:error, atom()}
  @callback actualizar_necesidad(String.t(), atom(), String.t(), String.t()) :: {:ok, struct()} | {:error, atom()}
  @callback listar_recursos() :: [struct()]
  @callback listar_necesidades() :: [struct()]
  @callback listar_movimientos() :: [struct()]
  @callback consultar_recurso(String.t()) :: {:ok, struct()} | {:error, atom()}
  @callback consultar_necesidad(String.t()) :: {:ok, struct()} | {:error, atom()}
end
