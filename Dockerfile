# ATAK plugin development container.
#
# Adds the Android SDK to the published base image. That step runs on your
# machine, not in a shared image: Google's Android SDK Terms 3.4 forbid
# redistributing the SDK, so a prebuilt image containing it would put whoever
# published it in breach.
#
# The base carries the JDK, Gradle, the scanners and the shell tooling, so this
# build is short. Override BASE to build against a pinned release.
#
# The ATAK SDK is not here either — licensed material, mounted at runtime.

ARG BASE=ghcr.io/joshuafuller/atak-plugin-dev-base:latest
FROM ${BASE}

ARG ANDROID_CMDLINE_TOOLS=13114758
ARG COMPILE_SDK=36
ARG BUILD_TOOLS=36.0.0

USER root

# Android command-line tools, then exactly the platform and build-tools the
# 5.8 template asks for (compileSdk 36, minSdk 21, targetSdk 34).
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" \
    && curl -fsSL -o /tmp/cmdline.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" \
    && unzip -q /tmp/cmdline.zip -d "${ANDROID_HOME}/cmdline-tools" \
    && mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest" \
    && rm /tmp/cmdline.zip

# /opt/tak-bin is this repo's workspace/bin, mounted at runtime. Putting it on
# PATH means `deploy`, `instrument`, `doctor` and `scan` are commands rather
# than paths an agent has to remember.
ENV PATH="/opt/tak-bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

# Accepting Google's Android SDK terms on your behalf, on your machine.
RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager --install \
        "platform-tools" \
        "platforms;android-${COMPILE_SDK}" \
        "platforms;android-34" \
        "build-tools;${BUILD_TOOLS}" > /dev/null \
    && chown -R dev:dev /opt/android-sdk

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
