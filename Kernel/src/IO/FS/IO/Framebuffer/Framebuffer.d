module IO.FS.IO.Framebuffer.Framebuffer;

import IO.FS;
import IO.FS.IO.Framebuffer;

import Data.Address;
import Data.Color;
import Data.Font;
import Memory.Paging;

abstract class Framebuffer : FileNode {
public:
	this(PhysAddress physAddress, size_t width, size_t height) {
		super(NodePermissions.DefaultPermissions, 0);

		this.width = width;
		this.height = height;

		//TODO: Map physAddress
		pixels = physAddress.Virtual;
	}

	override bool Open() {
		if (inUse)
			return false;
		return inUse = true;
	}

	override void Close() {
		inUse = false;
	}

	override ulong Read(ubyte[] buffer, ulong offset) {
		if (!active)
			return 0;
		size_t length = width * height * Color.sizeof + size_t.sizeof * 2;
		if (offset >= length)
			return 0;
		ulong size = buffer.length;
		ulong end = size + offset;
		if (end > length) {
			end = length;
			long tmp = end - offset;
			size = (tmp < 0) ? 0 : tmp;
		}

		size_t[] header = [width, height];

		if (offset < 16) {
			auto wroteHeader = ((size < 16) ? size : 16) - offset;
			memcpy(buffer.ptr, &header[offset], wroteHeader);
			if (buffer.length > size)
				memcpy(&buffer[wroteHeader], pixels.Ptr, size - wroteHeader);
		} else
			memcpy(buffer.ptr, &pixels.Ptr[offset - 16], size);

		return size;

	}

	override ulong Write(ubyte[] buffer, ulong offset) {
		if (!active)
			return 0;

		size_t pixelLength = width * height * Color.sizeof;
		if (offset > pixelLength)
			return 0;

		size_t size = buffer.length;
		if (size + offset > pixelLength)
			size = pixelLength - offset;
		memcpy(&pixels.Ptr[offset], buffer.ptr, size);
		return buffer.length;
	}

	void RenderPixel(ssize_t x, ssize_t y, Color c) {
		if (!active)
			return;
		putPixel(x, y, c);
	}

	void RenderText(Font font, string str, ssize_t x, ssize_t y, Color fg, Color bg) {
		if (!active)
			return;
		renderText(font, str, x, y, fg, bg);
	}

	void RenderChar(Font font, dchar str, ssize_t x, ssize_t y, Color fg, Color bg) {
		if (!active)
			return;
		renderChar(font, str, x, y, fg, bg);
	}

	void RenderRect(ssize_t x, ssize_t y, size_t width, size_t height, Color color) {
		if (!active)
			return;
		renderRect(x, y, width, height, color);
	}

	void RenderLine(ssize_t x0, ssize_t y0, ssize_t x1, ssize_t y1, Color c) {
		if (!active)
			return;
		renderLine(x0, y0, x1, y1, c);
	}

	void RenderCircle(ssize_t x0, ssize_t y0, ssize_t radius, Color color) {
		if (!active)
			return;
		renderCircle(x0, y0, radius, color);
	}

	void MoveRegion(ssize_t toX, ssize_t toY, ssize_t fromX, ssize_t fromY, size_t width, size_t height) {
		if (!active)
			return;

		moveRegion(toX, toY, fromX, fromY, width, height);
	}

	@property size_t Width() {
		return width;
	}

	@property size_t Height() {
		return height;
	}

	@property bool Active() {
		return active;
	}

	@property bool Active(bool active) {
		if (active && !this.active)
			OnActivate();
		else if (!active && this.active)
			OnDisable();

		this.active = active;
		return active;
	}

protected:
	size_t width;
	size_t height;

	/// Activate the Framebuffer.
	/// This should set the needed mode and rerender everything.
	abstract void OnActivate();
	abstract void OnDisable();

private:
	bool inUse;
	VirtAddress pixels;
	bool active;

