defmodule Emergencias.Dominio.ValidacionesTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Reglas.Validaciones

  test "validar texto no vacio" do
    assert {:ok, "Armenia"} = Validaciones.validar_texto_no_vacio("  Armenia  ")
    assert {:error, :texto_vacio} = Validaciones.validar_texto_no_vacio("   ")
    assert {:error, :texto_vacio} = Validaciones.validar_texto_no_vacio(nil)
    assert {:error, :texto_vacio} = Validaciones.validar_texto_no_vacio(123)
  end

  test "validar cantidad positiva y no negativa" do
    assert {:ok, 10} = Validaciones.validar_cantidad_positiva(10)
    assert {:error, :cantidad_invalida} = Validaciones.validar_cantidad_positiva(0)
    assert {:error, :cantidad_invalida} = Validaciones.validar_cantidad_positiva(-5)

    assert {:ok, 0} = Validaciones.validar_cantidad_no_negativa(0)
    assert {:ok, 25} = Validaciones.validar_cantidad_no_negativa(25)
    assert {:error, :cantidad_negativa} = Validaciones.validar_cantidad_no_negativa(-1)
  end

  test "validar nivel de gravedad y prioridad" do
    assert {:ok, :critico} = Validaciones.validar_nivel_gravedad(:critico)
    assert {:ok, :alto} = Validaciones.validar_nivel_gravedad("ALTO")
    assert {:error, :nivel_invalido} = Validaciones.validar_nivel_gravedad(:inexistente)

    assert {:ok, :critica} = Validaciones.validar_prioridad(:critica)
    assert {:ok, :baja} = Validaciones.validar_prioridad("baja")
    assert {:error, :prioridad_invalida} = Validaciones.validar_prioridad(:urgente)
  end

  test "validar rol, tamano mascota y tipo reporte" do
    assert {:ok, :coordinador} = Validaciones.validar_rol("coordinador")
    assert {:error, :rol_invalido} = Validaciones.validar_rol("superusuario")

    assert {:ok, :pequeno} = Validaciones.validar_tamano_mascota("pequeno")
    assert {:ok, :perdida} = Validaciones.validar_tipo_reporte_mascota("perdida")
    assert {:ok, :encontrada} = Validaciones.validar_tipo_reporte_mascota(:encontrada)
  end

  test "validar id unico en mapas y conjuntos" do
    existentes = MapSet.new(["N001", "N002"])
    assert {:ok, "N003"} = Validaciones.validar_id_unico("N003", existentes)
    assert {:error, :id_duplicado} = Validaciones.validar_id_unico("N001", existentes)

    mapa = %{"Z001" => true}
    assert {:ok, "Z002"} = Validaciones.validar_id_unico("Z002", mapa)
    assert {:error, :id_duplicado} = Validaciones.validar_id_unico("Z001", mapa)
  end
end
