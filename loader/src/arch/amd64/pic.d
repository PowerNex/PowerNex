/**
 * A $(I 8259 Programmable Interrupt Controller), also called PIC, helper module
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module arch.amd64.pic;

///
@safe static struct PIC {
public static:
	///
	@property ref bool enabled() @trusted {
		__gshared bool isEnabled = true;
		return isEnabled;
	}

	///
	void disable() {
		import io.ioport : outp;

		enum masterPort = 0x21;
		enum slavePort = 0xA1;

		outp!ubyte(masterPort, 0xFF);
		outp!ubyte(slavePort, 0xFF);
		enabled = false;
	}
}
