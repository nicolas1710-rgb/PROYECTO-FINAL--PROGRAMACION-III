defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoAlbergues do
  @moduledoc "Puerto de salida para albergues temporales y aforo."
  @callback registrar(map()) :: {:ok, struct()} | {:error, atom()}
  @callback consultar(String.t()) :: {:ok, struct()} | {:error, atom()}
  @callback ingresar(String.t(), String.t()) :: {:ok, struct()} | {:error, atom()}
  @callback salir(String.t(), String.t()) :: {:ok, struct()} | {:error, atom()}
  @callback vincular_recurso(String.t(), String.t()) :: {:ok, struct()} | {:error, atom()}
  @callback vincular_necesidad(String.t(), String.t()) :: {:ok, struct()} | {:error, atom()}
  @callback listar() :: [struct()]
end
