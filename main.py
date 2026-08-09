@@
-        if compartilhar_servico is not None:
-                async def _share_async():
-                    try:
-                        # Algumas versões do Flet usam share_files; se sua versão
-                        # diferir, ajuste conforme a API do ft.Share disponível.
-                        await compartilhar_servico.share_files([caminho_pdf])
-                        mostrar_snackbar("Compartilhamento aberto.")
-                    except Exception:
-                        mostrar_snackbar(f"Não foi possível abrir compartilhamento. PDF salvo em: {caminho_pdf}")
-                page.run_task(_share_async())
-            else:
-                mostrar_snackbar(f"PDF salvo em: {caminho_pdf}")
+            if compartilhar_servico is not None:
+                async def _share_async():
+                    try:
+                        # Compatibilidade com diferentes versões do Flet/ft.Share
+                        method = getattr(compartilhar_servico, "share_files", None) or getattr(compartilhar_servico, "share_file", None) or getattr(compartilhar_servico, "share", None)
+                        if method is None:
+                            raise RuntimeError("API de compartilhamento não disponível nesta versão do Flet.")
+                        # Alguns métodos aceitam lista de caminhos, outros apenas uma string
+                        if method.__name__.endswith("files"):
+                            await method([caminho_pdf])
+                        else:
+                            await method(caminho_pdf)
+                        mostrar_snackbar("Compartilhamento aberto.")
+                    except Exception:
+                        mostrar_snackbar(f"Não foi possível abrir compartilhamento. PDF salvo em: {caminho_pdf}")
+                page.run_task(_share_async)
+            else:
+                mostrar_snackbar(f"PDF salvo em: {caminho_pdf}")
@@
-    CORES = {
+    CORES = {
         db.TIPO_DINHEIRO:        C_GREEN,
         db.TIPO_PIX:             C_BLUE,
         db.TIPO_REQUISICAO:      C_PURPLE,
         db.TIPO_SODEXO:          C_TEAL,
         db.TIPO_DEPOSITO_GLOBAL: C_BROWN,
         db.TIPO_DESPESA:         C_RED,
         "Master Crédito":        C_RED,
         "Master Débito":         C_ORANGE,
         "Visa Crédito":          C_INDIGO,
-        "Visa Débito":           C_INDIGO2,
+        "Visa Débito":           C_INDIGO2,
         "Elo Crédito":           C_AMBER,
         "Elo Débito":            C_AMBER2,
         "Alelo Multibenefícios": C_PURPLE,
     }
