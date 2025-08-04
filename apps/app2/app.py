import os
import time
from flask import Flask, jsonify
from prometheus_client import start_http_server, Counter, Histogram
import logging

# Configure logging
logging_level = os.environ.get('LOG_LEVEL', 'INFO').upper()
logging.basicConfig(level=getattr(logging, logging_level),
                   format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('app1')

# Create the Flask application
app = Flask(__name__)

# Define metrics
REQUEST_COUNT = Counter('app_request_count', 'Application Request Count',
                       ['method', 'endpoint', 'http_status'])
REQUEST_LATENCY = Histogram('app_request_latency_seconds', 'Application Request Latency',
                           ['method', 'endpoint'])

@app.route('/')
def index():
    start_time = time.time()
    logger.info("Received request for index page")
    
    response_data = {
        'app': 'app1',
        'version': '1.0.0',
        'environment': os.environ.get('ENVIRONMENT', 'development')
    }
    
    # Record metrics
    REQUEST_COUNT.labels('GET', '/', 200).inc()
    REQUEST_LATENCY.labels('GET', '/').observe(time.time() - start_time)
    
    return jsonify(response_data)

@app.route('/health')
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    # Start up the server to expose metrics
    start_http_server(9090)
    logger.info("Metrics server started on port 9090")
    
    # Start the Flask application
    app.run(host='0.0.0.0', port=8080)