	pragma(inline, true) void putPixel(ssize_t x, ssize_t y, Color color) {
		if (x < 0 && y < 0)
			return;
		*(pixels + (y * width + x) * Color.sizeof).Ptr!Color = color;
	}

	void renderText(Font font, string str, ssize_t x, ssize_t y, Color fg, Color bg) {
		foreach (ch; str)
			RenderChar(font, ch, x += font.Width, y, fg, bg);
	}

	void renderChar(Font font, dchar ch, ssize_t x, ssize_t y, Color fg, Color bg) {
		ulong[] charData = font.GetChar(ch);
		foreach (idxRow, ulong row; charData)
			foreach (column; 0 .. font.Width)
				putPixel(x + column, y + idxRow, (row & (1 << (font.Width - 1 - column))) ? fg : bg);

		// XXX: Yes this is a memory leak, but it crashes
		//charData.destroy;
	}

	void renderRect(ssize_t x, ssize_t y, size_t width, size_t height, Color color) {
		for (ssize_t yy = y; yy < y + height; yy++)
			for (ssize_t xx = x; xx < x + width; xx++)
				putPixel(xx, yy, color);
	}

	void renderLine(ssize_t x0, ssize_t y0, ssize_t x1, ssize_t y1, Color c) {
		import Data.Util : abs;

		//Bresenham's line algorithm
		const ssize_t steep = abs(y1 - y0) > abs(x1 - x0);
		long inc = -1;

		if (steep) {
			ssize_t tmp = x0;
			x0 = y0;
			y0 = tmp;

			tmp = x1;
			x1 = y1;
			y1 = tmp;
		}

		if (x0 > x1) {
			ssize_t tmp = x0;
			x0 = x1;
			x1 = tmp;

			tmp = y0;
			y0 = y1;
			y1 = tmp;
		}

		if (y0 < y1)
			inc = 1;

		ssize_t dx = cast(ssize_t)abs(x0 - x1);
		ssize_t dy = cast(ssize_t)abs(y1 - y0);
		ssize_t e = 0;
		ssize_t y = y0;
		ssize_t x = x0;

		for (; x <= x1; x++) {
			if (steep)
				putPixel(y, x, c);
			else
				putPixel(x, y, c);

			if ((e + dy) << 1 < dx)
				e += dy;
			else {
				y += inc;
				e += dy - dx;
			}
		}
	}

	void renderCircle(ssize_t x0, ssize_t y0, ssize_t radius, Color color) {
		//Midpoint circle algorithm
		ssize_t x = radius;
		ssize_t y = 0;
		ssize_t radiusError = 1 - x;

		while (x >= y) {
			putPixel(x + x0, y + y0, color);
			putPixel(y + x0, x + y0, color);
			putPixel(-x + x0, y + y0, color);
			putPixel(-y + x0, x + y0, color);
			putPixel(-x + x0, -y + y0, color);
			putPixel(-y + x0, -x + y0, color);
			putPixel(x + x0, -y + y0, color);
			putPixel(y + x0, -x + y0, color);
			y++;
			if (radiusError < 0)
				radiusError += 2 * y + 1;
			else {
				x--;
				radiusError += 2 * (y - x) + 1;
			}
		}
	}

	void moveRegion(ssize_t toX, ssize_t toY, ssize_t fromX, ssize_t fromY, size_t width, size_t height) {
		if (fromY >= toY)
			foreach (row; 0 .. height)
				memmove((pixels + ((toY + row) * this.width + toX) * Color.sizeof).Ptr,
						(pixels + ((fromY + row) * this.width + fromX) * Color.sizeof).Ptr, width * Color.sizeof);
		else
					foreach_reverse (row; 0 .. height)
						memmove((pixels + ((toY + row) * this.width + toX) * Color.sizeof).Ptr,
								(pixels + ((fromY + row) * this.width + fromX) * Color.sizeof).Ptr, width * Color.sizeof);
	}
}
