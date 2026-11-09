defmodule Emergencias.Dominio.Reglas.TransicionesEstado do
  @moduledoc """
  Define y valida el grafo formal de transiciones de estado para las entidades de dominio.
  Utiliza mapas explícitos de transiciones válidas y detecta estados terminales cerrados.
  """

  alias Emergencias.Dominio.Modelos.{Necesidad, Persona, ReporteMascota}

  @transiciones_necesidad %{
    pendiente: MapSet.new([:asignada, :cancelada]),
    asignada: MapSet.new([:en_atencion, :cancelada]),
    en_atencion: MapSet.new([:atendida, :cancelada]),
    atendida: MapSet.new([]),
    cancelada: MapSet.new([])
  }

  @transiciones_mascota %{
    activa: MapSet.new([:posible_coincidencia, :resuelta]),
    posible_coincidencia: MapSet.new([:resuelta, :activa]),
    resuelta: MapSet.new([])
  }

  @transiciones_persona %{
    sin_informacion: MapSet.new([:reportada, :localizada]),
    reportada: MapSet.new([:localizada, :trasladada, :en_albergue]),
    localizada: MapSet.new([:trasladada, :en_albergue, :reunificada]),
    trasladada: MapSet.new([:en_albergue, :localizada, :reunificada]),
    en_albergue: MapSet.new([:reunificada, :trasladada]),
    reunificada: MapSet.new([])
  }

  @doc """
  Evaluar si es permitida la transición de un estado origen a un estado destino.
  """
  @spec poder_transitar?(atom(), atom(), atom()) :: boolean()
  def poder_transitar?(:necesidad, origen, destino) do
    origen
    |> obtener_transiciones_permitidas(@transiciones_necesidad)
    |> MapSet.member?(destino)
  end

  def poder_transitar?(:mascota, origen, destino) do
    origen
    |> obtener_transiciones_permitidas(@transiciones_mascota)
    |> MapSet.member?(destino)
  end

  def poder_transitar?(:persona, origen, destino) do
    origen
    |> obtener_transiciones_permitidas(@transiciones_persona)
    |> MapSet.member?(destino)
  end

  def poder_transitar?(_, _, _), do: false

  @doc """
  Verificar si un estado de una entidad es terminal (no permite más cambios).
  """
  @spec estar_cerrado?(atom(), atom()) :: boolean()
  def estar_cerrado?(:necesidad, estado), do: estado in [:atendida, :cancelada]
  def estar_cerrado?(:mascota, estado), do: estado == :resuelta
  def estar_cerrado?(:persona, estado), do: estado == :reunificada
  def estar_cerrado?(_, _), do: false

  @doc """
  Transitar una necesidad a un nuevo estado, agregando un evento al historial.
  """
  @spec transitar_necesidad(Necesidad.t(), Necesidad.estado(), String.t(), String.t()) ::
          {:ok, Necesidad.t()} | {:error, :transicion_invalida | :ya_cerrada}
  def transitar_necesidad(%Necesidad{estado: actual}, _nuevo, _usuario, _fecha)
      when actual in [:atendida, :cancelada] do
    {:error, :ya_cerrada}
  end

  def transitar_necesidad(%Necesidad{estado: actual} = nec, nuevo_estado, usuario, fecha) do
    if poder_transitar?(:necesidad, actual, nuevo_estado) do
      nuevo_evento = %{
        fecha: fecha,
        estado_anterior: actual,
        estado_nuevo: nuevo_estado,
        usuario: usuario
      }

      {:ok, %{nec | estado: nuevo_estado, historial: [nuevo_evento | nec.historial]}}
    else
      {:error, :transicion_invalida}
    end
  end

  @doc """
  Transitar una persona a un nuevo estado y actualizar ubicación/albergue.
  """
  @spec transitar_persona(Persona.t(), Persona.estado(), map(), String.t(), String.t()) ::
          {:ok, Persona.t()} | {:error, :transicion_invalida | :ya_cerrada}
  def transitar_persona(%Persona{estado: :reunificada}, _nuevo, _extras, _usuario, _fecha) do
    {:error, :ya_cerrada}
  end

  def transitar_persona(%Persona{estado: actual} = p, nuevo_estado, extras, usuario, fecha) do
    if poder_transitar?(:persona, actual, nuevo_estado) do
      nuevo_evento = %{
        fecha: fecha,
        estado_anterior: actual,
        estado_nuevo: nuevo_estado,
        usuario: usuario,
        detalles: Map.get(extras, :detalles, "Actualización de estado")
      }

      persona_actualizada = %{
        p
        | estado: nuevo_estado,
          ubicacion_actual: Map.get(extras, :ubicacion_actual, p.ubicacion_actual),
          codigo_albergue: Map.get(extras, :codigo_albergue, p.codigo_albergue),
          historial: [nuevo_evento | p.historial]
      }

      {:ok, persona_actualizada}
    else
      {:error, :transicion_invalida}
    end
  end

  @doc """
  Transitar un reporte de mascota a un nuevo estado.
  """
  @spec transitar_mascota(ReporteMascota.t(), ReporteMascota.estado(), String.t(), String.t()) ::
          {:ok, ReporteMascota.t()} | {:error, :transicion_invalida | :ya_cerrada}
  def transitar_mascota(%ReporteMascota{estado: :resuelta}, _nuevo, _usuario, _fecha) do
    {:error, :ya_cerrada}
  end

  def transitar_mascota(%ReporteMascota{estado: actual} = mascota, nuevo_estado, usuario, fecha) do
    if poder_transitar?(:mascota, actual, nuevo_estado) do
      nuevo_evento = %{
        fecha: fecha,
        estado_anterior: actual,
        estado_nuevo: nuevo_estado,
        usuario: usuario,
        detalles: "Cambio de estado a #{nuevo_estado}"
      }

      {:ok, %{mascota | estado: nuevo_estado, historial: [nuevo_evento | mascota.historial]}}
    else
      {:error, :transicion_invalida}
    end
  end

  defp obtener_transiciones_permitidas(estado, grafo) do
    Map.get(grafo, estado, MapSet.new())
  end
end
