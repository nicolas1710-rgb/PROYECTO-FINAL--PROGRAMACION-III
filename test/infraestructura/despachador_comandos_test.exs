defmodule Emergencias.Infraestructura.DespachadorComandosTest do
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Infraestructura.Entrada.DespachadorComandos

  setup do
    {:ok, admin} =
      Usuario.construir(%{
        id: "U001",
        nombre: "AdminTest",
        rol: :administrador,
        clave_hash: "hash",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    %{admin: admin}
  end

  test "despachar help y exit sin autenticacion" do
    assert {:ok, texto, nil} = DespachadorComandos.despachar_comando(:help, [], nil)
    assert String.contains?(texto, "COMANDOS DISPONIBLES")

    assert {:salir, despedida} = DespachadorComandos.despachar_comando(:exit, [], nil)
    assert String.contains?(despedida, "¡Hasta pronto!")
  end

  test "rechazar comandos protegidos si usuario es nil" do
    assert {:error, mensaje, nil} =
             DespachadorComandos.despachar_comando(:register_zone, ["Sur", "medio"], nil)

    assert String.contains?(mensaje, "Debes iniciar sesión")
  end

  test "despachar comando disconnect con y sin sesion", %{admin: admin} do
    assert {:error, msg, nil} = DespachadorComandos.despachar_comando(:disconnect, [], nil)
    assert String.contains?(msg, "Debes iniciar sesión")

    assert {:ok, msg_ok, nil} = DespachadorComandos.despachar_comando(:disconnect, [], admin)
    assert String.contains?(msg_ok, "cerrada correctamente")
  end

  test "despachar connect con argumentos invalidos" do
    assert {:error, msg, nil} = DespachadorComandos.despachar_comando(:connect, ["solo_nombre"], nil)
    assert String.contains?(msg, "Sintaxis o cantidad de argumentos incorrecta")
  end

  test "entradas numericas no enteras no tumban la consola", %{admin: admin} do
    # assign_resource con cantidad no entera
    assert {:error, msg, ^admin} =
             DespachadorComandos.despachar_comando(:assign_resource, ["R001", "N001", "abc"], admin)
    assert String.contains?(msg, "estrictamente positivo")

    # register_need con cantidad no entera
    assert {:error, msg_need, ^admin} =
             DespachadorComandos.despachar_comando(:register_need, ["Z001", "agua", "xyz", "alta"], admin)
    assert String.contains?(msg_need, "estrictamente positivo")

    # register_resource con cantidad no entera
    assert {:error, msg_rec, ^admin} =
             DespachadorComandos.despachar_comando(:register_resource, ["agua", "litros", "invalido", "Z001"], admin)
    assert String.contains?(msg_rec, "estrictamente positivo")

    # register_shelter con capacidad no entera
    assert {:error, msg_alb, ^admin} =
             DespachadorComandos.despachar_comando(:register_shelter, ["Refugio", "Z001", "no_entero"], admin)
    assert String.contains?(msg_alb, "estrictamente positivo")

    # match_pets con umbral no entero
    assert {:error, msg_pets, ^admin} =
             DespachadorComandos.despachar_comando(:match_pets, ["no_es_numero"], admin)
    assert String.contains?(msg_pets, "número entero válido")

    # critical_resources con umbral no entero
    assert {:error, msg_crit, ^admin} =
             DespachadorComandos.despachar_comando(:critical_resources, ["invalido"], admin)
    assert String.contains?(msg_crit, "número entero válido")

    # register_zone con gravedad invalida
    assert {:error, msg_zona, ^admin} =
             DespachadorComandos.despachar_comando(:register_zone, ["Centro", "gravedad_inexistente"], admin)
    assert String.contains?(msg_zona, "Nivel de gravedad inválido")
  end
end
