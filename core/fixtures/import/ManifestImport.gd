# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name ManifestImport extends RefCounted
## Base class for all manifest importers



## Loads a fixture manifest
static func load_from_file(file_path: String) -> FixtureManifest:
    return FixtureManifest.new()


## Gets a FixtureManifest in FixtureManifest.Type.Info mode
static func get_info(file_path: String) -> FixtureManifest:
    return FixtureManifest.new()