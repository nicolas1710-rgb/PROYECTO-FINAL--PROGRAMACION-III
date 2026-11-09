defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoMascotas do
  @moduledoc "Puerto de salida para reportes de mascotas y confirmacion de coincidencias."
  @callback reportar(map()) :: {:ok, struct()} | {:error, atom()}
  @callback listar() :: [struct()]
  @callback consultar(String.t()) :: {:ok, struct()} | {:error, atom()}
  @callback confirmar_coincidencia(String.t(), String.t(), String.t(), String.t()) :: {:ok, tuple()} | {:error, atom()}
  @callback actualizar_estado(String.t(), atom(), String.t(), String.t()) :: {:ok, struct()} | {:error, atom()}
end
