use kipio_identity_content::abi::export::KipioIdentityContentAbi;
use stylus_sdk::abi::export::{handle_license_and_pragma, print_from_args};

fn main() {
    handle_license_and_pragma();
    print_from_args::<KipioIdentityContentAbi>();
}
