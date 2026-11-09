defmodule Emergencias.Infraestructura.PersistenciaTest do
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.Modelos.{Recurso, Usuario}
  alias Emergencias.Infraestructura.Salida.Persistencia.AlmacenArchivo

  @dir_prueba "datos_prueba_persistencia"

  setup do
    File.rm_rf!(@dir_prueba)
    File.mkdir_p!(@dir_prueba)
    Application.put_env(:emergencias, :directorio_datos, @dir_prueba)

    on_exit(fn ->
      File.rm_rf!(@dir_prueba)
      Application.put_env(:emergencias, :directorio_datos, "datos")
    end)

    %{dir: @dir_prueba}
  end

  test "archivo inexistente retorna {:ok, []} sin crashear" do
    assert {:ok, []} = AlmacenArchivo.cargar(:zonas)
    assert {:ok, []} = AlmacenArchivo.cargar(:necesidades)
  end

  test "guardado atomico y recuperacion integra de usuarios" do
    {:ok, u1} =
      Usuario.construir(%{
        id: "U001",
        nombre: "Laura",
        rol: :coordinador,
        clave_hash: "hash1",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    {:ok, u2} =
      Usuario.construir(%{
        id: "U002",
        nombre: "Carlos",
        rol: :voluntario,
        clave_hash: "hash2",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    assert :ok = AlmacenArchivo.guardar(:usuarios, [u1, u2])

    ruta_archivo = Path.join(@dir_prueba, "usuarios.txt")
    assert File.exists?(ruta_archivo)

    assert {:ok, cargados} = AlmacenArchivo.cargar(:usuarios)
    assert length(cargados) == 2
    assert Enum.map(cargados, & &1.nombre) == ["Laura", "Carlos"]
  end

  test "actualizar un unico registro reemplaza el existente sin duplicar" do
    {:ok, r1} =
      Recurso.construir(%{
        id: "R001",
        tipo: "agua",
        unidad_medida: "litros",
        cantidad_total: 50,
        cantidad_disponible: 50,
        codigo_zona: "Z001",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    AlmacenArchivo.guardar(:recursos, [r1])

    {:ok, r1_mod} =
      Recurso.construir(%{
        id: "R001",
        tipo: "agua",
        unidad_medida: "litros",
        cantidad_total: 50,
        cantidad_disponible: 20,
        codigo_zona: "Z001",
        fecha_registro: "2026-03-01T10:00:00Z"
      })

    AlmacenArchivo.guardar(:recursos, r1_mod)

    {:ok, recursos} = AlmacenArchivo.cargar(:recursos)
    assert length(recursos) == 1
    [recuperado] = recursos
    assert recuperado.cantidad_disponible == 20
  end
end
