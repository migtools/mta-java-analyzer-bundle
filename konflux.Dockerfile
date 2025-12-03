FROM registry.redhat.io/ubi9:latest AS artifacts
RUN dnf -y install tar unzip gzip && dnf -y clean all
COPY --chown=1001:0 . /workspace
# Add some debugging
RUN cat /cachi2/cachi2.env /workspace/artifacts.lock.yaml
RUN ls -la /cachi2/output/deps/generic/
RUN cp /cachi2/output/deps/generic/fernflower-8.0.0.CR1-redhat-00003.jar /opt/fernflower.jar
RUN cp /cachi2/output/deps/generic/java-analyzer-bundle.core-8.0.1.CR1-redhat-00003.jar /opt/java-analyzer-bundle.core.jar
WORKDIR /maven-index-data
RUN cp /cachi2/output/deps/generic/maven-index-data-v20251112021242.zip /maven-index-data/maven-index-data.zip
RUN unzip maven-index-data.zip && rm -rf maven-index-data.zip
WORKDIR /jdtls
RUN cp /cachi2/output/deps/generic/org.eclipse.jdt.ls.product-7.2.0.CR1-redhat-00001.tar.gz /jdtls/jdtls-product.tar.gz
RUN tar -xvf jdtls-product.tar.gz --no-same-owner && chmod 755 /jdtls/bin/jdtls && rm -rf jdtls-product.tar.gz

FROM registry.redhat.io/ubi9:latest
# FIXME: modules in ART tooling not working at the moment
#RUN dnf -y module enable maven:3.9
RUN dnf module list
RUN dnf -y install openssl python39 java-1.8.0-openjdk-devel java-17-openjdk-devel maven-openjdk17 tar gzip --nodocs --setopt=install_weak_deps=0 && dnf -y clean all
ENV JAVA_HOME /usr/lib/jvm/java-17-openjdk
ENV JAVA8_HOME /usr/lib/jvm/java-1.8.0-openjdk
RUN mvn --version

RUN mkdir /root/.gradle
COPY --from=artifacts /workspace/gradle/build.gradle /usr/local/etc/task.gradle
COPY --from=artifacts /workspace/gradle/build-v9.gradle /usr/local/etc/task-v9.gradle

COPY --from=artifacts /maven-index-data/central.archive-metadata.txt /usr/local/etc/maven-index.txt
COPY --from=artifacts /maven-index-data/central.archive-metadata.idx /usr/local/etc/maven-index.idx

COPY --from=artifacts /workspace/hack/maven.default.index /usr/local/etc/maven.default.index
COPY --from=artifacts /jdtls /jdtls/
COPY --from=artifacts /opt/java-analyzer-bundle.core.jar /jdtls/java-analyzer-bundle/java-analyzer-bundle.core/target/
COPY --from=artifacts /opt/fernflower.jar /bin/fernflower.jar
COPY --from=artifacts /workspace/jdtls-bin-override/jdtls.py /jdtls/bin/jdtls.py
COPY --from=artifacts /workspace/LICENSE /licenses/

RUN ln -sf /root/.m2 /.m2 && chgrp -R 0 /root && chmod -R g=u /root

ENTRYPOINT ["/jdtls/bin/jdtls"]

LABEL \
        description="Migration Toolkit for Applications - JDTLS Server" \
        io.k8s.description="Migration Toolkit for Applications - JDTLS Server" \
        io.k8s.display-name="MTA - JDTLS Server" \
        io.openshift.maintainer.project="MTA" \
        io.openshift.tags="migration,modernization,mta,tackle,konveyor" \
        summary="Migration Toolkit for Applications - JDTLS Server"
