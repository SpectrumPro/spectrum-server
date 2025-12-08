# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name ManifestImport extends RefCounted
## Base class for all manifest importers



## Loads a fixture manifest
static func load_from_file(p_file_path: String) -> FixtureManifest:
	return FixtureManifest.new()


## Returns a Dictonary with infomation about the fixture on disk
static func get_info(p_file_path: String) -> Dictionary:
	return {}
