defmodule Emergencias.Dominio.PermisosTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Reglas.Permisos

  test "ciudadano tiene permisos basicos pero no de coordinacion" do
    assert Permisos.tener_permiso?(:ciudadano, :registrar_necesidad)
    assert Permisos.tener_permiso?(:ciudadano, :reportar_persona)
    assert Permisos.tener_permiso?(:ciudadano, :buscar_persona)
    assert Permisos.tener_permiso?(:ciudadano, :enviar_mensaje)
    assert Permisos.tener_permiso?(:ciudadano, :reportar_mascota)

    refute Permisos.tener_permiso?(:ciudadano, :asignar_recurso)
    refute Permisos.tener_permiso?(:ciudadano, :registrar_zona)
    assert {:error, :sin_permiso} = Permisos.autorizar(:ciudadano, :asignar_recurso)
  end

  test "voluntario puede registrar entradas y salidas de albergue y recursos" do
    assert Permisos.tener_permiso?(:voluntario, :registrar_recurso)
    assert Permisos.tener_permiso?(:voluntario, :registrar_entrada_albergue)
    assert Permisos.tener_permiso?(:voluntario, :registrar_salida_albergue)

    refute Permisos.tener_permiso?(:voluntario, :asignar_recurso)
    refute Permisos.tener_permiso?(:voluntario, :registrar_zona)
  end

  test "coordinador y administrador tienen facultades superiores" do
    assert :ok == Permisos.autorizar(:coordinador, :asignar_recurso)
    assert :ok == Permisos.autorizar(:coordinador, :transferir_recurso)
    assert :ok == Permisos.autorizar(:coordinador, :emparejar_mascotas)
    assert :ok == Permisos.autorizar(:coordinador, :generar_resumen)

    assert :ok == Permisos.autorizar(:administrador, :cualquier_operacion_arbitraria)
  end
end
