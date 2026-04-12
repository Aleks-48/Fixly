"""
FastAPI + YOLOv8 Backend для Fixly — определение неисправностей
===============================================================

Установка:
    pip install fastapi uvicorn ultralytics pillow python-multipart

Запуск:
    uvicorn main:app --host 0.0.0.0 --port 8000

Для продакшн:
    uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2

Модель:
    - По умолчанию используется yolov8n.pt (предобученная на COCO)
    - Для точного определения дефектов ЖКХ — нужно дообучить на своём датасете
    - Датасет: фото протечек, трещин, электрики и т.д.
    - Рекомендуется: Roboflow для разметки данных
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import io
import time
from PIL import Image
from typing import Optional

# ── YOLOv8 ────────────────────────────────────────────────
try:
    from ultralytics import YOLO
    MODEL_LOADED = True
except ImportError:
    print("⚠ ultralytics not installed. Using mock responses.")
    MODEL_LOADED = False

app = FastAPI(
    title="Fixly Defect Detection API",
    description="YOLOv8 API для распознавания неисправностей в ЖК",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Загрузка модели ────────────────────────────────────────
# Замени на путь к своей дообученной модели:
# model = YOLO("models/fixly_defects_v1.pt")
# 
# Для тестирования используем стандартную YOLOv8:
model = YOLO("yolov8n.pt") if MODEL_LOADED else None

# ── Маппинг классов COCO → дефекты ЖКХ ───────────────────
# Если используешь стандартную модель, нужно адаптировать классы.
# Для дообученной модели — классы будут свои.
DEFECT_CLASS_MAP = {
    # COCO classes → наши дефекты (для тестирования)
    "sink"      : "water_leak",
    "toilet"    : "water_leak",
    "vase"      : "pipe_crack",
    # После дообучения будут прямые классы:
    "water_leak"      : "water_leak",
    "pipe_crack"      : "pipe_crack",
    "electrical_spark": "electrical_spark",
    "broken_socket"   : "broken_socket",
    "mold"            : "mold",
    "wall_crack"      : "wall_crack",
    "broken_window"   : "broken_window",
    "door_damage"     : "door_damage",
    "ceiling_damage"  : "ceiling_damage",
    "floor_damage"    : "floor_damage",
    "gas_meter_issue" : "gas_meter_issue",
}

# ── Mock-данные для тестирования без дообученной модели ───
MOCK_DETECTIONS = [
    {
        "label"     : "water_leak",
        "confidence": 0.87,
        "box"       : [0.1, 0.2, 0.6, 0.8],
    },
    {
        "label"     : "mold",
        "confidence": 0.62,
        "box"       : [0.5, 0.3, 0.9, 0.7],
    },
]


@app.get("/")
def root():
    return {
        "service"   : "Fixly Defect Detection API",
        "version"   : "1.0.0",
        "model"     : "YOLOv8" if MODEL_LOADED else "Mock mode",
        "status"    : "running",
    }


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": MODEL_LOADED}


@app.post("/detect")
async def detect_defects(
    image              : UploadFile = File(...),
    confidence_threshold: float      = Form(0.4),
    max_detections      : int        = Form(10),
    use_mock            : bool       = Form(False),
):
    """
    Принимает изображение и возвращает список обнаруженных дефектов.

    Returns:
        {
            "detections": [
                {
                    "label": "water_leak",
                    "confidence": 0.87,
                    "box": [x1, y1, x2, y2]  # нормализованные 0..1
                }
            ],
            "count"     : 2,
            "image_size": [640, 480],
            "process_ms": 142
        }
    """
    start_time = time.time()

    # Проверка типа файла
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Файл должен быть изображением")

    # Читаем изображение
    try:
        contents = await image.read()
        pil_image = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Не удалось открыть изображение: {e}")

    img_width, img_height = pil_image.size

    # ── Mock-режим ─────────────────────────────────────────
    if use_mock or not MODEL_LOADED:
        process_ms = int((time.time() - start_time) * 1000) + 300
        return JSONResponse({
            "detections" : MOCK_DETECTIONS[:max_detections],
            "count"      : len(MOCK_DETECTIONS),
            "image_size" : [img_width, img_height],
            "process_ms" : process_ms,
            "model"      : "mock",
        })

    # ── YOLOv8 детекция ────────────────────────────────────
    try:
        results = model.predict(
            source    = pil_image,
            conf      = confidence_threshold,
            verbose   = False,
            max_det   = max_detections,
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка модели: {e}"
        )

    detections = []
    for result in results:
        if result.boxes is None:
            continue
        for box in result.boxes:
            # YOLO возвращает [x1, y1, x2, y2] в пикселях
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            conf_val  = float(box.conf[0])
            class_idx = int(box.cls[0])
            class_name = result.names.get(class_idx, "unknown")

            # Маппинг класса → дефект
            defect_label = DEFECT_CLASS_MAP.get(class_name, "unknown")

            if conf_val >= confidence_threshold:
                detections.append({
                    "label"     : defect_label,
                    "confidence": round(conf_val, 3),
                    "box"       : [
                        round(x1 / img_width,  4),
                        round(y1 / img_height, 4),
                        round(x2 / img_width,  4),
                        round(y2 / img_height, 4),
                    ],
                    "class_name": class_name,  # оригинальный класс YOLO
                })

    # Сортируем по уверенности
    detections.sort(key=lambda d: d["confidence"], reverse=True)
    detections = detections[:max_detections]

    process_ms = int((time.time() - start_time) * 1000)

    return JSONResponse({
        "detections" : detections,
        "count"      : len(detections),
        "image_size" : [img_width, img_height],
        "process_ms" : process_ms,
        "model"      : "yolov8",
    })


@app.post("/detect/test")
async def test_detection():
    """Тестовый эндпоинт — возвращает mock данные без изображения"""
    return JSONResponse({
        "detections": MOCK_DETECTIONS,
        "count"     : len(MOCK_DETECTIONS),
        "image_size": [640, 480],
        "process_ms": 45,
        "model"     : "mock",
    })


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
