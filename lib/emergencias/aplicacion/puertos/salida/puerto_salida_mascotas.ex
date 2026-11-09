defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaMascotas do
  @moduledoc """
  Puerto de salida para el censo y emparejamiento de mascotas extraviadas y encontradas.
  """

  alias Emergencias.Dominio.Modelos.ReporteMascota

  @doc "Registrar un reporte de mascota perdida o encontrada."
  @callback reportar(map(), String.t()) :: {:ok, ReporteMascota.t()} | {:error, atom()}

  @doc "Calcular emparejamientos entre mascotas perdidas y encontradas según umbral de similitud."
  @callback emparejar(non_neg_integer()) ::
              {:ok, list({ReporteMascota.t(), ReporteMascota.t(), non_neg_integer()})}

  @doc "Resolver y cerrar un caso de mascota emparejada."
  @callback resolver(String.t(), String.t()) ::
              {:ok, ReporteMascota.t()} | {:error, atom()}

  @doc "Listar todos los reportes de mascotas."
  @callback listar() :: {:ok, list(ReporteMascota.t())}
end
