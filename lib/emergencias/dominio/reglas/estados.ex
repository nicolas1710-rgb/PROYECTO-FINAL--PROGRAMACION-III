defmodule Emergencias.Dominio.Reglas.Estados do
  @moduledoc "Control de maquinas de estado y transiciones validas."

  @transiciones %{
    necesidad: %{
      pendiente: [:asignada, :cancelada],
      asignada: [:en_atencion, :atendida, :cancelada],
      en_atencion: [:atendida, :cancelada],
      atendida: [],
      cancelada: []
    },
    mascota: %{
      activa: [:posible_coincidencia, :resuelta],
      posible_coincidencia: [:resuelta, :activa],
      resuelta: []
    },
    persona: %{
      reportada: [:localizada, :trasladada, :en_albergue, :reunificada],
      localizada: [:trasladada, :en_albergue, :reunificada],
      trasladada: [:en_albergue, :reunificada],
      en_albergue: [:reunificada, :trasladada],
      reunificada: []
    }
  }

  @doc "Verificar si una entidad puede transitar de un estado a otro."
  def poder_transitar?(tipo_entidad, estado_actual, nuevo_estado) do
    permitidos = get_in(@transiciones, [tipo_entidad, estado_actual]) || []
    nuevo_estado in permitidos
  end

  @doc "Transitar una entidad a un nuevo estado registrando en su historial."
  def transitar(entidad, nuevo_estado, usuario, fecha) do
    tipo = tipo_de_entidad(entidad)
    actual = entidad.estado

    cond do
      actual in [:atendida, :cancelada, :resuelta, :reunificada] and actual == nuevo_estado ->
        {:error, :ya_cerrada}

      poder_transitar?(tipo, actual, nuevo_estado) ->
        evento = {fecha, actual, nuevo_estado, usuario}
        historial = [evento | Map.get(entidad, :historial, [])]
        {:ok, %{entidad | estado: nuevo_estado, historial: historial}}

      true ->
        {:error, :transicion_invalida}
    end
  end

  defp tipo_de_entidad(%Emergencias.Dominio.Modelos.Necesidad{}), do: :necesidad
  defp tipo_de_entidad(%Emergencias.Dominio.Modelos.Mascota{}), do: :mascota
  defp tipo_de_entidad(%Emergencias.Dominio.Modelos.Persona{}), do: :persona
end
