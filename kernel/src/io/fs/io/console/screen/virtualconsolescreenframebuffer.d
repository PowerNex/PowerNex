module IO.FS.IO.Console.Screen.VirtualConsoleScreenFramebuffer;

import IO.FS;
import IO.FS.IO.Console.Screen;
import IO.FS.IO.Framebuffer;

import Data.Color;
import Data.Font;

final class VirtualConsoleScreenFramebuffer : VirtualConsoleScreen {
public:
	this(Framebuffer fb, Font font) {
		super(fb.Width / font.Width, fb.Height / font.Height, FormattedChar(' ', Color(0xFF, 0xFF, 0xFF), Color(0x00,
				0x00, 0x00), CharStyle.None));
		this.fb = fb;
		this.font = font;
	}

protected:
	override void OnScroll(size_t lineCount) {
		size_t startRow = font.Height * lineCount;
		size_t rows = font.Height * height - startRow;

		fb.MoveRegion(0, 0, 0, startRow, fb.Width, rows);
		fb.RenderRect(0, rows, fb.Width, startRow, clearChar.bg);
	}

	override void UpdateCursor() {
		FormattedChar ch = screen[curY * width + curX];
		Color tmp = ch.fg;
		ch.fg = ch.bg;
		ch.bg = tmp;

		fb.RenderChar(font, ch.ch, curX * font.Width, curY * font.Height, ch.fg, ch.bg);
	}

	override void UpdateChar(size_t x, size_t y) {
		auto ch = screen[y * width + x];
		fb.RenderChar(font, ch.ch, x * font.Width, y * font.Height, ch.fg, ch.bg);
	}

	@property override bool Active(bool active) {
		fb.Active = active;
		return super.Active(active);
	}

private:
	Framebuffer fb;
	Font font;

	void rerender() {
		foreach (idx, ch; screen)
			fb.RenderChar(font, ch.ch, idx % font.Width, idx / font.Height, ch.fg, ch.bg);
		UpdateCursor();
	}
}
