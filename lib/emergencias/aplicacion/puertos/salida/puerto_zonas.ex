defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoZonas do
  @moduledoc "Puerto de salida para registro y consulta territorial de zonas."
  @callback registrar_zona(map()) :: {:ok, struct()} | {:error, atom()}
  @callback registrar_sector(String.t(), map()) :: {:ok, struct()} | {:error, atom()}
  @callback registrar_punto(String.t(), String.t(), map()) :: {:ok, struct()} | {:error, atom()}
  @callback consultar(String.t()) :: {:ok, struct()} | {:error, atom()}
  @callback listar() :: [struct()]
end
