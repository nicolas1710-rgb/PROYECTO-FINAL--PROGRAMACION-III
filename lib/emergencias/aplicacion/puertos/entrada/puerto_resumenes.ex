defmodule Emergencias.Aplicacion.Puertos.Entrada.PuertoResumenes do
  @moduledoc """
  Contrato del caso de uso de consolidación de resúmenes ejecutivos e indicadores.
  """

  alias Emergencias.Dominio.Modelos.{Necesidad, Recurso}

  @callback generar_resumen(struct(), keyword()) :: {:ok, map()} | {:error, atom()}
  @callback listar_recursos_criticos(non_neg_integer(), struct(), keyword()) ::
              {:ok, list(Recurso.t())} | {:error, atom()}
  @callback listar_necesidades_pendientes(struct(), keyword()) ::
              {:ok, list(Necesidad.t())} | {:error, atom()}
end
