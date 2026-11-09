defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoPersonas do
  @moduledoc "Puerto de salida para registro de personas censadas y mensajeria familiar."
  @callback reportar(map()) :: {:ok, struct()} | {:error, atom()}
  @callback buscar(String.t()) :: {:ok, struct()} | {:error, atom()}
  @callback actualizar_estado(String.t(), atom(), String.t(), String.t(), String.t() | nil) :: {:ok, struct()} | {:error, atom()}
  @callback listar() :: [struct()]
  @callback enviar_mensaje(map()) :: {:ok, struct()} | {:error, atom()}
  @callback listar_mensajes(String.t()) :: [struct()]
  @callback listar_todos_mensajes() :: [struct()]
end
