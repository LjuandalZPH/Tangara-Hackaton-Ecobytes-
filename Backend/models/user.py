"""
Modelo: User
Representa un usuario registrado en EcoBytes.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from db.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)

    # La contraseña se guarda como hash (nunca en texto plano)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    # Relación con los puntajes del juego
    scores: Mapped[list["GameScore"]] = relationship("GameScore", back_populates="user")  # noqa: F821

    def __repr__(self) -> str:
        return f"<User email={self.email}>"
