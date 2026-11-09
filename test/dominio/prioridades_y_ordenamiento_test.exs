defmodule Emergencias.Dominio.PrioridadesYOrdenamientoTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Modelos.Necesidad
  alias Emergencias.Dominio.Reglas.{Ordenamiento, Prioridades}

  test "pesos y comparacion de prioridades" do
    assert Prioridades.obtener_peso(:critica) == 4
    assert Prioridades.obtener_peso(:alta) == 3
    assert Prioridades.obtener_peso(:media) == 2
    assert Prioridades.obtener_peso(:baja) == 1

    assert Prioridades.comparar_prioridades(:critica, :alta) == :mayor
    assert Prioridades.comparar_prioridades(:baja, :media) == :menor
    assert Prioridades.comparar_prioridades(:alta, :alta) == :igual
  end

  test "ordenamiento merge sort puro sobre listas genericas" do
    # Caso base
    assert Ordenamiento.ordenar_merge_sort([], &(&1 <= &2)) == []
    assert Ordenamiento.ordenar_merge_sort([42], &(&1 <= &2)) == [42]

    # Caso recursivo con desorden
    lista = [5, 2, 9, 1, 5, 6]
    assert Ordenamiento.ordenar_merge_sort(lista, &(&1 <= &2)) == [1, 2, 5, 5, 6, 9]
  end

  test "ordenar necesidades por prioridad descendente y fecha ascendente" do
    {:ok, n1} =
      Necesidad.construir(%{
        id: "N001",
        codigo_zona: "Z001",
        tipo_recurso: "agua",
        cantidad_solicitada: 10,
        prioridad: :media,
        estado: :pendiente,
        fecha_registro: "2026-03-01T10:00:00Z",
        usuario_reporta: "U001"
      })

    {:ok, n2} =
      Necesidad.construir(%{
        id: "N002",
        codigo_zona: "Z001",
        tipo_recurso: "medicamentos",
        cantidad_solicitada: 5,
        prioridad: :critica,
        estado: :pendiente,
        fecha_registro: "2026-03-01T10:30:00Z",
        usuario_reporta: "U001"
      })

    {:ok, n3} =
      Necesidad.construir(%{
        id: "N003",
        codigo_zona: "Z001",
        tipo_recurso: "carpas",
        cantidad_solicitada: 20,
        prioridad: :critica,
        estado: :pendiente,
        fecha_registro: "2026-03-01T10:15:00Z",
        usuario_reporta: "U001"
      })

    {:ok, n4} =
      Necesidad.construir(%{
        id: "N004",
        codigo_zona: "Z001",
        tipo_recurso: "frazadas",
        cantidad_solicitada: 10,
        prioridad: :baja,
        estado: :pendiente,
        fecha_registro: "2026-03-01T09:00:00Z",
        usuario_reporta: "U001"
      })

    ordenadas = Ordenamiento.ordenar_por_prioridad([n1, n2, n3, n4])

    # n3 y n2 son :critica, pero n3 tiene fecha 10:15 vs n2 con 10:30 (más antigua primero)
    # luego n1 (:media), luego n4 (:baja)
    assert Enum.map(ordenadas, & &1.id) == ["N003", "N002", "N001", "N004"]
  end
end
