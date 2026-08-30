"""Local-only Telugu-to-English translation service for Telugu Tunes admins."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORT = 8765
MODEL_NAME = "ai4bharat/indictrans2-indic-en-1B"

_runtime = None


def runtime():
    global _runtime
    if _runtime is None:
        import torch
        from IndicTransToolkit import IndicProcessor
        from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

        tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
        model = AutoModelForSeq2SeqLM.from_pretrained(
            MODEL_NAME, trust_remote_code=True, low_cpu_mem_usage=True
        )
        model.eval()
        processor = IndicProcessor(inference=True)
        _runtime = (torch, tokenizer, model, processor)
    return _runtime


def translate(lines, source_language, target_language):
    torch, tokenizer, model, processor = runtime()
    results = []
    for start in range(0, len(lines), 12):
        original = lines[start : start + 12]
        nonempty = [line if line.strip() else " " for line in original]
        batch = processor.preprocess_batch(
            nonempty, src_lang=source_language, tgt_lang=target_language
        )
        inputs = tokenizer(
            batch,
            truncation=True,
            padding="longest",
            return_tensors="pt",
            max_length=256,
        )
        with torch.inference_mode():
            generated = model.generate(
                **inputs,
                num_beams=5,
                num_return_sequences=1,
                max_length=256,
            )
        decoded = tokenizer.batch_decode(generated, skip_special_tokens=True)
        translated = processor.postprocess_batch(decoded, lang=target_language)
        results.extend(
            "" if not original[index].strip() else value.strip()
            for index, value in enumerate(translated)
        )
    return results


class Handler(BaseHTTPRequestHandler):
    def send_json(self, status, payload):
        encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        self.wfile.write(encoded)

    def do_OPTIONS(self):
        self.send_json(204, {})

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"status": "UP", "model": MODEL_NAME})
        else:
            self.send_json(404, {"error": "Not found"})

    def do_POST(self):
        if self.path != "/translate":
            self.send_json(404, {"error": "Not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(length).decode("utf-8"))
            lines = body.get("lines", [])
            if not isinstance(lines, list) or len(lines) > 500:
                raise ValueError("lines must be an array containing at most 500 items")
            translations = translate(
                [str(line) for line in lines],
                body.get("sourceLanguage", "tel_Telu"),
                body.get("targetLanguage", "eng_Latn"),
            )
            self.send_json(200, {"translations": translations})
        except Exception as error:
            self.send_json(400, {"error": str(error)})

    def log_message(self, message, *args):
        print("IndicTrans2:", message % args)


if __name__ == "__main__":
    print(f"IndicTrans2 Admin Translator: http://{HOST}:{PORT}")
    print("The model is loaded only after the first translation request.")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
