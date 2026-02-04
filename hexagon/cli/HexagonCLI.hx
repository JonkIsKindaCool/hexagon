package hexagon.cli;

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
		}

		Sys.setCwd(oldCwd);
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
		data = Json.parse(File.getContent("build.json"));

		paths = data.paths;
		build = data.build;
		defines = data.defines;
		macros = data.macros;
		dependencies = data.dependencies;

		applicationTemplate = {"package;\n"
			+ 'import ${build.main};\n'
			+ "class ApplicationMain {\n"
			+ "   public static function main(){\n"
			+ '        new ${build.main}();\n'
			+ "   }\n"
			+ "}\n";
		};

		if (!FileSystem.exists(paths.export))
			FileSystem.createDirectory(paths.export);

		if (target != "run" && target != "eval" && target != "interp") {
			if (!FileSystem.exists(paths.export + '/' + target))
				FileSystem.createDirectory(paths.export + '/' + target);
		}

		if (!FileSystem.exists(paths.export + '/helper'))
			FileSystem.createDirectory(paths.export + '/helper');

		File.saveContent(paths.export + '/helper/ApplicationMain.hx', applicationTemplate);

		var haxeParams:Array<String> = [];

		haxeParams.push("--class-path");
		haxeParams.push(paths.export + '/helper');

		for (classPath in paths.source) {
			haxeParams.push("--class-path");
			haxeParams.push(classPath);
		}

		for (d in dependencies) {
			haxeParams.push("--library");

			if (d.version != null) {
				haxeParams.push('${d.name}:${d.version}');
			} else {
				haxeParams.push('${d.name}');
			}
		}

		if (build.dce != null) {
			haxeParams.push("--dce");
			haxeParams.push(build.dce);
		}

		if (build.debug != null) {
			if (build.debug) {
				haxeParams.push("--debug");
			}
		}

		if (build.verbose != null) {
			if (build.verbose) {
				haxeParams.push("--verbose");
			}
		}

		if (build.optimize != null) {
			if (build.optimize) {
				haxeParams.push("--no-opt");
			}
		}

		if (defines != null) {
			for (d in defines) {
				haxeParams.push("--define");
				haxeParams.push(d);
			}
		}

		addDefines(args, haxeParams);

		if (macros != null) {
			for (m in macros) {
				haxeParams.push("--macro");
				haxeParams.push(m);
			}
		}

		haxeParams.push("--main");
		haxeParams.push("ApplicationMain");

		switch (target) {
			case 'hl', 'hashlink':
				haxeParams.push("--hl");
				haxeParams.push(Path.join([paths.export, target, '${data.name}.hl']));
				Sys.command("haxe", haxeParams);

			case 'js', 'javascript':
				haxeParams.push("--js");
				haxeParams.push(Path.join([paths.export, target, '${data.name}.js']));
				Sys.command("haxe", haxeParams);

			case "cpp", "linux", "mac", "windows":
				var haxePath:String = Path.join([paths.export, target, 'haxe']);
				var binPath:String = Path.join([paths.export, target, 'bin']);

				haxeParams.push("--cpp");
				haxeParams.push(haxePath);

				switch (target) {
					case "linux":
						haxeParams.push("-D");
						haxeParams.push("linux");
					case "mac":
						haxeParams.push("-D");
						haxeParams.push("mac");
					case "windows":
						haxeParams.push("-D");
						haxeParams.push("windows");
				}

				Sys.command("haxe", haxeParams);

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

			case 'cs', 'csharp':
				var haxePath:String = Path.join([paths.export, target, 'haxe']);
				var binPath:String = Path.join([paths.export, target, 'bin']);

				haxeParams.push("--cs");
				haxeParams.push(haxePath);

				Sys.command("haxe", haxeParams);

				if (!FileSystem.exists(binPath))
					FileSystem.createDirectory(binPath);

				var haxeThing:String = systemName == "Windows" ? Path.join([haxePath, 'bin', 'ApplicationMain.exe']) : Path.join([haxePath, 'bin', 'ApplicationMain']);
				var binThing:String = systemName == "Windows" ? Path.join([binPath, '${data.name}.exe']) : Path.join([binPath, '${data.name}']);

				File.saveBytes(binThing, File.getBytes(haxeThing));

			case 'jvm', 'java':
				haxeParams.push("--jvm");
				haxeParams.push(Path.join([paths.export, target, '${data.name}.jar']));
				Sys.command("haxe", haxeParams);

			case 'python', 'py':
				haxeParams.push("--python");
				haxeParams.push(Path.join([paths.export, target, '${data.name}.py']));
				Sys.command("haxe", haxeParams);

			case 'lua':
				haxeParams.push("--lua");
				haxeParams.push(Path.join([paths.export, target, '${data.name}.lua']));
				Sys.command("haxe", haxeParams);

			case 'neko':
				haxeParams.push("--neko");
				haxeParams.push(Path.join([paths.export, target, '${data.name}.n']));
				Sys.command("haxe", haxeParams);

			case 'eval', 'interp', 'run':
				haxeParams.push("--interp");
				Sys.command("haxe", haxeParams);
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

				Sys.command('./$exeName');

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
