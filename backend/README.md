# Backend

FastAPI backend for the Android MVP.

## Quick Start

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Open:

```text
http://127.0.0.1:8000/docs
http://127.0.0.1:8000/health
```

## MVP Mock API

Current MVP endpoints store positions and quote snapshots in a local SQLite
database at `backend/data/stock_mvp.sqlite3`. K-lines and signals are still
generated from quote snapshots so the Flutter app can integrate against stable
response shapes before the real Futu OpenAPI provider is connected.

```text
GET    /api/v1/positions
POST   /api/v1/positions
PUT    /api/v1/positions/{position_id}
DELETE /api/v1/positions/{position_id}

GET    /api/v1/quotes?codes=HK.00700,US.AAPL
GET    /api/v1/klines/{stock_code}?period=day&limit=120
GET    /api/v1/signals
```

Example position payload:

```json
{
  "market": "HK",
  "code": "HK.00700",
  "name": "Tencent",
  "quantity": 100,
  "cost_price": 350.0,
  "currency": "HKD"
}
```
