defmodule Emergencias.Dominio.Modelos.Usuario do
  @moduledoc "Representa un usuario del sistema con su rol y clave cifrada."
  @enforce_keys [:id, :nombre, :rol, :clave_hash]
  defstruct [:id, :nombre, :rol, :clave_hash, :fecha_registro]

  @doc "Construir un usuario validando sus campos minimos."
  def construir(attrs) when is_map(attrs) do
    {:ok, struct(__MODULE__, attrs)}
  end
end
