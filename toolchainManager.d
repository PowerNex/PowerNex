#!/usr/bin/env rdmd
/**
 * PowerNex's toolchain manager
 *
 * Copyright: © 2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: Dan Printzell
 */

pragma(lib, "curl");

import core.sys.posix.stdio : fgets;
import core.sys.posix.unistd : isatty;
import core.stdc.string : strlen;
import std.stdio : write, writeln, stdout, stderr, stdin, File;
import std.file : exists, readText, fwrite = write, rmdirRecurse, mkdirRecurse;
import std.ascii : toLower, toUpper;
import std.json : JSONValue, parseJSON, JSON_TYPE;
import std.net.curl : get, HTTP;
import std.range : repeat;
import std.math : isNaN;
import std.format : format;
import std.process : executeShell, pipeShell, wait, ProcessPipes, Redirect;
import std.conv : to;
import std.typecons : Yes, No, Flag;
import std.getopt : getopt, defaultGetoptPrinter;

//
enum size_t major = 1;
enum size_t minor = 0;
enum size_t patch = 0;

//Flags
bool showVersion;
bool clean;
bool noconfirm;

void normal(Args...)(Args args) {
	write("\x1b[39;1m", args, "\x1b[0m");
}

void good(Args...)(Args args) {
	write("\x1b[33;1m", args, "\x1b[0m");
}

void warning(Args...)(Args args) {
	stderr.write("\x1b[31;1m", args, "\x1b[0m");
}

void error(Args...)(Args args) {
	stderr.write("\x1b[37;41;1m", args, "\x1b[0m");
}

//Version = Successfull ci build
struct VersionInfo {
	size_t dmdVersion;
	size_t binutilsVersion;
}

const string toolchainFolder = "build/cc";
const string versionInfoFile = toolchainFolder ~ "/versionInfo";

VersionInfo getOldInfo() {
	VersionInfo oldVI;
	if (!exists(versionInfoFile))
		return oldVI;

	JSONValue data = parseJSON(readText(versionInfoFile));
	if (auto _ = "dmdVersion" in data) {
		if (_.type == JSON_TYPE.UINTEGER)
			oldVI.dmdVersion = _.uinteger;
		else
			oldVI.dmdVersion = cast(ulong)_.integer;
	}
	if (auto _ = "binutilsVersion" in data) {
		if (_.type == JSON_TYPE.UINTEGER)
			oldVI.binutilsVersion = _.uinteger;
		else
			oldVI.binutilsVersion = cast(ulong)_.integer;
	}

	return oldVI;
}

VersionInfo getNewInfo() {
	size_t getLatestVersion(string url) {
		JSONValue data = parseJSON(get(url));
		auto _ = data["lastCompletedBuild"]["number"];
		if (_.type == JSON_TYPE.UINTEGER)
			return _.uinteger;
		else
			return cast(ulong)_.integer;
	}

	VersionInfo newVI;
	newVI.dmdVersion = getLatestVersion("https://ci.vild.io/job/PowerNex/job/powernex-dmd/job/master/api/json");
	newVI.binutilsVersion = getLatestVersion("https://ci.vild.io/job/PowerNex/job/powernex-binutils/job/master/api/json");

	return newVI;
}

char question(char defaultAlt, char[] alternative, Args...)(Args args) {
	char[64] data;

	warning(args, " [");
	foreach (idx, alt; alternative) {
		if (idx)
			warning("/");
		if (alt == defaultAlt)
			alt = alt.toUpper;
		warning(alt);
	}
	warning("]: ");

	stdout.flush();
	stderr.flush();

	if (noconfirm) {
		warning("\n");
		return defaultAlt;
	}

	if (!fgets(data.ptr, data.length, stdin.getFP)) {
		error("[fgets] Is stdin valid?\n");
		return char.init;
	}

	char[] input = data[0 .. data.ptr.strlen];

	char[2] altStr;
	altStr[1] = '\0';
	foreach (alt; alternative) {
		altStr[0] = alt.toLower;

		if (!strcasecmp(altStr, input))
			return alt;
	}
	if (!strcasecmp("\n", input))
		return defaultAlt;

	error("Invalid choice!\n");
	return char.init;
}

struct SaveFile {
	File f;

	@disable this();
	this(string path) {
		f = File(path, "wb");
	}

	~this() {
		f.close();
	}

	size_t opCall(ubyte[] data) {
		f.rawWrite(data);
		return data.length;
	}
}

struct ProcessPipe {
	ProcessPipes p;

	@disable this();
	this(string command, Flag!"IgnoreStdOut" ignoreStdOut = No.IgnoreStdOut, Flag!"IgnoreStdErr" ignoreStdErr = No.IgnoreStdErr) {
		Redirect flags = Redirect.stdin;
		if (ignoreStdOut)
			flags |= Redirect.stdout;
		if (ignoreStdErr)
			flags |= Redirect.stderr;

		p = pipeShell(command, flags);
	}

	~this() {
		p.stdin.flush();
		p.stdin.close();
		wait(p.pid);
	}

	size_t opCall(ubyte[] data) {
		p.stdin.rawWrite(data);
		return data.length;
	}
}

