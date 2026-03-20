import os
import psycopg2
from flask import Flask, request, jsonify

app = Flask(__name__)

def get_db_connection():
    return psycopg2.connect(
        host=os.environ.get('DB_HOST', 'localhost'),
        database=os.environ.get('DB_NAME', 'postgres'),
        user=os.environ.get('DB_USER', 'postgres'),
        password=os.environ.get('DB_PASSWORD', 'password123')
    )

@app.route('/init', methods=['GET'])
def init_db():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('CREATE TABLE IF NOT EXISTS messages (id serial PRIMARY KEY, text VARCHAR (150) NOT NULL);')
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"status": "Base de datos inicializada"})

@app.route('/messages', methods=['GET', 'POST'])
def messages():
    conn = get_db_connection()
    cur = conn.cursor()
    if request.method == 'POST':
        new_message = request.json['text']
        cur.execute('INSERT INTO messages (text) VALUES (%s)', (new_message,))
        conn.commit()
        return jsonify({"status": "Mensaje guardado"}), 201
    else:
        cur.execute('SELECT text FROM messages;')
        msgs = [row[0] for row in cur.fetchall()]
        return jsonify(msgs)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)