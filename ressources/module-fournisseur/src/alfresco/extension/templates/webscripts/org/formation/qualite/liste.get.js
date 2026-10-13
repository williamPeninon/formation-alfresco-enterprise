// Contrôleur : prépare les données affichées par le gabarit liste.get.html.ftl
var chemin = "Sites/qualite-test/documentLibrary/Procedures";
var dossier = companyhome.childByNamePath(chemin);

model.chemin = chemin;
model.dossier = dossier;
model.docs = (dossier != null) ? dossier.children : [];
