# Jenkins pour l'atelier A11 : JDK 21 (hérité de l'image de base), Maven et le
# client Docker (pour agent { docker { image '...' } }, via le socket de
# l'hôte monté par docker-compose), plugins pré-installés, assistant de
# configuration désactivé (identifiants admin/admin en lab, à ne jamais
# reproduire en production).
#
# Le paquet Debian docker.io n'embarque plus le binaire client /usr/bin/docker
# (vérifié : seulement dockerd, docker-proxy, docker-init) : on le récupère
# depuis l'image officielle docker:27-cli à la place.
FROM docker:27-cli AS docker-cli
FROM jenkins/jenkins:lts-jdk21

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends maven \
    && rm -rf /var/lib/apt/lists/*
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
# Le socket Docker monté par docker-compose appartient à root:root (mode 660)
# sur Docker Desktop : ajouter jenkins au groupe root pour qu'il puisse s'en
# servir (lab uniquement — à remplacer par un groupe docker au GID de l'hôte
# en dehors d'un environnement de formation).
RUN usermod -aG root jenkins

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

USER jenkins
