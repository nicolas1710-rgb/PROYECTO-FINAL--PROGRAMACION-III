defmodule Emergencias.Dominio.TransicionesEstadoTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Modelos.{Necesidad, Persona, ReporteMascota}
  alias Emergencias.Dominio.Reglas.TransicionesEstado

  setup do
    {:ok, necesidad} =
      Necesidad.construir(%{
        id: "N001",
        codigo_zona: "Z001",
        tipo_recurso: "agua",
        cantidad_solicitada: 50,
        prioridad: :critica,
        estado: :pendiente,
        fecha_registro: "2026-03-01T10:00:00Z",
        usuario_reporta: "U001"
      })

    {:ok, mascota} =
      ReporteMascota.construir(%{
        id: "MC001",
        tipo_reporte: :perdida,
        especie: "perro",
        color: "marron",
        tamano: :mediano,
        codigo_zona: "Z001",
        estado: :activa,
        usuario_reporta: "U001",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    {:ok, persona} =
      Persona.construir(%{
        id: "P001",
        documento: "10949001",
        nombre_completo: "Ana Maria",
        estado: :reportada,
        fecha_reporte: "2026-03-01T10:00:00Z"
      })

    %{necesidad: necesidad, mascota: mascota, persona: persona}
  end

  test "transicion valida e invalida de necesidad", %{necesidad: nec} do
    assert TransicionesEstado.poder_transitar?(:necesidad, :pendiente, :asignada)
    assert TransicionesEstado.poder_transitar?(:necesidad, :pendiente, :cancelada)
    refute TransicionesEstado.poder_transitar?(:necesidad, :pendiente, :atendida)

    assert {:ok, asignada} =
             TransicionesEstado.transitar_necesidad(
               nec,
               :asignada,
               "coordinador1",
               "2026-03-01T10:10:00Z"
             )

    assert asignada.estado == :asignada
    assert length(asignada.historial) == 1

    assert {:ok, en_atencion} =
             TransicionesEstado.transitar_necesidad(
               asignada,
               :en_atencion,
               "coordinador1",
               "2026-03-01T10:20:00Z"
             )

    assert {:ok, atendida} =
             TransicionesEstado.transitar_necesidad(
               en_atencion,
               :atendida,
               "coordinador1",
               "2026-03-01T10:30:00Z"
             )

    assert atendida.estado == :atendida
    assert TransicionesEstado.estar_cerrado?(:necesidad, :atendida)

    # Intento de reabrir o modificar una necesidad ya atendida
    assert {:error, :ya_cerrada} =
             TransicionesEstado.transitar_necesidad(
               atendida,
               :pendiente,
               "coordinador1",
               "2026-03-01T10:40:00Z"
             )
  end

  test "transicion de mascota activa hasta resuelta", %{mascota: m} do
    assert {:ok, m_posible} =
             TransicionesEstado.transitar_mascota(
               m,
               :posible_coincidencia,
               "U001",
               "2026-03-01T11:00:00Z"
             )

    assert {:ok, m_resuelta} =
             TransicionesEstado.transitar_mascota(
               m_posible,
               :resuelta,
               "U001",
               "2026-03-01T11:30:00Z"
             )

    assert m_resuelta.estado == :resuelta

    # No se puede volver a cerrar ni modificar una mascota resuelta
    assert {:error, :ya_cerrada} =
             TransicionesEstado.transitar_mascota(
               m_resuelta,
               :activa,
               "U001",
               "2026-03-01T12:00:00Z"
             )
  end

  test "transicion de persona a traves de su ciclo de atencion", %{persona: per} do
    assert {:ok, localizada} =
             TransicionesEstado.transitar_persona(
               per,
               :localizada,
               %{ubicacion_actual: "Sector Norte"},
               "coordinador1",
               "2026-03-01T12:00:00Z"
             )

    assert localizada.ubicacion_actual == "Sector Norte"

    assert {:ok, en_albergue} =
             TransicionesEstado.transitar_persona(
               localizada,
               :en_albergue,
               %{codigo_albergue: "ALB001"},
               "voluntario1",
               "2026-03-01T13:00:00Z"
             )

    assert en_albergue.codigo_albergue == "ALB001"

    assert {:ok, reunificada} =
             TransicionesEstado.transitar_persona(
               en_albergue,
               :reunificada,
               %{detalles: "Entregada a familiares"},
               "coordinador1",
               "2026-03-01T14:00:00Z"
             )

    assert reunificada.estado == :reunificada
    assert {:error, :ya_cerrada} =
             TransicionesEstado.transitar_persona(
               reunificada,
               :localizada,
               %{},
               "coordinador1",
               "2026-03-01T15:00:00Z"
             )
  end
end
