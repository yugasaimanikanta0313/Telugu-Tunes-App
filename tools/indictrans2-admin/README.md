# IndicTrans2 Admin Translator

This local helper generates a Telugu-to-English draft without Gemini, Groq, or
any translation cloud API. It listens only on `127.0.0.1`, so lyrics remain on
the admin computer until the reviewed result is published to Telugu Tunes.

## First-time setup

1. Install 64-bit Python 3.9–3.12. The setup automatically uses the compatible
   Miniconda Python already present on the current admin computer.
2. Open PowerShell in this folder.
3. Run `powershell -ExecutionPolicy Bypass -File .\setup-and-run.ps1`.
4. Keep the window open and use **Generate English** in the Telugu Tunes admin
   lyrics panel.

The first installation and first model download are large and can take time.
The computer should have at least 8 GB RAM; 16 GB is preferable. The Oracle
server does not run this model.

Every generated translation is a draft. Review names, idioms and poetic
meaning before selecting **Approve & publish**.
