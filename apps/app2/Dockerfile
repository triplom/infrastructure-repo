FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Expose ports for the application and metrics
EXPOSE 8080 9090

CMD ["python", "app.py"]