import os
import requests
from flask import Flask, render_template_string, request, redirect

app = Flask(__name__)
BACKEND_URL = os.environ.get('BACKEND_URL', 'http://localhost:5000')

TEMPLATE = """
<!DOCTYPE html>
<html>
<head><title>App ECS Fargate</title></head>
<body style="font-family: Arial; text-align: center; margin-top: 50px;">
    <h2>🚀 Mensajes Guardados en PostgreSQL</h2>
    
    <form method="POST" action="/init" style="margin-bottom: 20px;">
        <button type="submit" style="padding: 8px 15px; background: #dc3545; border: none; color: white; border-radius: 4px; cursor: pointer;">1º Haz clic aquí para Inicializar Base de Datos</button>
    </form>

    <ul style="list-style: none; padding: 0;">
    {% for msg in messages %}
        <li style="background: #eee; margin: 5px auto; padding: 10px; width: 300px; border-radius: 5px;">{{ msg }}</li>
    {% endfor %}
    </ul>
    
    <form method="POST" action="/add" style="margin-top: 20px;">
        <input type="text" name="text" placeholder="Escribe algo..." required style="padding: 10px; width: 200px;">
        <button type="submit" style="padding: 10px 20px; background: #ff9900; border: none; color: white; cursor: pointer;">Enviar</button>
    </form>
</body>
</html>
"""

@app.route('/')
def index():
    try:
        response = requests.get(f"{BACKEND_URL}/messages", timeout=2)
        messages = response.json() if response.status_code == 200 else []
    except Exception as e:
        messages = [f"Error conectando al backend: {e}"]
    return render_template_string(TEMPLATE, messages=messages)

@app.route('/add', methods=['POST'])
def add():
    text = request.form['text']
    try:
        requests.post(f"{BACKEND_URL}/messages", json={"text": text}, timeout=2)
    except:
        pass
    return redirect('/')

# ¡NUEVA RUTA PARA AVISAR AL BACKEND!
@app.route('/init', methods=['POST'])
def init_db():
    try:
        requests.get(f"{BACKEND_URL}/init", timeout=2)
    except:
        pass
    return redirect('/')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)