import Config

config :emergencias,
  puerto_usuarios: Emergencias.Infraestructura.Procesos.GestorUsuarios,
  puerto_zonas: Emergencias.Infraestructura.Procesos.GestorZonas,
  puerto_logistica: Emergencias.Infraestructura.Procesos.GestorLogistica,
  puerto_personas: Emergencias.Infraestructura.Procesos.GestorPersonas,
  puerto_mascotas: Emergencias.Infraestructura.Procesos.GestorMascotas,
  puerto_albergues: Emergencias.Infraestructura.Procesos.SupervisorAlbergues,
  puerto_bitacora: Emergencias.Infraestructura.Procesos.Bitacora,
  directorio_datos: "datos"
