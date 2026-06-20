# Imagen base oficial de Python (slim = más liviana)
FROM python:3.12-slim

# Directorio de trabajo dentro del contenedor
WORKDIR /app

# Instalar dependencias del sistema necesarias para psycopg2 (driver de PostgreSQL)
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copiar e instalar dependencias de Python primero
# (esto se cachea en Docker si requirements.txt no cambia — builds más rápidos)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el resto del código
COPY . .

# Puerto que expone el contenedor
EXPOSE 8000

# Comando por defecto (puede ser sobreescrito en docker-compose.yml)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
