defmodule Emergencias.Infraestructura.AnalizadorComandosTest do
  use ExUnit.Case, async: true

  alias Emergencias.Infraestructura.Entrada.AnalizadorComandos

  test "analizar comando basico sin argumentos" do
    assert {:ok, :help, []} = AnalizadorComandos.analizar_linea("help")
    assert {:ok, :exit, []} = AnalizadorComandos.analizar_linea("exit")
    assert {:ok, :summary, []} = AnalizadorComandos.analizar_linea("summary")
  end

  test "analizar comando con argumentos simples y cadenas con comillas" do
    linea = ~s(send_family_message 10949001 "Hola familia, estamos a salvo")
    assert {:ok, :send_family_message, ["10949001", "Hola familia, estamos a salvo"]} =
             AnalizadorComandos.analizar_linea(linea)

    linea_mascota = ~s(report_pet perdida perro "marron oscuro" grande Z001 "Firulais")
    assert {:ok, :report_pet, ["perdida", "perro", "marron oscuro", "grande", "Z001", "Firulais"]} =
             AnalizadorComandos.analizar_linea(linea_mascota)
  end

  test "analizar pares clave=valor para filtros" do
    linea = "list_needs zona=Z001 prioridad=critica estado=pendiente"
    assert {:ok, :list_needs, [{:zona, "Z001"}, {:prioridad, "critica"}, {:estado, "pendiente"}]} =
             AnalizadorComandos.analizar_linea(linea)
  end

  test "normalizar identificadores informales a mayusculas con prefijo" do
    assert AnalizadorComandos.normalizar_identificador("need1") == "N001"
    assert AnalizadorComandos.normalizar_identificador("n25") == "N025"
    assert AnalizadorComandos.normalizar_identificador("res2") == "R002"
    assert AnalizadorComandos.normalizar_identificador("r10") == "R010"
    assert AnalizadorComandos.normalizar_identificador("zone3") == "Z003"
    assert AnalizadorComandos.normalizar_identificador("pet1") == "MC001"
    assert AnalizadorComandos.normalizar_identificador("shelter4") == "ALB004"
  end

  test "manejo de lineas vacias y comandos desconocidos" do
    assert {:error, :linea_vacia} = AnalizadorComandos.analizar_linea("")
    assert {:error, :linea_vacia} = AnalizadorComandos.analizar_linea("   ")
    assert {:error, :comando_desconocido} = AnalizadorComandos.analizar_linea("comando_inexistente arg1")
  end
end
