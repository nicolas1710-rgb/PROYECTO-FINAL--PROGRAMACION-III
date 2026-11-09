defmodule Emergencias.Aplicacion.Puertos.Entrada.PuertoNecesidades do
  @moduledoc """
  Contrato del caso de uso de gestión de necesidades humanitarias.
  """

  alias Emergencias.Dominio.Modelos.Necesidad

  @callback registrar_necesidad(map(), struct(), keyword()) :: {:ok, Necesidad.t()} | {:error, atom()}
  @callback listar_necesidades(keyword(), struct()) :: {:ok, list(Necesidad.t())} | {:error, atom()}
  @callback actualizar_necesidad(String.t(), atom(), struct(), keyword()) ::
              {:ok, Necesidad.t()} | {:error, atom()}
end
