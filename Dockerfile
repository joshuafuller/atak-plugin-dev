# ATAK plugin development container.
#
# Pins every version the ATAK 5.8 plugin template requires, so builds do not
# depend on whatever happens to be installed on the host.
#
# The ATAK SDK is NOT baked in — it is licensed material and is mounted at
# runtime. Everything else is here.

FROM eclipse-temurin:17-jdk-jammy

ARG ANDROID_CMDLINE_TOOLS=13114758
ARG COMPILE_SDK=36
ARG BUILD_TOOLS=36.0.0
ARG GRADLE_VERSION=8.14.3

ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    GRADLE_USER_HOME=/home/dev/.gradle \
    DEBIAN_FRONTEND=noninteractive

# Build essentials plus the things you actually want when a build misbehaves
# at 1am. This is a personal dev box, not a hardened CI image.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl wget unzip zip git ca-certificates file sudo \
        vim nano less tree jq python3 python3-pip \
        procps iputils-ping net-tools openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Android command-line tools, then exactly the platform and build-tools the
# 5.8 template asks for (compileSdk 36, minSdk 21, targetSdk 34).
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" \
    && curl -fsSL -o /tmp/cmdline.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" \
    && unzip -q /tmp/cmdline.zip -d "${ANDROID_HOME}/cmdline-tools" \
    && mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest" \
    && rm /tmp/cmdline.zip

ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager --install \
        "platform-tools" \
        "platforms;android-${COMPILE_SDK}" \
        "platforms;android-34" \
        "build-tools;${BUILD_TOOLS}" > /dev/null

# Pre-seed the Gradle distribution the wrapper wants, so the first build does
# not spend several minutes downloading it.
RUN useradd -m -u 1000 -s /bin/bash dev \
    && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev \
    && mkdir -p /home/dev/.gradle/wrapper/dists \
    && curl -fsSL -o /tmp/gradle.zip \
        "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-all.zip" \
    && HASH=$(printf '%s' "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-all.zip" \
        | md5sum | cut -d' ' -f1) \
    && mkdir -p "/home/dev/.gradle/wrapper/dists/gradle-${GRADLE_VERSION}-all/${HASH}" \
    && unzip -q /tmp/gradle.zip -d "/home/dev/.gradle/wrapper/dists/gradle-${GRADLE_VERSION}-all/${HASH}" \
    && touch "/home/dev/.gradle/wrapper/dists/gradle-${GRADLE_VERSION}-all/${HASH}/gradle-${GRADLE_VERSION}-all.zip.ok" \
    && rm /tmp/gradle.zip \
    && chown -R dev:dev /home/dev /opt/android-sdk

USER dev
WORKDIR /work

# adb deliberately gets NO ADB_SERVER_SOCKET. The container reaches the host's
# adb server through a forwarder on its own 127.0.0.1:5037 (workspace/bin/adb-bridge,
# started by the compose command) so that adb behaves exactly as if the server
# were local. Setting ADB_SERVER_SOCKET instead breaks Gradle: its device
# monitor ignores the variable, runs `adb start-server`, cannot bind, and then
# retries for as long as you let it.

# Stay alive so you can `docker compose exec atak-dev bash` and poke around.
CMD ["sleep", "infinity"]
