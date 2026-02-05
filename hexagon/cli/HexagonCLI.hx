package hexagon.cli;

import haxe.display.Position.Range;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import hexagon.data.HexagonData;

using StringTools;

class HexagonCLI {
	static var data:HexagonData;
	static var paths:HexagonPaths;
	static var build:HexagonBuild;
	static var defines:Array<String>;
	static var macros:Array<String>;
	static var dependencies:HexagonDependencies;
	static var args:Array<String>;

	static var applicationTemplate:String = "";

	static var path:String;
	static var oldCwd:String;
	static var systemName:String;

	static function main() {
		args = Sys.args();
		path = args.pop();
		oldCwd = Sys.getCwd();
		Sys.setCwd(path);

		systemName = Sys.systemName();

		switch (args[0]) {
			case "build":
				buildApp(args[1]);
			case "test":
				buildApp(args[1]);
				test(args[1]);
			case "setup":
				setup();
			case "display":
				generateDisplayFile(args[1] != null ? args[1] : "interp");
		}

		Sys.setCwd(oldCwd);
	}

	private static function loadFile():HexagonData {
		if (FileSystem.exists('hexagon.xml')) {
			var xml:Xml = Xml.parse(File.getContent("hexagon.json")).firstChild();
			var data:HexagonData = {
				name: null,
				version: null,
				author: null,
				paths: {
					assets: [],
					source: [],
					export: null
				},
				build: {
					main: null
				},
				dependencies: [],
				defines: [],
				macros: []
			}

			var hasProject:Bool = false;
			for (project in xml.elementsNamed("project")) {
				data.name = project.get("name");
				data.version = project.get("version");
				data.author = project.get("author");
				hasProject = true;
				break;
			}

			if (!hasProject)
				throw "hexagon.xml should have a project element";

			var hasExport:Bool = false;
			for (export in xml.elementsNamed("export")) {
				data.paths.export = export.get("path");
				hasExport = true;
				break;
			}

			if (!hasExport)
				throw "hexagon.xml should have a export element";

			var hasBuild:Bool = false;
			for (build in xml.elementsNamed("build")) {
				data.build.main = build.get("main");

				if (build.exists("debug"))
					data.build.debug = build.get("debug") == "true";

				if (build.exists("verbose"))
					data.build.verbose = build.get("verbose") == "true";

				if (build.exists("optimize"))
					data.build.verbose = build.get("optimize") == "true";

				if (build.exists("dce"))
					data.build.dce = build.get("dce");

				hasBuild = true;
				break;
			}

			if (!hasBuild)
				throw "hexagon.xml should have a build element";

			for (asset in xml.elementsNamed("assets")) {
				data.paths.assets.push(asset.get("path"));
			}

			for (source in xml.elementsNamed("source")) {
				data.paths.source.push(source.get("path"));
			}

			for (dep in xml.elementsNamed("dependency")) {
				final dependency:HexagonDependency = {
					name: dep.get("name")
				}

				if (dep.exists("version"))
					dependency.version = dep.get("version");

				data.dependencies.push(dependency);
			}

			for (def in xml.elementsNamed("define")) {
				data.defines.push(def.get("value"));
			}

			for (mac in xml.elementsNamed("macro")) {
				data.macros.push(mac.get("value"));
			}

			return data;
		}

		return Json.parse(File.getContent("hexagon.json"));
	}

