from flask import Flask, request, Response
import queue
import json

api = Flask(__name__)
rolls = 0
MAX_SIZE = 5

class RollAnnouncer:
    def __init__(self):
        self.listeners = []

    def listen(self):
        q = queue.Queue(maxsize=MAX_SIZE)
        self.listeners.append(q)
        print(f'listeners is now {len(self.listeners)} long')
        return q
    
    def announce(self, roll):
        # Remove listeners that are no longer active
        self.listeners = [q for q in self.listeners if not q.full()]
        
        serialized_roll = json.dumps({"roll": roll})
        for q in self.listeners:
            try:
                q.put_nowait(serialized_roll)
                print(f'Roll {roll} sent to listener')
            except queue.Full:
                continue


@api.route('/roll', methods=['POST'])
def post_rolls():
    global rolls  # Consider making this a class attribute instead of global
    try:
        rolls = int(request.args.get('value3', 0))  # Add type conversion and default
        announcer.announce(rolls)  # Announce immediately when roll received
        return {'status': 'success', 'roll': rolls}, 200
    except ValueError:
        return {'status': 'error', 'message': 'Invalid roll value'}, 400

@api.route('/listen', methods=['GET'])
def listen():
    def stream():
        try:
            rolls = announcer.listen()
            while True:
                try:
                    this_roll = rolls.get(timeout=30)
                    yield f"data: {this_roll}\n\n"
                except queue.Empty:
                    yield f"data: {json.dumps({'heartbeat': True})}\n\n"
                except AttributeError as e:
                    print(f'Error: {e}')
                    break
        except Exception as e:
            print(f'Stream error: {e}')
            
    response = Response(stream(), mimetype='text/event-stream')
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'
    return response

if __name__ == '__main__':
    announcer = RollAnnouncer()
    api.run(host='0.0.0.0')
