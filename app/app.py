from flask import Flask, jsonify
from datetime import datetime, timezone
import os

app = Flask(__name__)

@app.get("/")
def home():
    return jsonify({
        "message": "Python application deployed successfully on AWS EC2!",
        "project": "GitHub Actions EC2 Deployment",
        "deployment": os.getenv("DEPLOYMENT_METHOD", "local"),
        "timestamp": datetime.now(timezone.utc).isoformat()
    })

@app.get("/health")
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
