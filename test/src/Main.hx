package;

import sdl.Types.WindowPos;
import sdl.Types.InitFlags;
import sdl.Types.Event;
import sdl.Types.WindowInitFlags;
import sdl.SDL;
import sdl.Types.Window;
import hscript.Parser;
import hscript.Interp;

class Main {
	public function new() {
		SDL.init(VIDEO | AUDIO | EVENTS);

		var w:Window = SDL.createWindow("aea", WindowPos.CENTERED, WindowPos.CENTERED, 800, 600, WindowInitFlags.ALLOW_HIGHDPI);

		var ev:Event = SDL.makeEvent();
		var running:Bool = true;

		while (running) {
			while (SDL.pollEvent(ev) != 0) {
				switch (ev.ref.type) {
					case QUIT:
						running = false;
					case _:
				}
			}
		}

        SDL.destroyWindow(w);
		SDL.quit();
	}
}
