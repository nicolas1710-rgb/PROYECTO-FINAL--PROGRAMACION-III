defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaUsuarios do
  @moduledoc """
  Puerto de salida para la autenticación, registro y consulta de usuarios del sistema.
  """

  alias Emergencias.Dominio.Modelos.Usuario

  @doc "Autenticar un usuario existente o registrar uno nuevo si no existe."
  @callback conectar(String.t(), String.t(), atom()) :: {:ok, Usuario.t()} | {:error, atom()}

  @doc "Cerrar la sesión activa del usuario."
  @callback desconectar(String.t()) :: :ok

  @doc "Listar todos los usuarios registrados."
  @callback listar() :: {:ok, list(Usuario.t())}

  @doc "Consultar un usuario por su nombre de usuario."
  @callback consultar(String.t()) :: {:ok, Usuario.t()} | {:error, atom()}

  @doc "Registrar un nuevo usuario en el sistema."
  @callback registrar(Usuario.t()) :: {:ok, Usuario.t()} | {:error, atom()}
end
