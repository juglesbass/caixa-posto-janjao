"""Módulo de integração para envio automático de PDFs para o Google Drive."""

import base64
import json
import logging
import os
import sys
import urllib.parse
import urllib.request

logger = logging.getLogger("caixa_app")

# URL do Webhook do Google Apps Script ou Cloud Function do Posto Janjão
DRIVE_WEBHOOK_URL = os.environ.get(
    "GOOGLE_DRIVE_WEBHOOK_URL",
    "https://script.google.com/macros/s/AKfycbzes0dAFXK3_Us145YsnfKXAI_UzVjMHlVG4uK2-cYkxHy2f5M_VCaLEVEJhWOIvcVITQ/exec"
).strip()


def _is_pyodide() -> bool:
    """Verifica se está executando dentro do navegador (Pyodide WebAssembly)."""
    if "pyodide" in sys.modules or (hasattr(sys, "platform") and sys.platform == "emscripten"):
        return True
    try:
        import js
        return True
    except ImportError:
        return False


def _enviar_web_js(url_webhook: str, payload: dict) -> tuple[bool, str]:
    """Envia o payload usando a API fetch nativa do navegador (PWA/Pyodide)."""
    try:
        import js
        payload_str = json.dumps(payload)
        
        # Em Apps Script, usar Content-Type "text/plain" evita o pré-flight CORS travado pelo navegador
        options = js.Object.fromEntries([
            ("method", "POST"),
            ("headers", js.Object.fromEntries([("Content-Type", "text/plain;charset=utf-8")])),
            ("body", payload_str)
        ])
        
        js.fetch(url_webhook, options)
        logger.info("[DriveService Web] Requisição de envio disparada via browser fetch.")
        return True, "PDF enviado com sucesso para o Google Drive do Gerente!"
    except Exception as e:
        msg = f"Falha ao enviar via Web Browser: {e}"
        logger.error(f"[DriveService Web] {msg}")
        return False, msg


def enviar_pdf_drive_bg(caminho_pdf: str, turno_id: int, operador: str) -> tuple[bool, str]:
    """Envia o arquivo PDF em segundo plano para o Google Drive.
    
    Retorna uma tupla (sucesso: bool, mensagem: str).
    """
    if not os.path.exists(caminho_pdf):
        msg = f"Arquivo PDF não encontrado: {caminho_pdf}"
        logger.error(f"[DriveService] {msg}")
        return False, msg

    url_webhook = os.environ.get("GOOGLE_DRIVE_WEBHOOK_URL", "").strip() or DRIVE_WEBHOOK_URL
    if not url_webhook:
        logger.info("[DriveService] URL do Google Drive não configurada. PDF armazenado em backup local.")
        return True, "PDF salvo localmente (Drive não configurado)"

    try:
        nome_arquivo = os.path.basename(caminho_pdf)
        with open(caminho_pdf, "rb") as f:
            conteudo_bytes = f.read()

        payload = {
            "nome_arquivo": nome_arquivo,
            "turno_id": turno_id,
            "operador": operador,
            "arquivo_base64": base64.b64encode(conteudo_bytes).decode("utf-8"),
        }

        # Se for executado no navegador (PWA/Pyodide WebAssembly), dispara via Javascript Fetch API
        if _is_pyodide():
            return _enviar_web_js(url_webhook, payload)

        data = json.dumps(payload).encode("utf-8")
        headers = {
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        }
        req = urllib.request.Request(
            url_webhook,
            data=data,
            headers=headers,
            method="POST",
        )

        with urllib.request.urlopen(req, timeout=30) as resp:
            status_code = resp.getcode()
            corpo_resposta = resp.read().decode("utf-8", errors="ignore")

        if status_code in (200, 201):
            logger.info(f"[DriveService] PDF {nome_arquivo} enviado com sucesso para o Google Drive.")
            return True, "PDF enviado com sucesso para o Google Drive do Gerente!"
        else:
            msg = f"Resposta inesperada do servidor ({status_code}): {corpo_resposta[:100]}"
            logger.warning(f"[DriveService] {msg}")
            return False, msg

    except urllib.error.HTTPError as he:
        if he.code == 403:
            msg = "Erro 403: Verifique na implantação do Google Apps Script se 'Quem tem acesso' está definido como 'Qualquer pessoa' (Anyone)."
        else:
            msg = f"Erro HTTP {he.code}: {he.reason}"
        logger.error(f"[DriveService] {msg}")
        return False, msg
    except Exception as e:
        msg_erro = f"Falha ao enviar para o Google Drive: {e}"
        logger.error(f"[DriveService] {msg_erro}")
        return False, msg_erro
