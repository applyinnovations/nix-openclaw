{ pkgs
, sourceInfo ? import ../sources/clawdbot-source.nix
, steipetePkgs ? {}
, toolNamesOverride ? null
, excludeToolNames ? []
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  clawdbotGateway = pkgs.callPackage ./clawdbot-gateway.nix {
    inherit sourceInfo;
    pnpmDepsHash = sourceInfo.pnpmDepsHash or null;
  };
  clawdbotApp = if isDarwin then pkgs.callPackage ./clawdbot-app.nix { } else null;

  mkToolSets = { toolNamesOverride ? null, excludeToolNames ? [] }:
    import ../tools/extended.nix {
      pkgs = pkgs;
      steipetePkgs = steipetePkgs;
      inherit toolNamesOverride excludeToolNames;
    };

  mkPackageSet = { toolNamesOverride ? null, excludeToolNames ? [] }:
    let
      toolSets = mkToolSets { inherit toolNamesOverride excludeToolNames; };
      clawdbotTools = pkgs.buildEnv {
        name = "clawdbot-tools";
        paths = toolSets.tools;
        pathsToLink = [ "/bin" ];
      };
      clawdbotBundle = pkgs.callPackage ./clawdbot-batteries.nix {
        clawdbot-gateway = clawdbotGateway;
        clawdbot-app = clawdbotApp;
        extendedTools = toolSets.tools;
      };
    in {
      clawdbot-gateway = clawdbotGateway;
      clawdbot = clawdbotBundle;
      clawdbot-tools = clawdbotTools;
      toolNames = toolSets.toolNames;
    } // (if isDarwin then { clawdbot-app = clawdbotApp; } else {});

  packageSet = mkPackageSet { inherit toolNamesOverride excludeToolNames; };
in
packageSet // {
  withTools = { toolNamesOverride ? null, excludeToolNames ? [] }:
    mkPackageSet { inherit toolNamesOverride excludeToolNames; };
}
