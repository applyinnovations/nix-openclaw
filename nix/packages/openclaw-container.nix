{ lib
, dockerTools
, runCommand
, bash
, coreutils
, cacert
, openclaw-gateway
, extendedTools ? []
}:

let
  entrypoint = runCommand "openclaw-entrypoint" {
    src = ../scripts/docker-entrypoint.sh;
  } "${../scripts/docker-entrypoint-install.sh}";
in

dockerTools.buildLayeredImage {
  name = "openclaw";
  tag = openclaw-gateway.version;
  maxLayers = 100;

  contents = [
    openclaw-gateway
    entrypoint
    bash
    coreutils
    cacert
    dockerTools.fakeNss
  ] ++ extendedTools;

  fakeRootCommands = ''
    mkdir -p ./tmp ./data ./config ./home/openclaw
    chmod 1777 ./tmp
  '';

  config = {
    Cmd = [ "${entrypoint}/bin/openclaw-entrypoint" ];
    ExposedPorts = { "18789/tcp" = {}; };
    Volumes = {
      "/data" = {};
      "/config" = {};
    };
    Env = [
      "MOLTBOT_NIX_MODE=1"
      "CLAWDBOT_NIX_MODE=1"
      "MOLTBOT_STATE_DIR=/data"
      "CLAWDBOT_STATE_DIR=/data"
      "HOME=/home/openclaw"
      "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
      "TMPDIR=/tmp"
    ];
    WorkingDir = "/data";
  };
}
