from flask import Flask, jsonify
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

@app.route('/')
def hello():
    env = os.getenv('ENV', 'unknown')
    logger.info(f"Hello endpoint accessed, environment: {env}")
    return jsonify({
        "message": f"Hello from App1!",
        "environment": env,
        "app": "app1",
        "version": "1.0.0"
    })

@app.route('/health')
def health():
    logger.info("Health check endpoint accessed")
    return jsonify({
        "status": "healthy", 
        "app": "app1",
        "version": "1.0.0"
    })

@app.route('/metrics')
def metrics():
    """Basic metrics endpoint for monitoring"""
    return jsonify({
        "app": "app1",
        "status": "running",
        "environment": os.getenv('ENV', 'unknown')
    })

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8000))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    logger.info(f"Starting App1 on port {port}, debug={debug}")
    app.run(host='0.0.0.0', port=port, debug=debug)
