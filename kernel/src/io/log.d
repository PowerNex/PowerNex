module io.log;

import io.com;
import data.string;

__gshared Log log;

enum LogLevel {
	VERBOSE = '&',
	DEBUG   = '+',
	INFO    = '*',
	WARNING = '#',
	ERROR   = '-',
	FATAL   = '!'
}

struct Log {
	int indent;

	void Init() {
		COM1.Init();
		indent = 0;
	}

	void opCall(string file = __FILE__, string func = __PRETTY_FUNCTION__, int line = __LINE__)(LogLevel level, string msg = "") {
		for (int i = 0; i < indent; i++)
			COM1.Write(' ');

		COM1.Write('[', cast(char)level, "] ", file /*, ": ", func*/, '@');

		ubyte[int.sizeof * 8] buf;
		auto start = itoa(line, buf.ptr, buf.length, 10);
		for (size_t i = start; i < buf.length; i++)
			COM1.Write(buf[i]);

		COM1.Write("> ", msg);

		COM1.Write("\r\n");
	}

	void Verbose(string file = __FILE__, string func = __PRETTY_FUNCTION__, int line = __LINE__)(string msg = "") {
		this.opCall!(file, func, line)(LogLevel.VERBOSE, msg);
	}

	void Debug(string file = __FILE__, string func = __PRETTY_FUNCTION__, int line = __LINE__)(string msg = "") {
		this.opCall!(file, func, line)(LogLevel.DEBUG, msg);
	}

	void Info(string file = __FILE__, string func = __PRETTY_FUNCTION__, int line = __LINE__)(string msg = "") {
		this.opCall!(file, func, line)(LogLevel.INFO, msg);
	}

	void Warning(string file = __FILE__, string func = __PRETTY_FUNCTION__, int line = __LINE__)(string msg = "") {
		this.opCall!(file, func, line)(LogLevel.WARNING, msg);
	}

	void Error(string file = __FILE__, string func = __PRETTY_FUNCTION__, int line = __LINE__)(string msg = "") {
		this.opCall!(file, func, line)(LogLevel.ERROR, msg);
	}

	void Fatal(string file = __FILE__, string func = __PRETTY_FUNCTION__, int line = __LINE__)(string msg = "") {
		this.opCall!(file, func, line)(LogLevel.FATAL, msg);
	}

}
