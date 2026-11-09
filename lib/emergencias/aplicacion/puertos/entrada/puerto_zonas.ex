defmodule Emergencias.Aplicacion.Puertos.Entrada.PuertoZonas do
  @moduledoc """
  Contrato del caso de uso de gestión territorial de zonas.
  """

  alias Emergencias.Dominio.Modelos.Zona

  @callback registrar_zona(map(), struct(), keyword()) :: {:ok, Zona.t()} | {:error, atom()}
  @callback consultar_zona(String.t(), struct()) :: {:ok, Zona.t()} | {:error, atom()}
  @callback listar_zonas(struct()) :: {:ok, list(Zona.t())} | {:error, atom()}
end
