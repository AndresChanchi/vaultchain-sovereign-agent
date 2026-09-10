//! kipio_domain_externs
//!
//! Rust implementation of every abstract type that Dafny marks
//! with `{:extern}` inside the Kipio Account formal domain.
//!
//! Each `pub mod` here corresponds one-to-one to a Dafny module
//! that declares an abstract type. The generated Rust crate
//! re-exports these modules at its root, so that the code emitted
//! by `dafny translate rs` (which references
//! `crate::<Module>::<Type>`) resolves correctly.
//!
//! All types derive `Clone` because `dafny_runtime::Sequence<T>`
//! requires `T: DafnyType`, and `DafnyType` is implemented for
//! every `T: Clone`. `Debug`, `PartialEq`, `Eq`, `Hash` are added
//! because the generated consumers use them (comparison, hashing).
//!
//! If a type is used in sequences but does not derive Clone, the
//! generated crate will fail to compile with
//! `error[E0277]: the trait bound ...: Clone is not satisfied`.

pub mod KipioAccountChain {
    #[derive(Clone, Debug, PartialEq, Eq, Hash)]
    pub struct Chain;

    impl ::dafny_runtime::DafnyPrint for Chain {
        fn fmt_print(
            &self,
            f: &mut ::std::fmt::Formatter<'_>,
            _in_seq: bool,
        ) -> ::std::fmt::Result {
            write!(f, "Chain")
        }
    }
}

pub mod KipioAccountDomainAction {
    #[derive(Clone, Debug, PartialEq, Eq, Hash)]
    pub struct DomainAction;

    impl ::dafny_runtime::DafnyPrint for DomainAction {
        fn fmt_print(
            &self,
            f: &mut ::std::fmt::Formatter<'_>,
            _in_seq: bool,
        ) -> ::std::fmt::Result {
            write!(f, "DomainAction")
        }
    }
}

pub mod KipioAccountExecutionTarget {
    #[derive(Clone, Debug, PartialEq, Eq, Hash)]
    pub struct ExecutionTarget;

    impl ::dafny_runtime::DafnyPrint for ExecutionTarget {
        fn fmt_print(
            &self,
            f: &mut ::std::fmt::Formatter<'_>,
            _in_seq: bool,
        ) -> ::std::fmt::Result {
            write!(f, "ExecutionTarget")
        }
    }
}

pub mod KipioAccountExecutionConstraints {
    #[derive(Clone, Debug, PartialEq, Eq, Hash)]
    pub struct ExecutionConstraints;

    impl ::dafny_runtime::DafnyPrint for ExecutionConstraints {
        fn fmt_print(
            &self,
            f: &mut ::std::fmt::Formatter<'_>,
            _in_seq: bool,
        ) -> ::std::fmt::Result {
            write!(f, "ExecutionConstraints")
        }
    }
}

pub mod KipioAccountExecutionSemantics {
    #[derive(Clone, Debug, PartialEq, Eq, Hash)]
    pub struct ExecutionEnvironment;

    impl ::dafny_runtime::DafnyPrint for ExecutionEnvironment {
        fn fmt_print(
            &self,
            f: &mut ::std::fmt::Formatter<'_>,
            _in_seq: bool,
        ) -> ::std::fmt::Result {
            write!(f, "ExecutionEnvironment")
        }
    }
}
