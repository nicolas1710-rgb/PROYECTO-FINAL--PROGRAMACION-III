defmodule EmergenciasWeb.SesionController do
  @moduledoc "Controlador para autenticar usuarios y persistir la sesion firmada."
  use EmergenciasWeb, :controller
  alias Emergencias.Aplicacion.CasosUso.GestionarUsuarios
  alias Emergencias.Infraestructura.MensajesError

  @doc "Iniciar sesion invocando el caso de uso y guardando el usuario en cookie."
  def iniciar(conn, %{"usuario" => nom, "clave" => clave} = p) do
    case GestionarUsuarios.conectar(nom, clave, Map.get(p, "rol", "ciudadano")) do
      {:ok, usr} ->
        conn
        |> put_session("usuario", Map.put(usr, :zona, Map.get(p, "zona", "Z001")))
        |> configure_session(renew: true)
        |> put_flash(:info, "Bienvenido/a, #{usr.nombre} (#{usr.rol}).")
        |> redirect(to: ~p"/resumen")
      {:error, r} ->
        conn |> put_flash(:error, MensajesError.obtener_mensaje(r)) |> redirect(to: ~p"/")
    end
  end

  @doc "Cerrar la sesion activa y redirigir al login."
  def cerrar(conn, _params) do
    if usr = get_session(conn, "usuario"), do: GestionarUsuarios.desconectar(usr)
    conn |> clear_session() |> put_flash(:info, "Sesion finalizada con exito.") |> redirect(to: ~p"/")
  end
end
