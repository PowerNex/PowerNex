module gfx.powernex.gfx.ppm;

@safe struct PPM {
public:
	this(ubyte[] data) {
		assert(data[0] == 'P');
		assert(data[1] == '6');

		data = data[2 .. $];
		alias isWhitespace = (ubyte b) => b == ' ' || b == '\t' || b == '\r' || b == '\n';
		void skipWhitespace() {
			assert(isWhitespace(data[0]));
			do {
				if (data[0] == '#') {
					while (data[0] != '\n')
						data = data[1 .. $];
				}
				data = data[1 .. $];
			}
			while (isWhitespace(data[0]) || data[0] == '#');
		}

		size_t readInt() {
			size_t val;
			assert(data[0] >= '0' && data[0] <= '9');
			do {
				val = val * 10 + data[0] - '0';
				data = data[1 .. $];
			}
			while (data[0] >= '0' && data[0] <= '9');
			return val;
		}

		skipWhitespace();
		_width = readInt();
		skipWhitespace();
		_height = readInt();
		skipWhitespace();
		_maxVal = readInt();

		assert(isWhitespace(data[0]));
		_data = data[1 .. $]; //TODO: dup
	}

	@property size_t width() {
		return _width;
	}

	@property size_t height() {
		return _height;
	}

	@property size_t maxVal() {
		return _maxVal;
	}

	@property const(ubyte)[] data() {
		return _data;
	}

private:
	size_t _width;
	size_t _height;
	size_t _maxVal;

	ubyte[] _data;
}