	private static function generateDisplayFile(target:String):Void {
		data = loadFile();
		paths = data.paths;
		build = data.build;
		defines = data.defines;
		macros = data.macros;
		dependencies = data.dependencies ?? [];
		dependencies.push({name: "hexagon"});

		applicationTemplate = {"package;\n"
			+ 'import ${build.main};\n'
			+ "class ApplicationMain {\n"
			+ "	  public static var compilingData:String = '"
			+ Json.stringify(data)
			+ "';\n"
			+ "   public static function main(){\n"
			+ '        new ${build.main}();\n'
			+ "   }\n"
			+ "}\n";
		};

		if (!FileSystem.exists(paths.export))
			FileSystem.createDirectory(paths.export);

		if (!FileSystem.exists(paths.export + '/helper'))
			FileSystem.createDirectory(paths.export + '/helper');

		File.saveContent(paths.export + '/helper/ApplicationMain.hx', applicationTemplate);

		var lines:Array<String> = [];

		lines.push('--class-path ${paths.export}/helper');
		for (classPath in paths.source) {
			lines.push('--class-path $classPath');
		}
		lines.push('');

		if (dependencies != null && dependencies.length > 0) {
			for (d in dependencies) {
				if (d.version != null) {
					lines.push('-lib ${d.name}:${d.version}');
				} else {
					lines.push('-lib ${d.name}');
				}
			}
			lines.push('');
		}

		if (defines != null && defines.length > 0) {
			for (def in defines) {
				lines.push('-D $def');
			}
			lines.push('');
		}

		if (macros != null && macros.length > 0) {
			for (m in macros) {
				lines.push('--macro $m');
			}
			lines.push('');
		}

		if (build.dce != null) {
			lines.push('--dce ${build.dce}');
		}

		if (build.debug == true) {
			lines.push('--debug');
		}

		if (build.verbose == true) {
			lines.push('--verbose');
		}

		if (build.optimize != null) {
			if (build.optimize) {
				lines.push('--no-opt');
			}
		}

		lines.push('');
		lines.push('-main ApplicationMain');
		lines.push('');

		switch (target) {
			case "hl", "hashlink":
				lines.push('--hl ${Path.join([paths.export, target, data.name + ".hl"])}');
			case "js", "javascript":
				lines.push('--js ${Path.join([paths.export, target, data.name + ".js"])}');
			case "cpp", "linux", "mac", "windows":
				lines.push('--cpp ${Path.join([paths.export, target, "haxe"])}');
				if (target == "linux")
					lines.push('-D linux');
				if (target == "mac")
					lines.push('-D mac');
				if (target == "windows")
					lines.push('-D windows');
			case "cs", "csharp":
				lines.push('--cs ${Path.join([paths.export, target, "haxe"])}');
			case "jvm", "java":
				lines.push('--jvm ${Path.join([paths.export, target, data.name + ".jar"])}');
			case "python", "py":
				lines.push('--python ${Path.join([paths.export, target, data.name + ".py"])}');
			case "lua":
				lines.push('--lua ${Path.join([paths.export, target, data.name + ".lua"])}');
			case "neko":
				lines.push('--neko ${Path.join([paths.export, target, data.name + ".n"])}');
			case 'eval', 'interp', 'run':
				lines.push('--interp');
		}

		File.saveContent(Path.join([paths.export, 'helper', 'build_${target}.hxml']), lines.join('\n'));
		Sys.println('Generated ${paths.export}/helper/build_${target}.hxml');
	}

	private static function addDefines(args:Array<String>, haxeParams:Array<String>) {
		for (a in args) {
			if (a.charAt(0) == "-") {
				haxeParams.push("--define");
				haxeParams.push(a.substring(1));
			}
		}
	}

	private static function buildApp(target:String) {
		generateDisplayFile(target);
		var targetHXML:String = Path.join([paths.export, 'helper', 'build_${target}.hxml']);
		var targetPath:String = Path.join([paths.export, target]);

		trace(targetHXML);

		Sys.command('haxe', [targetHXML]);

		if (["cpp", "windows", "mac", "linux"].contains(target)) {
			var haxePath:String = Path.join([paths.export, target, 'haxe']);
			var binPath:String = Path.join([paths.export, target, 'bin']);

			targetPath = binPath;

			if (!FileSystem.exists(binPath))
				FileSystem.createDirectory(binPath);

			var exeName = switch (target) {
				case "windows": '${data.name}.exe';
				case "linux", "mac", "cpp": target == "cpp" && systemName == "Windows" ? '${data.name}.exe' : data.name;
				default: data.name;
			}

			var haxeThing:String = target == "windows"
				|| (target == "cpp" && systemName == "Windows") ? Path.join([haxePath, 'ApplicationMain.exe']) : Path.join([haxePath, 'ApplicationMain']);
			var binThing:String = Path.join([binPath, exeName]);

			File.saveBytes(binThing, File.getBytes(haxeThing));
		}

		if (target != 'eval' && target != 'interp' && target != 'run') {
			copyAssets(targetPath);
		}
	}

