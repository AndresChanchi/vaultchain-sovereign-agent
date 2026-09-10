pub mod KipioAccountChain {
    pub struct Chain;

    impl ::dafny_runtime::DafnyPrint for Chain {
        fn fmt_print(&self, f: &mut ::std::fmt::Formatter<'_>, _in_seq: bool) -> ::std::fmt::Result {
            write!(f, "Chain")
        }
    }
}
