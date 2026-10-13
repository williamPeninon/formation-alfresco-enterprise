<#escape x as x?html>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8"/>
  <title>Procédures qualité</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 2rem; color: #1b2733; }
    h1 { color: #0b5cad; }
    table { border-collapse: collapse; margin-top: 1rem; }
    th, td { border: 1px solid #c9d3de; padding: 6px 12px; text-align: left; }
    th { background: #0b5cad; color: #fff; }
    .erreur { color: #b00020; font-weight: bold; }
  </style>
</head>
<body>
  <h1>Procédures du service Qualité</h1>
  <#if dossier??>
    <p>Dossier : <b>${chemin}</b></p>
    <table>
      <tr><th>Nom</th><th>Titre</th><th>Version</th><th>Modifié le</th><th>Taille (Ko)</th></tr>
      <#list docs as d>
        <#if d.isDocument>
          <tr>
            <td>${d.name}</td>
            <td>${(d.properties["cm:title"])!""}</td>
            <td>${(d.properties["cm:versionLabel"])!"-"}</td>
            <td>${d.properties["cm:modified"]?string("dd/MM/yyyy HH:mm")}</td>
            <td>${(d.size / 1024)?string("0.0")}</td>
          </tr>
        </#if>
      </#list>
    </table>
  <#else>
    <p class="erreur">Dossier introuvable : ${chemin}</p>
  </#if>
</body>
</html>
</#escape>
