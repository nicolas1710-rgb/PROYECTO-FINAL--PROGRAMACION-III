defmodule EmergenciasWeb.Notificador do
  @moduledoc "Modulo de publicacion y suscripcion a eventos de tiempo real con Phoenix.PubSub."

  @topico "emergencias"

  @doc "Suscribir el proceso actual a los eventos de emergencias."
  def suscribir do
    Phoenix.PubSub.subscribe(Emergencias.PubSub, @topico)
  end

  @doc "Difundir un cambio de estado hacia todas las vistas conectadas."
  def difundir_cambio(tema) do
    Phoenix.PubSub.broadcast(Emergencias.PubSub, @topico, {:cambio, tema})
  end
end
