# 🌿 EcoBytes — Backend

Stack: **FastAPI** + **PostgreSQL 15 + PostGIS** + **Docker**  
Equipo: Bit&Volt Labs | Hackathon Tángara 2026

---

## Levantar en desarrollo (3 pasos)

```bash
# 1. Clonar el repo
git clone https://github.com/bit-volt-labs/ecobytes.git
cd ecobytes

# 2. Configurar variables de entorno
cp backend/.env.example backend/.env
# Editar backend/.env con los valores reales

# 3. Levantar todo
docker compose up --build
```

La API queda disponible en:

- `http://localhost:8000` — API
- `http://localhost:8000/docs` — Documentación interactiva (Swagger)
- `http://localhost:8000/health` — Verificar que todo funciona

---

## Cargar datos históricos de Tángara

```bash
# Descargar CSV desde https://tangara.sebaxtian.dev/
# Luego correr desde la carpeta backend/:
python scripts/ingest_csv.py --file datos_tangara_2026_05.csv
```

---

## Estructura del proyecto

```scheme
ecobytes/
├── docker-compose.yml
├── .gitignore
└── backend/
    ├── Dockerfile
    ├── requirements.txt
    ├── .env.example
    ├── main.py                  ← punto de entrada FastAPI
    ├── db/
    │   ├── database.py          ← conexión y sesiones
    │   └── init.sql             ← activa PostGIS al crear la BD
    ├── models/
    │   ├── sensor.py            ← tabla sensor_readings
    │   ├── user.py              ← tabla users
    │   └── game.py              ← tabla game_scores
    ├── routers/
    │   ├── sensors.py           ← GET /sensors/latest, /history, WS /ws/live
    │   ├── auth.py              ← stub Sprint 3
    │   ├── chatbot.py           ← stub Sprint 3
    │   └── game.py              ← stub Sprint 4
    ├── services/
    │   └── calibration.py       ← algoritmo de corrección PM2.5
    └── scripts/
        └── ingest_csv.py        ← carga CSV histórico de Tángara
```

---

## Comandos útiles

```bash
# Ver logs del backend en tiempo real
docker compose logs -f api

# Apagar todo
docker compose down

# Apagar y borrar la base de datos (fresh start)
docker compose down -v

# Entrar a la consola de PostgreSQL
docker compose exec db psql -U ecobytes_user -d ecobytes
```

---

*Hecho con 💚 en Cali, Colombia.*
