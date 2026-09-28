# Ápice Workspace

Protótipo responsivo do workspace interno e portal de clientes da **Ápice Studio**.

## Como abrir localmente

### Opção 1 — VS Code + Live Server
1. Abra esta pasta no VS Code.
2. Instale a extensão **Live Server** (Ritwick Dey), se ainda não tiver.
3. Clique com o botão direito em `index.html`.
4. Selecione **Open with Live Server**.

### Opção 2 — Python
No terminal aberto nesta pasta:

```bash
python -m http.server 5500
```

Depois abra `http://localhost:5500` no navegador.

## Estrutura

```text
apice-workspace/
├── index.html
├── README.md
└── .gitignore
```

O protótipo atual está concentrado em um único `index.html` para facilitar testes e publicação. A identidade visual da Ápice está incorporada ao arquivo.

## Publicação

Para o protótipo, você pode publicar gratuitamente com GitHub Pages. Para a versão de produção, a arquitetura planejada é frontend + Supabase + Cloudflare R2.
