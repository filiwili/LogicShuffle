from datetime import datetime, timedelta
import uuid
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

def gen_uuid():
    return str(uuid.uuid4())

class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    username = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    score = db.Column(db.Integer, default=0)
    profile_image = db.Column(db.Text, nullable=True, default=None)

    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    reset_token_hash = db.Column(db.String(255), nullable=True)
    reset_token_expires_at = db.Column(db.DateTime, nullable=True)

    def to_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "score": self.score,
            "profile_image": self.profile_image or None,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
