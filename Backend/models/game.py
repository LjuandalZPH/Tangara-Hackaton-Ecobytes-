"""
Modelo: GameScore
Guarda el puntaje de cada partida del módulo de gamificación.
"""

import uuid
from datetime import datetime
from sqlalchemy import Integer, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from db.database import Base


class GameScore(Base):
    __tablename__ = "game_scores"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    # Referencia al usuario que jugó
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    score: Mapped[int] = mapped_column(Integer, nullable=False)
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=True)

    played_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    # Relación inversa con el usuario
    user: Mapped["User"] = relationship("User", back_populates="scores")  # noqa: F821

    def __repr__(self) -> str:
        return f"<GameScore user={self.user_id} score={self.score}>"