void downloadProgress(T = SaveFile, Args...)(string name, const(char)[] url, Args args) {
	T receiver = T(args);
	HTTP http = HTTP(url); // Because opCall
	http.onReceive = (ubyte[] data) => receiver(data);

	normal("\x1b[?25l");

	static float lastDiff = -1;

	http.onProgress = (size_t total, size_t current, size_t _, size_t __) {
		import std.string : leftJustifier;

		enum width = 64;
		float fDiff = cast(float)current / cast(float)total;
		if (fDiff.isNaN)
			fDiff = 0;
		if (cast(size_t)(100 * lastDiff) == cast(size_t)(100 * fDiff))
			return 0;

		size_t procent = cast(size_t)(100 * fDiff);

		size_t filled = cast(size_t)(width * fDiff * 8);

		dchar[] step = [' ', '▏', '▎', '▍', '▋', '▊', '▉', '█'];

		long fullFilled = cast(long)(filled) / 8;
		if (fullFilled < 0)
			fullFilled = 0;
		long empty = width - fullFilled - 1;
		if (empty < 0)
			empty = 0;

		normal("\r", name, ":", leftJustifier("", 8 - name.length + 1, ' '), format("%3d", procent), "% \x1b[36;46;1m",
				repeat(step[$ - 1], fullFilled), repeat(step[filled % 8], (procent != 100) * 1), repeat(step[0], empty));
		return 0;
	};
	http.perform();
	normal("\x1b[?25h\n");
}

int main(string[] args) {
	static string versionMsg = "PowerNex's toolchain manager v" ~ major.to!string ~ "." ~ minor.to!string ~ "."
		~ patch.to!string ~ "\n" ~ "Copyright © 2017, Dan Printzell - https://github.com/Vild/PowerNex";

	// dfmt off
	auto helpInformation = getopt(args,
		"v|version", "Show the updaters version", &showVersion,
		"c|clean", "Clean out the toolchain folder before starting", &clean,
		"noconfirm", "Always choose the default answer to questions", &noconfirm
	);
	// dfmt on

	if (helpInformation.helpWanted) {
		defaultGetoptPrinter(versionMsg, helpInformation.options);
		return 0;
	}
	if (showVersion) {
		writeln(versionMsg);
		return 0;
	}

	normal("PowerNex's toolchain manager - https://github.com/Vild/PowerNex\n");
	VersionInfo oldVI = clean ? VersionInfo.init : getOldInfo();
	VersionInfo newVI = getNewInfo();
	bool newDMD = newVI.dmdVersion > oldVI.dmdVersion;
	bool newBinutils = newVI.binutilsVersion > oldVI.binutilsVersion;
	if (!newDMD && !newBinutils) {
		good("You already have the latest toolchain!\n");
		return 0;
	}

	if (newDMD) {
		if (oldVI.dmdVersion)
			good("There is a new DMD version! (from: v.", oldVI.dmdVersion, " to: v.", newVI.dmdVersion, ")\n");
		else
			good("DMD is missing! Will download version ", newVI.dmdVersion, ".\n");
	}
	if (newBinutils) {
		if (oldVI.binutilsVersion)
			good("There is a new BINUTILS version! (from: v.", oldVI.binutilsVersion, " to: v.", newVI.binutilsVersion, ")\n");
		else
			good("BINUTILS is missing! Will download version ", newVI.binutilsVersion, ".\n");
	}

	char answer = question!('y', ['y', 'n'])("Do you want to continue with the download?");
	if (answer == char.init)
		return -1;
	if (answer == 'n')
		return 0;
	if (exists(toolchainFolder)) {
		if (!clean) {
			answer = question!('n', ['y', 'n'])("Erase the toolchains folder content before starting? (Will force download everything)");
			if (answer == char.init)
				return -1;
			clean |= answer == 'y';
		}
		if (clean)
			rmdirRecurse(toolchainFolder);
	}

	mkdirRecurse(toolchainFolder ~ "/bin");
	if (newDMD || clean) {
		downloadProgress("DMD", "https://ci.vild.io/job/PowerNex/job/powernex-dmd/job/master/" ~ newVI.dmdVersion.to!string ~ "/artifact/powernex-dmd",
				toolchainFolder ~ "/bin/powernex-dmd");
		normal("Fixing permissions...\n");
		executeShell("chmod +x " ~ toolchainFolder ~ "/bin/powernex-dmd");
	}

	if (newBinutils || clean) {
		downloadProgress!ProcessPipe("BINUTILS",
				"https://ci.vild.io/job/PowerNex/job/powernex-binutils/job/master/" ~ newVI.binutilsVersion.to!string ~ "/artifact/powernex-binutils.tar.xz",
				"tar xkJ --no-same-owner -C " ~ toolchainFolder, No.IgnoreStdOut, Yes.IgnoreStdErr);
	}

	normal("Saving new version file...\n");
	{
		JSONValue data = ["dmdVersion" : newVI.dmdVersion, "binutilsVersion" : newVI.binutilsVersion];
		fwrite(versionInfoFile, data.toString);
	}
	normal("Everything is now up to date :)\n");

	return 0;
}

// Not defined in phobos, or has a wrapper in core.sys.posix.string
int strcasecmp(scope const char[] s1, scope const char[] s2) @trusted pure @nogc {
	size_t len = s1.length < s2.length ? s1.length : s2.length;
	size_t idx;
	while (idx < len && s1[idx]) {
		if (s1[idx].toLower != s2[idx].toLower)
			return s1[idx] - s2[idx];
		idx++;
	}
	return 0;
}
