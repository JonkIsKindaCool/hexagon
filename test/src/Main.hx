package;

import sys.io.File;
import hscript.Parser;
import hscript.Interp;
import sys.FileSystem;

class Main {
	public function new() {
		var scripts:Array<String> = FileSystem.readDirectory('assets/scripts');
		Sys.println('Available scripts: ${scripts.join(", ")}');

		var running:Bool =	 true;

		while (running){
			var i:String = Sys.stdin().readLine();

			if (!scripts.contains(i)){
				Sys.println('Please use one of the available scripts.');
			} else {
				new Interp().execute(new Parser().parseString(File.getContent('assets/scripts/$i')));
				running = false;
			}
		}
	}
}
