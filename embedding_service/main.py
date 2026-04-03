from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
import numpy as np
import re

app = FastAPI()

model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")

CATEGORIES = ["Музыка", "Искусство", "Подкасты", "Игры", "Образование", "Другое"]
# Category signal amplified so it has meaningful weight alongside 384-dim text vector
CATEGORY_WEIGHT = 3.0


def category_vector(category: str) -> list[float]:
    vec = [0.0] * len(CATEGORIES)
    if category in CATEGORIES:
        vec[CATEGORIES.index(category)] = CATEGORY_WEIGHT
    return vec


def strip_html(text: str) -> str:
    clean = re.sub(r"<[^>]+>", " ", text)
    return re.sub(r"\s+", " ", clean).strip()


class EmbedRequest(BaseModel):
    title: str
    content: str = ""
    category: str = ""


class EmbedResponse(BaseModel):
    vector: list[float]  # 390 dims: 384 text + 6 category


@app.post("/embed", response_model=EmbedResponse)
def embed(req: EmbedRequest):
    text = (req.title + " " + strip_html(req.content)).strip()
    text_vec: list[float] = model.encode(text, normalize_embeddings=True).tolist()  # 384
    cat_vec = category_vector(req.category)  # 6
    return {"vector": text_vec + cat_vec}  # 390


class UpdateUserRequest(BaseModel):
    current_vector: list[float]  # empty list if no prior vector
    post_vector: list[float]
    alpha: float = 0.3  # learning rate — how fast user preference shifts


@app.post("/user/update")
def update_user_vector(req: UpdateUserRequest):
    post_vec = np.array(req.post_vector, dtype=np.float32)
    if not req.current_vector:
        result = post_vec
    else:
        curr = np.array(req.current_vector, dtype=np.float32)
        # Exponential moving average: shifts preference toward recently liked content
        result = req.alpha * post_vec + (1.0 - req.alpha) * curr
    norm = float(np.linalg.norm(result))
    if norm > 0:
        result = result / norm
    return {"vector": result.tolist()}


@app.get("/health")
def health():
    return {"ok": True}
