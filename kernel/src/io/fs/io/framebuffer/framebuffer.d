module io.fs.io.framebuffer.framebuffer;

import io.fs;
import io.fs.io.framebuffer;

import data.address;
import data.color;
import data.font;
import memory.paging;

abstract class Framebuffer : FileNode {
public:
	this(PhysAddress physAddress, size_t width, size_t height) {
		super(NodePermissions.defaultPermissions, 0);

		_width = width;
		_height = height;

		//TODO: Map physAddress
		_pixels = physAddress.virtual;
	}

	override bool open() {
		if (_inUse)
			return false;
		return _inUse = true;
	}

	override void close() {
		_inUse = false;
	}

	override ulong read(ubyte[] buffer, ulong offset) {
		if (!_active)
			return 0;
		size_t length = _width * _height * Color.sizeof + size_t.sizeof * 2;
		if (offset >= length)
			return 0;
		ulong size = buffer.length;
		ulong end = size + offset;
		if (end > length) {
			end = length;
			long tmp = end - offset;
			size = (tmp < 0) ? 0 : tmp;
		}

		size_t[] header = [_width, _height];

		if (offset < 16) {
			auto wroteHeader = ((size < 16) ? size : 16) - offset;
			memcpy(buffer.ptr, &header[offset], wroteHeader);
			if (buffer.length > size)
				memcpy(&buffer[wroteHeader], _pixels.ptr, size - wroteHeader);
		} else
			memcpy(buffer.ptr, &_pixels.ptr[offset - 16], size);

		return size;

	}

	override ulong write(ubyte[] buffer, ulong offset) {
		if (!_active)
			return 0;

		size_t pixelLength = _width * _height * Color.sizeof;
		if (offset > pixelLength)
			return 0;

		size_t size = buffer.length;
		if (size + offset > pixelLength)
			size = pixelLength - offset;
		memcpy(&_pixels.ptr[offset], buffer.ptr, size);
		return buffer.length;
	}

	void renderPixel(ssize_t x, ssize_t y, Color c) {
		if (!_active)
			return;
		putPixel(x, y, c);
	}

	void renderText(Font font, string str, ssize_t x, ssize_t y, Color fg, Color bg) {
		if (!_active)
			return;
		_renderText(font, str, x, y, fg, bg);
	}

	void renderChar(Font font, dchar str, ssize_t x, ssize_t y, Color fg, Color bg) {
		if (!_active)
			return;
		_renderChar(font, str, x, y, fg, bg);
	}

	void renderRect(ssize_t x, ssize_t y, size_t _width, size_t _height, Color color) {
		if (!_active)
			return;
		_renderRect(x, y, _width, _height, color);
	}

	void renderLine(ssize_t x0, ssize_t y0, ssize_t x1, ssize_t y1, Color c) {
		if (!_active)
			return;
		_renderLine(x0, y0, x1, y1, c);
	}

	void renderCircle(ssize_t x0, ssize_t y0, ssize_t radius, Color color) {
		if (!_active)
			return;
		_renderCircle(x0, y0, radius, color);
	}

	void moveRegion(ssize_t toX, ssize_t toY, ssize_t fromX, ssize_t fromY, size_t _width, size_t _height) {
		if (!_active)
			return;

		_moveRegion(toX, toY, fromX, fromY, _width, _height);
	}

	@property size_t width() {
		return _width;
	}

	@property size_t height() {
		return _height;
	}

	@property bool active() {
		return _active;
	}

	@property bool active(bool active) {
		if (active && !_active)
			onActivate();
		else if (!active && _active)
			onDisable();

		_active = active;
		return _active;
	}

protected:
	size_t _width;
	size_t _height;

	/// Activate the Framebuffer.
	/// This should set the needed mode and rerender everything.
	abstract void onActivate();
	abstract void onDisable();

private:
	bool _inUse;
	VirtAddress _pixels;
	bool _active;

	pragma(inline, true) void putPixel(ssize_t x, ssize_t y, Color color) {
		if (x < 0 && y < 0)
			return;
		*(_pixels + (y * _width + x) * Color.sizeof).ptr!Color = color;
	}

	void _renderText(Font font, string str, ssize_t x, ssize_t y, Color fg, Color bg) {
		foreach (ch; str)
			_renderChar(font, ch, x += font.width, y, fg, bg);
	}

	void _renderChar(Font font, dchar ch, ssize_t x, ssize_t y, Color fg, Color bg) {
		ulong[] charData = new ulong[font.bufferSize];
		foreach (idxRow, ulong row; font.getChar(ch, charData))
			foreach (column; 0 .. font.width)
				putPixel(x + column, y + idxRow, (row & (1 << (font.width - 1 - column))) ? fg : bg);

		charData.destroy;
	}

	void _renderRect(ssize_t x, ssize_t y, size_t _width, size_t _height, Color color) {
		for (ssize_t yy = y; yy < y + _height; yy++)
			for (ssize_t xx = x; xx < x + _width; xx++)
				putPixel(xx, yy, color);
	}

	void _renderLine(ssize_t x0, ssize_t y0, ssize_t x1, ssize_t y1, Color c) {
		import data.util : abs;

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

	void _renderCircle(ssize_t x0, ssize_t y0, ssize_t radius, Color color) {
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

	void _moveRegion(ssize_t toX, ssize_t toY, ssize_t fromX, ssize_t fromY, size_t _width, size_t _height) {
		if (fromY >= toY)
			foreach (row; 0 .. _height)
				memmove((_pixels + ((toY + row) * this._width + toX) * Color.sizeof).ptr,
						(_pixels + ((fromY + row) * this._width + fromX) * Color.sizeof).ptr, _width * Color.sizeof);
		else
					foreach_reverse (row; 0 .. _height)
						memmove((_pixels + ((toY + row) * this._width + toX) * Color.sizeof).ptr,
								(_pixels + ((fromY + row) * this._width + fromX) * Color.sizeof).ptr, _width * Color.sizeof);
	}
}
