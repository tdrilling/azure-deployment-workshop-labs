# -*- coding: utf-8 -*-
"""Rendert eine Lab-Markdown-Datei in die gleiche HTML-Vorlage wie die
uebrigen Instructions/*.html (Kopf/CSS 1:1 aus 09-containers.html
extrahiert, da kein Build-Skript im Repo ueberlebt hat -- siehe README/
HANDOFF-Historie)."""
import sys
import markdown

HERE_HTML = "07-app-service-bicep.html"

with open(HERE_HTML, "r", encoding="utf-8") as f:
    existing = f.read()

HEAD_START = existing.index("<!doctype html>")
HEAD_END = existing.index("<body>") + len("<body>")
HEAD_BLOCK = existing[HEAD_START:HEAD_END]


def render(md_path, out_path, title, day_badge, lab_num, h1):
    with open(md_path, "r", encoding="utf-8") as f:
        md_text = f.read()

    # Erste H1-Zeile und Ziel/Dauer-Zeilen sind im Hero-Header, nicht im Body
    lines = md_text.split("\n")
    assert lines[0].startswith("# "), "Markdown muss mit H1 beginnen"
    body_md = "\n".join(lines[1:]).lstrip("\n")

    html_body = markdown.markdown(
        body_md,
        extensions=["extra", "codehilite", "tables", "sane_lists"],
        extension_configs={"codehilite": {"css_class": "codehilite", "guess_lang": False}},
    )

    head = HEAD_BLOCK.replace(
        existing[existing.index("<title>"):existing.index("</title>") + len("</title>")],
        f"<title>{title} — Azure Deployment Workshop</title>",
    )

    out = []
    out.append(head)
    out.append("\n\n<header class=\"hero\">\n  <div class=\"wrap\">\n")
    out.append(f'    <p class="crumb"><a href="../index.html">&larr; Zur Lab-Übersicht</a></p>\n')
    out.append(f'    <p class="eyebrow"><span class="day-badge">{day_badge}</span>{lab_num} &middot; Azure Deployment Workshop</p>\n')
    out.append(f"    <h1>{h1}</h1>\n")
    out.append("  </div>\n</header>\n\n<div class=\"wrap\">\n  <article>\n")
    out.append(html_body)
    out.append("\n  </article>\n\n")
    out.append("  <div class=\"lab-nav\">\n")
    out.append('    <a href="../index.html">&larr; Zur Lab-Übersicht</a>\n')
    md_basename = md_path.rsplit("/", 1)[-1]
    out.append(f'    <a href="https://github.com/tdrilling/azure-deployment-workshop-labs/blob/main/Instructions/{md_basename}">Quelltext (Markdown) auf GitHub ansehen &rarr;</a>\n')
    out.append("  </div>\n\n")
    out.append('  <p class="credit">Thomas Drilling &middot; Microsoft Certified Trainer &middot; drilling-azure.de / cloudtrain.de</p>\n')
    out.append("</div>\n</body>\n</html>\n")

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("".join(out))
    print("Gerendert:", out_path)


if __name__ == "__main__":
    render(
        "10-wordpress-managed.md",
        "10-wordpress-managed.html",
        "WordPress on Azure App Service: der verwaltete Weg",
        "Tag 4",
        "Lab 10",
        "WordPress on Azure App Service: der verwaltete Weg",
    )
