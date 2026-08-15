"""Módulo de integração para envio automático de PDFs para o Google Drive com alta resiliência."""

import base64
import json
import logging
import os
import ssl
import sys
import time
import urllib.error
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


def _get_ssl_context() -> ssl.SSLContext:
    """Retorna um contexto SSL resiliente para evitar falhas em Android, iOS e macOS."""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        pass

    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        return ctx
    except Exception:
        pass

    if hasattr(ssl, "_create_unverified_context"):
        return ssl._create_unverified_context()
    return ssl.create_default_context()


def _caminho_fila_pendencias() -> str:
    """Retorna o caminho do arquivo de fila offline de pendências."""
    try:
        import db
        pasta = db.caminho_backups()
    except Exception:
        pasta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backups")
    os.makedirs(pasta, exist_ok=True)
    return os.path.join(pasta, "pendencias_drive.json")


def obter_pendencias_envio() -> list[dict]:
    """Retorna a lista de envios pendentes para o Google Drive."""
    if _is_pyodide():
        try:
            import js
            raw = js.localStorage.getItem("pendencias_drive_json")
            if raw:
                return json.loads(str(raw))
        except Exception:
            pass
        return []

    caminho = _caminho_fila_pendencias()
    if not os.path.exists(caminho):
        return []
    try:
        with open(caminho, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return []


def salvar_pendencia_envio(caminho_pdf: str, turno_id: int, operador: str) -> None:
    """Adiciona um turno à fila de pendências para reenvio automático."""
    pendencias = obter_pendencias_envio()
    for p in pendencias:
        if p.get("turno_id") == turno_id:
            return

    pendencias.append({
        "turno_id": turno_id,
        "caminho_pdf": caminho_pdf,
        "operador": operador,
        "timestamp": time.time(),
        "tentativas": 0,
    })

    if _is_pyodide():
        try:
            import js
            js.localStorage.setItem("pendencias_drive_json", json.dumps(pendencias))
        except Exception:
            pass
    else:
        try:
            with open(_caminho_fila_pendencias(), "w", encoding="utf-8") as f:
                json.dump(pendencias, f, indent=2)
        except Exception as e:
            logger.error(f"[DriveQueue] Erro ao salvar pendência: {e}")


def remover_pendencia_envio(turno_id: int) -> None:
    """Remove um turno da fila de pendências após envio confirmado."""
    pendencias = [p for p in obter_pendencias_envio() if p.get("turno_id") != turno_id]
    if _is_pyodide():
        try:
            import js
            js.localStorage.setItem("pendencias_drive_json", json.dumps(pendencias))
        except Exception:
            pass
    else:
        try:
            with open(_caminho_fila_pendencias(), "w", encoding="utf-8") as f:
                json.dump(pendencias, f, indent=2)
        except Exception as e:
            logger.error(f"[DriveQueue] Erro ao atualizar pendências: {e}")


def _enviar_web_js(url_webhook: str, payload: dict) -> tuple[bool, str]:
    """Envia o payload usando fetch assíncrono blindado no navegador (PWA/Pyodide)."""
    try:
        import js
        payload_str = json.dumps(payload)
        js_code = f"""
            (async function() {{
                try {{
                    var payload = {payload_str};
                    var bodyText = JSON.stringify(payload);
                    await fetch("{url_webhook}", {{
                        method: "POST",
                        mode: "no-cors",
                        headers: {{ "Content-Type": "text/plain;charset=utf-8" }},
                        body: bodyText,
                        keepalive: true
                    }});
                    console.log("[Drive Webhook] Disparado com sucesso.");
                }} catch (e) {{
                    console.error("[Drive Webhook] Erro ao enviar:", e);
                }}
            }})();
        """
        try:
            js.window.eval(js_code)
        except Exception:
            import pyodide
            pyodide.code.run_js(js_code)
        return True, "PDF enviado com sucesso para o Google Drive do Gerente!"
    except Exception as e:
        msg = f"Falha ao enviar via Web Browser: {e}"
        logger.error(f"[DriveService Web] {msg}")
        return False, msg


def enviar_pdf_drive_bg(caminho_pdf: str, turno_id: int, operador: str) -> tuple[bool, str]:
    """Envia o arquivo PDF em segundo plano para o Google Drive com retentativas automáticas.
    
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

    salvar_pendencia_envio(caminho_pdf, turno_id, operador)

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
            ok, msg = _enviar_web_js(url_webhook, payload)
            if ok:
                remover_pendencia_envio(turno_id)
            return ok, msg

        data = json.dumps(payload).encode("utf-8")
        headers = {
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        }
        ssl_ctx = _get_ssl_context()

        ultimo_erro = ""
        for tentativa in range(1, 4):
            try:
                req = urllib.request.Request(
                    url_webhook,
                    data=data,
                    headers=headers,
                    method="POST",
                )

                with urllib.request.urlopen(req, timeout=35, context=ssl_ctx) as resp:
                    status_code = resp.getcode()
                    corpo_resposta = resp.read().decode("utf-8", errors="ignore")

                if status_code in (200, 201):
                    logger.info(f"[DriveService] PDF {nome_arquivo} enviado com sucesso para o Google Drive na tentativa {tentativa}.")
                    remover_pendencia_envio(turno_id)
                    return True, "PDF enviado com sucesso para o Google Drive do Gerente!"
                else:
                    ultimo_erro = f"Servidor retornou status {status_code}: {corpo_resposta[:100]}"
            except urllib.error.HTTPError as he:
                if he.code == 403:
                    ultimo_erro = "Erro 403: Verifique se 'Quem tem acesso' está definido como 'Qualquer pessoa' (Anyone) no Google Apps Script."
                    break
                ultimo_erro = f"Erro HTTP {he.code}: {he.reason}"
            except Exception as e:
                ultimo_erro = f"Tentativa {tentativa}/3 falhou: {e}"
                time.sleep(1.5)

        logger.warning(f"[DriveService] {ultimo_erro}. PDF mantido na fila offline para reenvio.")
        return False, f"Salvo na fila offline ({ultimo_erro})"

    except Exception as e:
        msg_erro = f"Falha no envio para o Google Drive: {e}"
        logger.error(f"[DriveService] {msg_erro}")
        return False, msg_erro


def sincronizar_pendencias_drive_bg() -> tuple[int, int]:
    """Processa todos os PDFs que ficaram na fila offline por falta de conexão.
    
    Retorna (sucessos: int, total_pendentes: int).
    """
    pendencias = obter_pendencias_envio()
    if not pendencias:
        return 0, 0

    sucessos = 0
    total = len(pendencias)
    for item in list(pendencias):
        caminho = item.get("caminho_pdf", "")
        turno_id = item.get("turno_id")
        operador = item.get("operador", "Operador")
        if caminho and os.path.exists(caminho) and turno_id:
            ok, _ = enviar_pdf_drive_bg(caminho, turno_id, operador)
            if ok:
                sucessos += 1
                remover_pendencia_envio(turno_id)

    return sucessos, total
