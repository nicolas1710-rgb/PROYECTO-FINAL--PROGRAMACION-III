defmodule Emergencias.Aplicacion.Puertos.Entrada.PuertoMascotas do
  @moduledoc """
  Contrato del caso de uso de reporte, emparejamiento y resolución de mascotas.
  """

  alias Emergencias.Dominio.Modelos.ReporteMascota

  @callback reportar_mascota(map(), struct(), keyword()) ::
              {:ok, ReporteMascota.t()} | {:error, atom()}
  @callback emparejar_mascotas(struct(), keyword()) ::
              {:ok, list({ReporteMascota.t(), ReporteMascota.t(), non_neg_integer()})}
              | {:error, atom()}
  @callback resolver_mascota(String.t(), struct(), keyword()) ::
              {:ok, ReporteMascota.t()} | {:error, atom()}
end
