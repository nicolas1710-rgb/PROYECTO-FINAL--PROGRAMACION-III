defmodule Emergencias.Dominio.Modelos.Usuario do
  @moduledoc """
  Representa un usuario registrado en el sistema con su rol y credencial cifrada.
  """

  @enforce_keys [:id, :nombre, :rol, :clave_hash, :fecha_registro]
  defstruct [:id, :nombre, :rol, :clave_hash, :fecha_registro]

  @type rol :: :ciudadano | :voluntario | :coordinador | :administrador

  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t(),
          rol: rol(),
          clave_hash: String.t(),
          fecha_registro: String.t()
        }

  @doc """
  Construir una nueva instancia del modelo de usuario.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       nombre: Map.fetch!(atributos, :nombre),
       rol: Map.fetch!(atributos, :rol),
       clave_hash: Map.fetch!(atributos, :clave_hash),
       fecha_registro: Map.fetch!(atributos, :fecha_registro)
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
