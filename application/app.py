"""
Multi-Tier AWS Application - Flask Web Server
Production-ready web application with database connectivity
"""

import os
import psycopg2
from flask import Flask, jsonify, request
from flask_cors import CORS
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'database': os.getenv('DB_NAME', 'appdb'),
    'user': os.getenv('DB_USER', 'admin'),
    'password': os.getenv('DB_PASSWORD', 'password'),
    'port': os.getenv('DB_PORT', '5432')
}


def get_db_connection():
    """Create and return database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        logger.error(f"Database connection error: {str(e)}")
        raise


def init_database():
    """Initialize database tables"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Create users table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(100) UNIQUE NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Create visits table for tracking
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS visits (
                id SERIAL PRIMARY KEY,
                ip_address VARCHAR(45),
                user_agent TEXT,
                visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        cursor.close()
        conn.close()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization error: {str(e)}")


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for ALB"""
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'database': 'connected'
        }), 200
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'timestamp': datetime.utcnow().isoformat(),
            'database': 'disconnected',
            'error': str(e)
        }), 503


@app.route('/', methods=['GET'])
def index():
    """Home endpoint"""
    try:
        # Log visit
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO visits (ip_address, user_agent)
            VALUES (%s, %s)
        """, (request.remote_addr, request.headers.get('User-Agent', '')))
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'message': 'Welcome to Multi-Tier AWS Application',
            'version': '1.0.0',
            'timestamp': datetime.utcnow().isoformat(),
            'status': 'operational'
        }), 200
    except Exception as e:
        logger.error(f"Error in index: {str(e)}")
        return jsonify({
            'message': 'Welcome to Multi-Tier AWS Application',
            'version': '1.0.0',
            'timestamp': datetime.utcnow().isoformat(),
            'status': 'operational',
            'note': 'Database logging temporarily unavailable'
        }), 200


@app.route('/api/users', methods=['GET'])
def get_users():
    """Get all users"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, username, email, created_at FROM users ORDER BY created_at DESC")
        users = cursor.fetchall()
        cursor.close()
        conn.close()
        
        result = []
        for user in users:
            result.append({
                'id': user[0],
                'username': user[1],
                'email': user[2],
                'created_at': user[3].isoformat() if user[3] else None
            })
        
        return jsonify({'users': result, 'count': len(result)}), 200
    except Exception as e:
        logger.error(f"Error getting users: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/users', methods=['POST'])
def create_user():
    """Create a new user"""
    try:
        data = request.get_json()
        username = data.get('username')
        email = data.get('email')
        
        if not username or not email:
            return jsonify({'error': 'Username and email are required'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO users (username, email)
            VALUES (%s, %s)
            RETURNING id, username, email, created_at
        """, (username, email))
        
        user = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'id': user[0],
            'username': user[1],
            'email': user[2],
            'created_at': user[3].isoformat() if user[3] else None
        }), 201
    except psycopg2.IntegrityError as e:
        return jsonify({'error': 'User already exists'}), 409
    except Exception as e:
        logger.error(f"Error creating user: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get application statistics"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get user count
        cursor.execute("SELECT COUNT(*) FROM users")
        user_count = cursor.fetchone()[0]
        
        # Get visit count
        cursor.execute("SELECT COUNT(*) FROM visits")
        visit_count = cursor.fetchone()[0]
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'users': user_count,
            'visits': visit_count,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        logger.error(f"Error getting stats: {str(e)}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    # Initialize database on startup
    init_database()
    
    # Run application
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
