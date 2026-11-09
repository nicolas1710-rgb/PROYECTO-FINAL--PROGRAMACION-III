defmodule Emergencias.Aplicacion.CasosUso.GestionarUsuarios do
  @moduledoc "Casos de uso para autenticacion y consulta de usuarios del sistema."

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.Validaciones

  @doc "Conectar un usuario validando credenciales o registrandolo si es nuevo."
  def conectar(nombre, clave, rol_str, opts \\ []) do
    with {:ok, nom} <- Validaciones.validar_no_vacio(nombre),
         {:ok, pass} <- Validaciones.validar_no_vacio(clave),
         {:ok, rol} <- Validaciones.validar_rol(rol_str) do
      puerto = resolver_puerto(opts, :puerto_usuarios)
      puerto.conectar(nom, pass, rol)
    end
  end

  @doc "Cerrar sesion de un usuario conectado."
  def desconectar(%Usuario{} = u, opts \\ []) do
    puerto = resolver_puerto(opts, :puerto_usuarios)
    puerto.desconectar(u.nombre)
  end

  @doc "Listar usuarios registrados en el sistema."
  def listar_usuarios(%Usuario{}, opts \\ []) do
    puerto = resolver_puerto(opts, :puerto_usuarios)
    {:ok, puerto.listar()}
  end

  defp resolver_puerto(opts, clave) do
    Keyword.get(opts, clave, Application.get_env(:emergencias, clave))
  end
end
