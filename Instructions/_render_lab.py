# -*- coding: utf-8 -*-
"""Rendert alle Lab-Markdown-Dateien in die gemeinsame HTML-Vorlage (Kopf/CSS
1:1 aus 07-app-service-bicep.html extrahiert, da kein Build-Skript im Repo
ueberlebt hat -- siehe README/HANDOFF-Historie). Ergaenzt die admonition-
Extension fuer die "Reflexionsstop"-Kaesten (!!! reflect "...")."""
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
        extensions=["extra", "codehilite", "tables", "sane_lists", "admonition"],
        extension_configs={"codehilite": {"css_class": "codehilite", "guess_lang": False}},
    )

    head = HEAD_BLOCK.replace(
        existing[existing.index("<title>"):existing.index("</title>") + len("</title>")],
        f"<title>{title} — Azure Deployment Workshop</title>",
    )

    out = []
    out.append(head)
    out.append("\n\n<header class=\"hero\">\n  <div class=\"wrap\">\n")
    out.append('    <p class="crumb"><a href="../index.html">&larr; Zur Lab-Übersicht</a></p>\n')
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


LABS = [
    ("01-manual-lamp.md", "01-manual-lamp.html",
     "Manuelle LAMP-Installation auf einer Azure-VM", "Tag 1", "Lab 01",
     "Manuelle LAMP-Installation auf einer Azure-VM"),
    ("02-cloud-init.md", "02-cloud-init.html",
     "LAMP + WordPress automatisiert per Cloud-Init", "Tag 1", "Lab 02",
     "LAMP + WordPress automatisiert per Cloud-Init"),
    ("03-windows-dsc.md", "03-windows-dsc.html",
     "WordPress unter Windows: VM-Erweiterungen, VM-Anwendungen und DSC", "Tag 1", "Lab 03",
     "WordPress unter Windows: VM-Erweiterungen, VM-Anwendungen und DSC"),
    ("04-bicep.md", "04-bicep.html",
     "WordPress deklarativ mit Bicep", "Tag 2", "Lab 04",
     "WordPress deklarativ mit Bicep"),
    ("05-terraform.md", "05-terraform.html",
     "WordPress deklarativ mit Terraform (einmalige Demonstration)", "Tag 2", "Lab 05",
     "WordPress deklarativ mit Terraform (einmalige Demonstration)"),
    ("06-app-service-manual.md", "06-app-service-manual.html",
     "Manuelles PHP-Deployment auf App Service", "Tag 3", "Lab 06",
     "Manuelles PHP-Deployment auf App Service"),
    ("07-app-service-bicep.md", "07-app-service-bicep.html",
     "Deklaratives App-Service-Deployment (Bicep)", "Tag 3", "Lab 07",
     "Deklaratives App-Service-Deployment (Bicep)"),
    ("08-cicd-github-actions.md", "08-cicd-github-actions.html",
     "CI/CD mit GitHub Actions: Build → Deploy in Slot → Swap", "Tag 3", "Lab 08",
     "CI/CD mit GitHub Actions: Build → Deploy in Slot → Swap"),
    ("09-containers.md", "09-containers.html",
     "Container-Deployment (Azure Container Instances)", "Tag 4", "Lab 09",
     "Container-Deployment (Azure Container Instances)"),
    ("10-wordpress-managed.md", "10-wordpress-managed.html",
     "WordPress on Azure App Service: der verwaltete Weg", "Tag 4", "Lab 10",
     "WordPress on Azure App Service: der verwaltete Weg"),
]


if __name__ == "__main__":
    for md_path, out_path, title, day_badge, lab_num, h1 in LABS:
        render(md_path, out_path, title, day_badge, lab_num, h1)
