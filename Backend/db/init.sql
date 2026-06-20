-- Este script corre automáticamente cuando Docker crea la base de datos por primera vez.
-- Su único trabajo es activar la extensión PostGIS.

-- PostGIS: agrega soporte geográfico a PostgreSQL
-- (coordenadas, polígonos, consultas espaciales)
CREATE EXTENSION IF NOT EXISTS postgis;

-- uuid-ossp: genera UUIDs automáticamente para las claves primarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
