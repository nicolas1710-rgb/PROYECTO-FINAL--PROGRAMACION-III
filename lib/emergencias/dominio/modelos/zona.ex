defmodule Emergencias.Dominio.Modelos.PuntoAtencion do
  @moduledoc "Punto de atencion especifico dentro de un sector."
  defstruct [:id, :nombre, personas_afectadas: 0]
end

defmodule Emergencias.Dominio.Modelos.Sector do
  @moduledoc "Sector barrial o funcional dentro de una zona."
  defstruct [:id, :nombre, personas_afectadas: 0, puntos_atencion: []]
end

defmodule Emergencias.Dominio.Modelos.Zona do
  @moduledoc "Zona territorial afectada con sectores y puntos anidados."
  defstruct [:id, :nombre, :nivel_gravedad, personas_afectadas: 0, sectores: [], fecha_registro: nil]

  @doc "Construir una zona base con lista de sectores vacia."
  def construir(attrs) when is_map(attrs) do
    {:ok, struct(__MODULE__, Map.put_new(attrs, :sectores, []))}
  end
end
