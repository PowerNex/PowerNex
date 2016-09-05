module PowerNex.Data.Parameters;

template Parameters(func...) {
	static if (is(typeof(&func[0]) Fsym : Fsym*) && is(Fsym == function))
		static if (is(Fsym P == function))
			alias Parameters = P;
		else
			static assert(0, "argument has no parameters");
}
