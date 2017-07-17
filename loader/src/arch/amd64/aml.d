/**
 * A AML helper module
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module arch.amd64.aml;

/// Opcodes that exist in AML
enum AMLOpcodes : ubyte {
	nameOP = 0x08, ///
	bytePrefix = 0x0A, ///
	packageOP = 0x12 ///
}