	private static function copyAssets(targetPath:String):Void {
		if (paths.assets == null || paths.assets.length == 0)
			return;

		for (assetDir in paths.assets) {
			if (!FileSystem.exists(assetDir)) {
				Sys.println('Warning: Asset directory not found: $assetDir');
				continue;
			}

			var destDir = Path.join([targetPath, Path.withoutDirectory(assetDir)]);

			if (!FileSystem.exists(destDir)) {
				FileSystem.createDirectory(destDir);
			}

			copyDirectory(assetDir, destDir);
		}
	}

	private static function copyDirectory(source:String, destination:String):Void {
		if (!FileSystem.exists(destination)) {
			FileSystem.createDirectory(destination);
		}

		for (file in FileSystem.readDirectory(source)) {
			var srcPath = Path.join([source, file]);
			var dstPath = Path.join([destination, file]);

			if (FileSystem.isDirectory(srcPath)) {
				copyDirectory(srcPath, dstPath);
			} else {
				File.saveBytes(dstPath, File.getBytes(srcPath));
			}
		}
	}

	private static function test(target:String) {
		switch (target) {
			case 'hl', 'hashlink':
				Sys.setCwd(Path.join([path, paths.export, target]));
				Sys.command("hl", ['${data.name}.hl']);

			case 'js', 'javascript':
				Sys.setCwd(Path.join([path, paths.export, target]));
				Sys.command("node", ['${data.name}.js']);

			case 'cpp', 'linux', 'mac', 'windows':
				Sys.setCwd(Path.join([path, paths.export, target, 'bin']));

				var exeName = switch (target) {
					case "windows": '${data.name}.exe';
					case "linux", "mac", "cpp": target == "cpp" && systemName == "Windows" ? '${data.name}.exe' : data.name;
					default: data.name;
				}

				var exePath = Path.join([path, paths.export, target, 'bin', exeName]);

				if (target != "windows" && !(target == "cpp" && systemName == "Windows")) {
					Sys.command("chmod", ["+x", exePath]);
				}

				Sys.command('"./$exeName"');

			case 'jvm', 'java':
				Sys.setCwd(Path.join([path, paths.export, target]));
				Sys.command("java", ["-jar", '${data.name}.jar']);

			case 'python', 'py':
				Sys.setCwd(Path.join([path, paths.export, target]));
				Sys.command("python", ['${data.name}.py']);

			case 'lua':
				Sys.setCwd(Path.join([path, paths.export, target]));
				Sys.command("lua", ['${data.name}.lua']);

			case 'neko':
				Sys.setCwd(Path.join([path, paths.export, target]));
				Sys.command("neko", ['${data.name}.n']);

			case 'eval', 'interp', 'run':
		}
	}

	static function setup():Void {
		try {
			if (systemName.indexOf('Win') != -1)
				installWindowsAlias();
			else if (systemName.indexOf('Linux') != -1)
				installUnixAlias(true);
			else if (systemName.indexOf('Mac') != -1)
				installUnixAlias(false);
			else {
				Sys.println('Unsupported OS for alias installation');
				Sys.exit(1);
			}

			Sys.println('Installed command-line alias "hexagon"');
		} catch (e:Dynamic) {
			Sys.println('Failed to install command-line alias');
			Sys.exit(1);
		}
	}

	private static function installWindowsAlias():Void {
		var haxePath = Sys.getEnv('HAXEPATH');
		if (haxePath == null || haxePath.trim() == '') {
			haxePath = 'C:\\HaxeToolkit\\haxe';
		} else {
			haxePath = haxePath.trim();
		}

		File.saveContent(Path.join([haxePath, 'hexagon.bat']), '@echo off\nhaxelib --global run hexagon %*');
	}

	private static function installUnixAlias(useSudo:Bool):Void {
		var sudo = useSudo ? 'sudo ' : '';
		var dest = '/usr/local/bin/hexagon';

		var scriptContent = '#!/bin/bash\nhaxelib --global run hexagon "$@"';
		var tempFile = '/tmp/hexagon_install.sh';

		File.saveContent(tempFile, scriptContent);
		Sys.command('${sudo}mv $tempFile $dest');
		Sys.command('${sudo}chmod 755 $dest');
	}
}
