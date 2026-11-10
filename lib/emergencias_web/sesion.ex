defmodule EmergenciasWeb.Sesion do
  @moduledoc "Gestion de sesion de usuario para LiveViews mediante on_mount."
  import Phoenix.LiveView
  import Phoenix.Component

  @doc "Hook on_mount para exigir autenticacion en vistas protegidas."
  def on_mount(:exigir_sesion, _params, session, socket) do
    case Map.get(session, "usuario") do
      nil -> {:halt, redirect(socket, to: "/")}
      usuario -> {:cont, assign(socket, usuario: usuario)}
    end
  end

  def on_mount(:redirigir_autenticado, _params, session, socket) do
    case Map.get(session, "usuario") do
      nil -> {:cont, assign(socket, usuario: nil)}
      _usuario -> {:halt, redirect(socket, to: "/resumen")}
    end
  end
end
