import http.server
import socketserver


class Server(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        print("path ", self.path)
        self.send_response(200, "OK")
        self.send_header("x-user-id", 1)
        self.send_header("x-foo", "bar")
        self.end_headers()


def serve_forever(port):
    print("Starting server on port", port)
    socketserver.TCPServer(("", port), Server).serve_forever()


if __name__ == "__main__":
    serve_forever(8080)
